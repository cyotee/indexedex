import { readFile, readdir } from "node:fs/promises";
import { join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { Transaction, keccak256, zeroPadValue } from "ethers";
import { z } from "zod";
import { loadEvidence } from "./authenticate.js";
import { frames } from "./admission.js";
import { check, ProofError, save, json, abi, T, Y, HIST, qty, hex,
  txSchema, receiptSchema, blockSchema, frameSchema } from "./common.js";
import { W0, UNRELATED_WEIGHT } from "./setup.js";

const directory = resolve(process.argv[2] ?? "");
check(directory.startsWith(resolve(import.meta.dirname, "..") + "/run-"), "owned run required");
const evidence = await loadEvidence(directory);
const wireRows = [];
const wire = new Map<string, unknown>();
for (const name of (await readdir(join(directory, "wire"))).filter(n => /^\d+\.json$/.test(n)).sort()) {
  const row = z.object({ request: z.string(), response: z.string(), httpStatus: z.number(), raw: z.boolean() })
    .parse(JSON.parse(await readFile(join(directory, "wire", name), "utf8")));
  const request = z.object({ method: z.string(), params: z.array(z.unknown()), id: z.number() }).parse(JSON.parse(row.request));
  const response = z.object({ result: z.unknown(), id: z.number() }).parse(JSON.parse(row.response));
  check(row.httpStatus === 200 && row.raw && request.id === response.id, "raw exchange differs");
  check(!(request.method === "debug_traceTransaction" && request.params[0] === HIST), "forbidden historical trace");
  check(!["anvil_setCode", "anvil_setBalance", "anvil_setNonce", "anvil_setStorageAt", "anvil_reset", "evm_revert"]
    .includes(request.method), "forbidden state injection");
  wire.set(json([request.method, request.params]), response.result);
  wireRows.push({ request, response });
}
const observed = (method: string, params: readonly unknown[]) => {
  const key = json([method, params]);
  check(wire.has(key), `missing ${method} evidence`);
  return wire.get(key);
};
const transactions = [];
for (const name of (await readdir(join(directory, "wire"))).filter(n => n.startsWith("mined-"))) {
  const c = z.object({ raw: hex.nullable(), receipt: receiptSchema, transaction: txSchema,
    block: blockSchema, prior: blockSchema, trace: frameSchema })
    .parse(JSON.parse(await readFile(join(directory, "wire", name), "utf8")));
  const hash = c.transaction.hash;
  check(json(c.transaction) === json(txSchema.parse(observed("eth_getTransactionByHash", [hash])))
    && json(c.receipt) === json(receiptSchema.parse(observed("eth_getTransactionReceipt", [hash])))
    && json(c.trace) === json(frameSchema.parse(observed("debug_traceTransaction", [hash, { tracer: "callTracer" }])))
    && json(c.block) === json(blockSchema.parse(observed("eth_getBlockByNumber", [c.block.number, false])))
    && c.block.transactions.length === 1 && c.block.transactions[0] === hash
    && c.block.parentHash === c.prior.hash && c.receipt.blockHash === c.block.hash
    && c.transaction.blockHash === c.block.hash, "mined evidence canonical binding");
  if (c.raw !== null) {
    const signed = Transaction.from(c.raw);
    check(signed.isSigned() && signed.hash === hash && signed.chainId === 4663n
      && signed.from?.toLowerCase() === c.transaction.from
      && (signed.to?.toLowerCase() ?? null) === c.transaction.to
      && signed.data === c.transaction.input && signed.value === BigInt(c.transaction.value)
      && BigInt(signed.nonce) === BigInt(c.transaction.nonce)
      && observed("eth_sendRawTransaction", [c.raw]) === hash, "signed body identity");
  } else {
    check(c.transaction.from === "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3"
      && c.transaction.to === T && c.transaction.input.startsWith("0xcc447fba"),
      "unsigned operation outside disclosed donor");
  }
  transactions.push({ hash, signed: c.raw !== null, type: Transaction.from(c.raw ?? {}).type,
    from: c.transaction.from, to: c.transaction.to, block: BigInt(c.block.number).toString(),
    status: c.receipt.status });
}
const admitted = [], rejected = [], custody = [];
for (const { label, member: m } of evidence.rows) {
  if (label.startsWith("eligible-")) admitted.push({ label, ...evidence.authenticate(m) });
  else if (!label.startsWith("custody-")) {
    let reason: string | undefined;
    try { evidence.authenticate(m); }
    catch (error) { if (!(error instanceof ProofError)) throw error; reason = error.message; }
    check(reason !== undefined, "actual negative accepted");
    rejected.push({ label, hash: m.captured.transaction.hash, reason });
  } else {
    // Rebind every balance/allowance/book field to the independently captured numbered RPC call.
    const reads = [
      ["weight", T, "balanceOf", [m.wallet]], ["weightSupply", T, "totalSupply", []],
      ["walletSy", Y, "balanceOf", [m.wallet]], ["custodySy", Y, "balanceOf", [evidence.fixture.custody]],
      ["allowance", Y, "allowance", [m.wallet, evidence.fixture.custody]],
      ["booked", evidence.fixture.custody, "booked", [m.wallet]],
    ] as const;
    for (const [tag, state] of [[m.captured.prior.number, m.before], [m.captured.block.number, m.after]] as const) {
      for (const [field, target, method, args] of reads) {
        const value = abi.decodeFunctionResult(method, hex.parse(observed("eth_call",
          [{ to: target, data: abi.encodeFunctionData(method, args) }, tag])))[0];
        check(value === state[field], "custody state not bound to original wire");
      }
    }
    if (label.includes("late-failure")) {
      check(json(m.before) === json(m.after) && m.captured.receipt.status === "0x0"
        && m.captured.receipt.logs.length === 0 && m.after.weight === UNRELATED_WEIGHT, "custody rollback");
      check(frames(m.captured.trace).some(r => r.frame.type === "CALL" && r.frame.to === Y
        && r.frame.from === evidence.fixture.custody && r.frame.error === undefined
        && !r.committed && r.frame.input.startsWith("0x23b872dd")
        && abi.decodeFunctionResult("transferFrom", r.frame.output)[0] === true), "successful inner custody transfer absent");
    } else {
      const amount = m.before.walletSy - m.after.walletSy;
      check(m.captured.receipt.status === "0x1" && amount > 0n
        && m.after.custodySy - m.before.custodySy === amount
        && m.after.booked - m.before.booked === amount && m.after.weight === UNRELATED_WEIGHT,
        "custody transfer conservation");
    }
    custody.push({ label, hash: m.captured.transaction.hash, before: m.before, after: m.after });
  }
}
const deployments = [];
for (const name of ["SourceCustody", "DelegatedSourceProbe"]) {
  const d = z.object({ target: z.string(), args: z.array(z.string()), initcode: hex, runtime: hex,
    runtimeHash: z.string(), artifactPath: z.string(), artifactSha256: z.string(), transactionHash: z.string() })
    .passthrough().parse(JSON.parse(await readFile(join(directory, "wire", `deployment-${name}.json`), "utf8")));
  const bytes = await readFile(d.artifactPath);
  check(createHash("sha256").update(bytes).digest("hex") === d.artifactSha256, "artifact drift");
  const artifact = z.object({ bytecode: z.object({ object: hex }),
    deployedBytecode: z.object({ object: hex, immutableReferences: z.record(z.string(),
      z.array(z.object({ start: z.number(), length: z.number() }))) }),
    metadata: z.object({ compiler: z.object({ version: z.string() }),
      sources: z.record(z.string(), z.object({ keccak256: z.string() }).passthrough()) }).passthrough(),
  }).passthrough().parse(JSON.parse(bytes.toString()));
  let patched = artifact.deployedBytecode.object;
  for (const spans of Object.values(artifact.deployedBytecode.immutableReferences)) {
    const values = spans.map(({ start, length }) => {
      check(length === 20, "unexpected Solar immutable width");
      const v = `0x${d.runtime.slice(2 + 2 * start, 2 + 2 * (start + length))}`;
      check(d.args.some(a => zeroPadValue(a, length).toLowerCase() === v), "constructor immutable mismatch");
      patched = patched.slice(0, 2 + 2 * start) + v.slice(2) + patched.slice(2 + 2 * (start + length));
      return v;
    });
    check(new Set(values).size === 1, "immutable repeats differ");
  }
  const mined = txSchema.parse(observed("eth_getTransactionByHash", [d.transactionHash]));
  check(patched === d.runtime && keccak256(d.runtime) === d.runtimeHash && mined.input === d.initcode,
    "artifact/deployment/runtime mismatch");
  const source = await readFile(join(import.meta.dirname, "src/DelegatedSourceProbe.sol"));
  check(artifact.metadata.sources["src/DelegatedSourceProbe.sol"]?.keccak256 === keccak256(source),
    "compiled source metadata mismatch");
  deployments.push({ name, target: d.target, runtimeHash: d.runtimeHash, bytes: (d.runtime.length - 2) / 2,
    compiler: artifact.metadata.compiler.version, artifactSha256: d.artifactSha256 });
}
const signedCount = transactions.filter(t => t.signed).length;
check(admitted.length === 4 && rejected.length === 5 && custody.length === 6, "coverage census");
check(admitted.filter(r => r.label.startsWith("eligible-split")).reduce((n, r) => n + r.weight, 0n) === W0,
  "complete split including zero");
const balances = wireRows.filter(r => r.request.method === "eth_call"
  && json(r.request.params[0]) === json({ to: T, data: abi.encodeFunctionData("totalSupply") }));
const initial = balances[0];
check(initial, "initial weight supply missing");
const initialSupply = z.bigint().parse(abi.decodeFunctionResult("totalSupply", hex.parse(initial.response.result))[0]);
const final = custody[custody.length - 1]?.after;
check(final && initialSupply - final.weightSupply === 2n * W0 + 3n * 10n ** 18n + 2n, "global source supply reconciliation");
const result = { verdict: "bounded-local-source-proof", rpcExchanges: wireRows.length,
  signedTransactions: signedCount, disclosedDonorTransactions: transactions.length - signedCount,
  transactions, admitted, rejected, custody, deployments, initialSupply, final,
  historicalTraceRequests: 0, injectionRequests: 0,
  authority: "Same producer's separate stopped-evidence audit; not an independent agent or public-chain attestation" };
await save(join(directory, "audit.json"), result);
console.log("AUDIT_COMPLETE", wireRows.length, signedCount, transactions.length - signedCount);
