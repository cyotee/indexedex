import { readFile, readdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { Interface, Transaction, keccak256, toUtf8Bytes } from "ethers";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const base = dirname(fileURLToPath(import.meta.url));
const U = 10n ** 27n;
const S = 10n ** 9n;
const ER = "0x4ac89ad061a531fa62ddceed53520c2750113b01";
const decimal = z.string().regex(/^(0|[1-9][0-9]*)$/).transform(BigInt);
const account = z.object({ who: z.string(), display: decimal, external: decimal, diagnosticInternal: decimal });
const ledger = z.object({ who: z.string(), Q: decimal, C: decimal, B: decimal, delivered: decimal, allowance: decimal });
const state = z.object({ rate: decimal, totalShares: decimal, diagnosticTotalInternal: decimal,
  accounts: z.array(account), ledgers: z.array(ledger) });
const receipt = z.object({ status: z.string(), transactionHash: z.string(), from: z.string(),
  to: z.string().nullable(), logs: z.array(z.unknown()) }).passthrough();
const signedRecord = z.object({
  label: z.string(), raw: z.string(), before: state, after: state, receipt,
  request: z.object({ to: z.string().nullable(), data: z.string(), signer: z.string(), expected: z.string() }),
  trace: z.unknown(),
});
const check = (condition: boolean, message: string) => {
  if (!condition) throw new ExecutionError("STATE", message);
};
const pullAbi = new Interface(["function pull(uint256,bool)", "event Pulled(uint256,uint256,uint256,uint256)"]);
const pulls = [];
const reverts = [];
const signatures = [];
const sourceArchivePath = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry.source.json";
const sourceArchiveBytes = await readFile(sourceArchivePath);
const sourceArchive = z.object({ contracts: z.record(z.string(), z.object({
  runtimeMatch: z.string().optional(), observedCode: z.string().optional(), onchainBytecode: z.string().optional(),
  sources: z.record(z.string(), z.object({ content: z.string() })).optional(),
}).passthrough()) }).passthrough().parse(JSON.parse(sourceArchiveBytes.toString()));
const archived = sourceArchive.contracts["0x25e611fb63eb904776678286ef5cbe2a931b4f9a"];
check(archived?.runtimeMatch === "match", "archived qualification differs");
const identity = z.object({ bindings: z.array(z.object({ method: z.string(), code: z.string() })) })
  .passthrough().parse(JSON.parse(await readFile(join(base, "run-03/identity.json"), "utf8")));
for (const binding of identity.bindings) {
  check(binding.code === archived?.observedCode && binding.code === archived?.onchainBytecode,
    "actual source bytes differ from retained archive");
}
for (const run of ["run-03", "run-05"]) {
  for (const file of (await readdir(join(base, run))).filter(f => f.endsWith(".json")).sort()) {
    const parsed: unknown = JSON.parse(await readFile(join(base, run, file), "utf8"));
    const entry = signedRecord.safeParse(parsed);
    if (!entry.success) continue;
    const e = entry.data;
    const tx = Transaction.from(e.raw);
    check(keccak256(e.raw) === e.receipt.transactionHash && tx.chainId === 4663n
      && tx.from?.toLowerCase() === e.request.signer.toLowerCase()
      && tx.data === e.request.data && (tx.to?.toLowerCase() ?? null) === e.request.to,
    `signed intent/receipt mismatch ${run}/${file}`);
    signatures.push({ file: `${run}/${file}`, hash: e.receipt.transactionHash, signer: tx.from, nonce: tx.nonce,
      status: e.receipt.status });
    if (BigInt(e.receipt.status) === 0n) {
      const stringify = (x: unknown) => JSON.stringify(x, (_key, value: unknown) => typeof value === "bigint" ? String(value) : value);
      check(stringify(e.before) === stringify(e.after) && e.receipt.logs.length === 0, "failed source transaction changed state");
      reverts.push({ file: `${run}/${file}`, hash: e.receipt.transactionHash });
      continue;
    }
    if (!e.request.data.startsWith(pullAbi.getFunction("pull")?.selector ?? "missing")) continue;
    const [rawInput] = pullAbi.decodeFunctionData("pull", e.request.data);
    const n = z.bigint().parse(rawInput);
    const wallet = e.before.accounts.find(a => a.who === e.receipt.from);
    const walletAfter = e.after.accounts.find(a => a.who === e.receipt.from);
    const custody = e.before.accounts.find(a => a.who === e.receipt.to);
    const custodyAfter = e.after.accounts.find(a => a.who === e.receipt.to);
    const before = e.before.ledgers.find(a => a.who === e.receipt.to);
    const after = e.after.ledgers.find(a => a.who === e.receipt.to);
    if (!wallet || !walletAfter || !custody || !custodyAfter || !before || !after) {
      throw new ExecutionError("STATE", "missing actual endpoint/ledger");
    }
    const ds = wallet.external - walletAfter.external;
    const dc = custodyAfter.external - custody.external;
    const max = ds > dc ? ds : dc;
    const min = ds < dc ? ds : dc;
    const low = (max - 1n) * S + 1n;
    const upperExclusive = (min + 1n) * S;
    const rLow = n * U / upperExclusive + 1n;
    const rHigh = n * U / low;
    check(rLow === rHigh && rLow === e.before.rate && e.after.rate === rLow, "rate not uniquely identified by public floors");
    const q = n * U / rLow;
    const c = q === before.Q ? before.C : before.C * q / before.Q;
    check(q > 0n && q <= before.Q && c > 0n, "invalid eligible amount");
    check(wallet.diagnosticInternal - walletAfter.diagnosticInternal === q
      && custodyAfter.diagnosticInternal - custody.diagnosticInternal === q, "diagnostic exact movement differs");
    check(after.Q === before.Q - q && after.C === before.C - c && after.B === before.B + q
      && after.delivered === before.delivered + c && after.allowance === before.allowance - n,
    "consumption or allowance arithmetic differs");
    check(custody.diagnosticInternal - before.B === custodyAfter.diagnosticInternal - after.B
      && e.before.diagnosticTotalInternal === e.after.diagnosticTotalInternal, "inventory or source supply conservation failed");
    pulls.push({ file: `${run}/${file}`, transaction: e.receipt.transactionHash,
      n: String(n), rate: String(rLow), q: String(q), c: String(c),
      ds: String(ds), dc: String(dc), low: String(low), upperExclusive: String(upperExclusive),
      rLow: String(rLow), rHigh: String(rHigh), unbooked: String(custody.diagnosticInternal - before.B),
      Qafter: String(after.Q), Cafter: String(after.C) });
  }
}
check(pulls.length === 8, "expected six custody pulls and two rate pulls");
check(reverts.length === 8, "expected seven custody reverts and changed-rate late rollback");
// Exhaustive reduced-unit arithmetic, supplementary to real source witnesses.
let vectors = 0;
let isolated = 0;
for (let scale = 2n; scale <= 6n; scale++) for (let n = 1n; n <= 9n; n++) {
  for (let rate = 1n; rate <= 13n; rate++) for (let a = 0n; a < scale; a++) for (let b = 0n; b < scale; b++) {
    const q = n * 97n / rate;
    const sender = q + 10n * scale + a;
    const receiver = 7n * scale + b;
    const ds = sender / scale - (sender - q) / scale;
    const dc = (receiver + q) / scale - receiver / scale;
    const max = ds > dc ? ds : dc;
    const min = ds < dc ? ds : dc;
    const low = max === 0n ? 0n : (max - 1n) * scale + 1n;
    const high = (min + 1n) * scale - 1n;
    check(low <= q && q <= high, "floor interval theorem failed");
    if (low > 0n) {
      const rl = n * 97n / (high + 1n) + 1n;
      const rh = n * 97n / low;
      check(rl <= rate && rate <= rh, "rate inverse interval failed");
      if (rl === rh) { check(n * 97n / rl === q, "uniquely recovered movement failed"); isolated++; }
    }
    vectors++;
  }
}
const compilerArtifact = JSON.parse(await readFile(join(base, "build/ReceiptCustodyProbe.sol/ReceiptCustodyProbe.json"), "utf8"));
const compiler = z.object({ metadata: z.object({ compiler: z.object({ version: z.string() }),
  sources: z.record(z.string(), z.object({ keccak256: z.string() }).passthrough()) }).passthrough() })
  .passthrough().parse(compilerArtifact);
for (const [path, source] of Object.entries(compiler.metadata.sources)) {
  check(keccak256(await readFile(path)) === source.keccak256, `compiled source mismatch ${path}`);
}
await save(join(base, "proof.json"), {
  status: "PASS", source: ER, sourceArchivePath,
  sourceArchiveSha256: createHash("sha256").update(sourceArchiveBytes).digest("hex"),
  sourceQualification: archived?.runtimeMatch, authenticatedBindings: identity.bindings.length,
  signatures, pulls, reverts, arithmeticOracle: { vectors, isolated },
  compiler: compiler.metadata.compiler, compiledSources: compiler.metadata.sources,
  helperSha256: createHash("sha256").update(await readFile(join(base, "ReceiptCustodyProbe.sol"))).digest("hex"),
  deliberateLateFailureSelector: keccak256(toUtf8Bytes("DeliberateLateFailure()")).slice(0, 10),
  diagnosticStorageIsNotProductionApi: true, productionImplementation: false,
});
console.log("AUDIT_PASS");
