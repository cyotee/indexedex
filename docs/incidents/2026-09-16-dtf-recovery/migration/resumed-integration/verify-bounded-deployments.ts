import { mkdir, readFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
import { Interface, Wallet, keccak256 } from "ethers";
import type { Result } from "ethers";
import { z } from "zod";
import { ANVIL, FORGE, child, launchAnvil } from "../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { RehearsalChain } from "../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { DEV, subscribeReceipt } from "../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { interfaceFile, save } from "../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { address, hash, hex } from "../../../../../scripts/recovery/dtf-migration/schema.js";
import { intent, quantity } from "../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import type { Receipt } from "../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { validateIntent } from "../../../../../scripts/recovery/dtf-migration/execution.js";
import { canonical, fingerprint } from "../../../../../scripts/recovery/dtf-migration/provenance.js";
import { recoverySamples } from "../conformance-20261114/task-11/recovery.js";

const evidence = resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("new evidence directory required");
const key = process.env["ALCHEMY_KEY"];
if (!key) throw new Error("existing archive credential required");
const upstream = `https://robinhood-mainnet.g.alchemy.com/v2/${key}`;
await mkdir(evidence, { recursive: false });
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18561", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--gas-limit", "100000000",
  "--disable-min-priority-fee", "--balance", "1000000", "--no-mining"],
join(evidence, "anvil.log"), upstream);
const chain = new RehearsalChain("18561");
// Cold, multi-recipient fork estimation exceeded the ordinary 15-second read budget.
// Scope the measured-run request budget to this owned client; do not retry a transaction.
const connection = chain.provider._getConnection();
connection.timeout = 120_000;
chain.provider._getConnection = () => connection.clone();
try {
  if (await chain.send("eth_chainId", []) !== "0x1237") throw new Error("wrong local chain");
  const anchor = z.object({ hash }).passthrough().parse(
    await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  if (anchor.hash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") {
    throw new Error("wrong local fork");
  }
  const policyPath = "docs/incidents/2026-09-16-dtf-recovery/migration/deployment-gas/diagnosis/limits-and-transactions.json";
  const policyBytes = await readFile(policyPath);
  const policy = z.object({
    historicalHeader: z.object({ hash, gasLimit: quantity }),
    historicalCalls: z.object({ block: z.literal(108944663), getMaxTxGasLimit: z.literal("32000000"), exit: z.literal(0) }),
  }).passthrough().parse(JSON.parse(policyBytes.toString()));
  assert.equal(policy.historicalHeader.hash, anchor.hash);
  const ceiling = BigInt(policy.historicalCalls.getMaxTxGasLimit) < BigInt(policy.historicalHeader.gasLimit)
    ? BigInt(policy.historicalCalls.getMaxTxGasLimit) : BigInt(policy.historicalHeader.gasLimit);
  await save(join(evidence, "source-manifest.json"), {
    chainId: "4663", blockNumber: "108944663", blockHash: anchor.hash,
    path: policyPath, sha256: createHash("sha256").update(policyBytes).digest("hex"),
    transactionLimit: policy.historicalCalls.getMaxTxGasLimit, headerLimit: policy.historicalHeader.gasLimit,
    applicableLimit: ceiling.toString(), qualification: "Pinned historical target policy; Anvil is not ArbOS fee emulation.",
  });
  const argv = [FORGE, "script", "--use", "solar",
    "scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol:MigrationDeploymentGasResumedQA",
    "--sig", "run()", "--rpc-url", chain.endpoint.toString(), "--sender", DEV,
    "--unlocked", "--legacy", "--gas-price", "2000000000"];
  const script = await child(["/bin/sh", "-c",
    'printf "ARGV"; printf " <%s>" "$@"; printf "\\n"; "$@"; code=$?; printf "\\nEXIT_CODE %s\\n" "$code"; exit "$code"',
    "task-11", ...argv], join(evidence, "generation.log"));
  if (script.code !== 0) throw new Error("bounded witness generation failed");
  const generated = z.object({ transactions: z.array(z.object({ transaction: z.object({
    from: address, to: address.nullable().optional(), input: hex, value: quantity.default("0x0"), nonce: quantity,
  }).passthrough() }).passthrough()) }).passthrough().parse(JSON.parse(await readFile(
    "broadcast/MigrationDeploymentGasResumedQA.s.sol/4663/dry-run/run-latest.json", "utf8")));
  const wallet = Wallet.fromPhrase("test test test test test test test test test test test junk");
  let signingCalls = 0;
  let sendingCalls = 0;
  const sign = wallet.signTransaction.bind(wallet);
  wallet.signTransaction = async (transaction) => { ++signingCalls; return sign(transaction); };
  const send = chain.send.bind(chain);
  chain.send = async (method, params) => {
    if (method === "eth_sendRawTransaction" || method === "eth_sendTransaction") ++sendingCalls;
    return send(method, params);
  };
  const pkg = await interfaceFile("out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const records: { readonly index: number; readonly transactionHash: string; readonly rawSignedTransaction: string;
    readonly transaction: unknown; readonly receipt: Receipt }[] = [];
  const constrained = [];
  const operations = [];
  const configured = new Set<string>();
  let lastLarge: { to: string; input: string } | undefined;
  let boundary: unknown;
  const parents = new Set<string>();
  const owners = new Set<string>();
  const preparationSelector = pkg.getFunction("prepareSyChildren")?.selector;
  const finalSelector = pkg.getFunction("deployVault")?.selector;
  const submit = async (tx: { readonly to?: string | null | undefined; readonly input: string; readonly value: string; readonly nonce: string },
    gasLimit = 32_000_000n) => {
    const raw = await wallet.signTransaction({ ...(tx.to ? { to: tx.to } : {}),
      data: tx.input, value: BigInt(tx.value), nonce: Number(BigInt(tx.nonce)), chainId: 4663n,
      gasLimit, gasPrice: 2_000_000_000n, type: 0 });
    const transactionHash = keccak256(raw);
    const watch = await subscribeReceipt(chain, transactionHash);
    try {
      if (await chain.send("eth_sendRawTransaction", [raw]) !== transactionHash) throw new Error("submitted hash differs");
      await chain.send("evm_mine", []);
      const receipt = await watch.mined();
      const actual = z.object({ gas: quantity, hash, blockHash: hash }).passthrough().parse(
        await chain.send("eth_getTransactionByHash", [transactionHash]));
      if (BigInt(receipt.status) !== 1n || actual.hash !== transactionHash
        || actual.blockHash !== receipt.blockHash || BigInt(actual.gas) !== gasLimit) throw new Error("bounded transaction failed");
      const record = { index: records.length, transactionHash, rawSignedTransaction: raw, transaction: actual, receipt };
      records.push(record);
      return record;
    } finally { watch.close(); }
  };
  for (const [index, entry] of generated.transactions.entries()) {
    const tx = entry.transaction;
    if (tx.from !== DEV || BigInt(tx.nonce) > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("unexpected fixture signer/nonce");
    const request = { from: DEV, ...(tx.to ? { to: tx.to } : {}), data: tx.input, value: tx.value,
      gas: "0x1e84800", gasPrice: "0x77359400" };
    await chain.send("eth_call", [request, "latest"]);
    const estimate = BigInt(quantity.parse(await chain.send("eth_estimateGas", [request])));
    if (estimate > ceiling) throw new Error(`transaction ${index} estimate exceeds authenticated ceiling`);
    const decoded = allocation.parseTransaction({ data: tx.input, value: tx.value });
    const operation = decoded && ["configureIndependentAllocations", "issueIndependentAllocations"].includes(decoded.name)
      ? decoded : null;
    const selected = operation ? Number(operation.args[0].length) : 0;
    const unrelated = configured.size - (operation?.name === "issueIndependentAllocations" ? selected : 0);
    const { transactionHash, transaction: actual, receipt } = await submit(tx);
      if (operation && tx.to) {
        const originals = operation.name === "configureIndependentAllocations"
          ? operation.args[0].map((row: { entitlements: readonly unknown[] }) => row.entitlements.length)
          : await Promise.all(operation.args[0].map(async (row: { recipient: string }) =>
            (await chain.call(tx.to ?? "", migration, "independentAllocation", [row.recipient]))[0].entitlements.length));
        const sample = { method: operation.name, selected, unrelated, originalsPerRecipient: originals,
          inputBytes: (tx.input.length - 2) / 2, estimate: estimate.toString(),
          signedLimit: BigInt(actual.gas).toString(), bufferedLimit: (estimate * 3n / 2n > ceiling ? ceiling : estimate * 3n / 2n).toString(),
          gasUsed: BigInt(quantity.parse(receipt["gasUsed"])).toString(), transactionHash, receipt,
          expectedResult: operation.name === "configureIndependentAllocations" ? "complete rows stored" : "exact funded bonds issued" };
        for (const row of operation.args[0]) {
          const recipient = address.parse(row.recipient);
          if (operation.name === "configureIndependentAllocations") {
            const config: Result = (await chain.call(tx.to, migration, "independentAllocation", [recipient]))[0];
            assert.equal(config.entitlements.length, row.entitlements.length);
            configured.add(recipient);
          } else {
            const issuance: Result = (await chain.call(tx.to, migration, "independentIssuance", [recipient]))[0];
            assert.equal(issuance.issued, true);
            const config: Result = (await chain.call(tx.to, migration, "independentAllocation", [recipient]))[0];
            assert.equal(issuance.credit, config.totalCredit);
            const bond = address.parse((await chain.call(tx.to, migration, "bondNftVault"))[0]);
            const bondAbi = await interfaceFile("out/IUniswapV4DetfMigrationBondNFTVault.sol/IUniswapV4DetfMigrationBondNFTVault.json");
            assert.equal((await chain.call(bond, bondAbi, "positionOf", [issuance.bondTokenId]))[0].principal, config.totalCredit);
          }
        }
        operations.push(sample);
        console.log("OPERATION_GAS", JSON.stringify(sample));
        if (operation.name === "configureIndependentAllocations" && selected === 64) {
          lastLarge = { to: tx.to, input: tx.input };
          const requests = await Promise.all(operation.args[0].map(async (row: { recipient: string }) => ({
            recipient: row.recipient,
            configurationId: (await chain.call(tx.to ?? "", migration, "independentAllocation", [row.recipient]))[0].configurationId,
          })));
          const input = allocation.encodeFunctionData("issueIndependentAllocations", [requests]);
          const nonceBefore = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
          const callsBefore = { signingCalls, sendingCalls };
          await assert.rejects(chain.send("eth_call", [{ from: DEV, to: tx.to, data: input, gas: "0x1e84800" }, "latest"]), /revert|gas/i);
          assert.equal(await chain.send("eth_getTransactionCount", [DEV, "latest"]), nonceBefore);
          assert.deepEqual({ signingCalls, sendingCalls }, callsBefore);
          boundary = { selected: 64, method: "issueIndependentAllocations", gas: ceiling.toString(),
            nonceBefore, nonceAfter: nonceBefore, signingCalls: signingCalls - callsBefore.signingCalls,
            sendingCalls: sendingCalls - callsBefore.sendingCalls, rejected: true };
          console.log("BOUNDARY_REJECTED", JSON.stringify(boundary));
        }
      }
      if (tx.to && (tx.input.slice(0, 10) === preparationSelector || tx.input.slice(0, 10) === finalSelector)) {
        const method = tx.input.slice(0, 10) === preparationSelector ? "prepareSyChildren" : "deployVault";
        const args = pkg.decodeFunctionData(method, tx.input)[0];
        const construction = (await chain.call(tx.to, pkg, "syConstruction", [args]))[0];
        const parent = address.parse(construction.parent);
        if (method === "prepareSyChildren") {
          if (await chain.send("eth_getCode", [parent, "latest"]) !== "0x") throw new Error("preparation published parent");
        } else {
          if (address.parse((await chain.call(parent, migration, "owner"))[0]) !== address.parse(args.owner)
            || (await chain.call(parent, migration, "migrationActivated"))[0] !== false
            || (await chain.call(parent, new Interface(["function totalSupply() view returns(uint256)"]), "totalSupply"))[0] !== 0n) {
            throw new Error("final parent identity or initial state differs");
          }
          parents.add(parent);
          owners.add(address.parse(args.owner));
        }
        constrained.push({ method, parent, transactionHash, inputBytes: (tx.input.length - 2) / 2,
          selected: 1, unrelated: parents.size - (method === "deployVault" ? 1 : 0),
          estimate: estimate.toString(), expectedResult: method === "deployVault" ? "inert registered parent" : "bound children only",
          receipt, envelope: BigInt(actual.gas).toString(),
          gasUsed: BigInt(quantity.parse(receipt["gasUsed"])).toString() });
      }
    if (index % 50 === 0) console.log(`BOUNDED_TX ${index + 1}/${generated.transactions.length}`);
  }
  if (constrained.length !== 4 || parents.size !== 2 || owners.size !== 2) throw new Error("two distinct constructions not demonstrated");
  await save(join(evidence, "constrained-receipts.json"), constrained);
  if (!lastLarge || !boundary) throw new Error("missing actual over-limit boundary");
  const decoded = allocation.decodeFunctionData("configureIndependentAllocations", lastLarge.input);
  const recipients = decoded[0].map((row: { recipient: string }) => row.recipient);
  const state = async () => canonical(await Promise.all(recipients.map((recipient: string) =>
    chain.send("eth_call", [{ to: lastLarge?.to, data: migration.encodeFunctionData("independentAllocation", [recipient]) }, "latest"]))));
  const before = await state();
  const rows = decoded[0].map((row: { recipient: string; evidenceId: string; entitlements: unknown }) => ({
    recipient: row.recipient, evidenceId: keccak256(new TextEncoder().encode("rollback gas witness")),
    entitlements: row.entitlements,
  }));
  const input = allocation.encodeFunctionData("configureIndependentAllocations", [rows, decoded[1]]);
  const nonce = BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"])));
  const raw = await wallet.signTransaction({ to: lastLarge.to, data: input, nonce: Number(nonce),
    chainId: 4663n, gasLimit: 1_000_000n, gasPrice: 2_000_000_000n, type: 0 });
  const failedHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, failedHash);
  let failedReceipt;
  try {
    await chain.send("eth_sendRawTransaction", [raw]);
    await chain.send("evm_mine", []);
    failedReceipt = await watch.mined();
    assert.equal(BigInt(failedReceipt.status), 0n);
    assert.equal(await state(), before);
    assert.equal(failedReceipt.logs.length, 0);
  } finally { watch.close(); }
  const operation = { id: fingerprint("over-limit saved intent"), stage: "deploy", method: "deployVault",
    transaction: { from: DEV, to: lastLarge.to, data: input, value: "0" } } as const;
  const oversized = await wallet.signTransaction({ to: lastLarge.to, data: input, nonce: Number(nonce + 1n),
    chainId: 4663n, gasLimit: ceiling + 1n, gasPrice: 2_000_000_000n, type: 0 });
  const savedIntent = intent.parse({ version: "dtf-operator-intent-v2", domainHash: fingerprint("gas negative"),
    ...operation, nonce: String(nonce + 1n), startBlock: "108944663", gasLimit: String(ceiling + 1n),
    gasPrice: "2000000000", signedTransaction: oversized, transactionHash: keccak256(oversized) });
  const savedNonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  const validationCalls = { signingCalls, sendingCalls };
  assert.throws(() => validateIntent(savedIntent, operation, "4663"), /exceeds target transaction gas limit/);
  assert.equal(await chain.send("eth_getTransactionCount", [DEV, "latest"]), savedNonce);
  assert.deepEqual({ signingCalls, sendingCalls }, validationCalls);
  await save(join(evidence, "..", "gas-negatives.json"), { boundary,
    underfunded: { rawSignedTransaction: raw, receipt: failedReceipt, beforeHash: fingerprint(before),
      afterHash: fingerprint(await state()), allConfigurationsRolledBack: true },
    savedIntent: { intent: savedIntent, rejected: true, nonceBefore: savedNonce, nonceAfter: savedNonce,
      signingDuringValidation: signingCalls - validationCalls.signingCalls,
      sends: sendingCalls - validationCalls.sendingCalls } });
  console.log("GAS_NEGATIVES_PASS", JSON.stringify({ boundary, failedHash, savedNonce }));
  const parent = lastLarge.to;
  const samples = await recoverySamples({ chain, parent, evidence, mine: async (data) => {
    const request = { from: DEV, to: parent, data, gas: "0x1e84800" };
    await chain.send("eth_call", [request, "latest"]);
    const estimate = BigInt(quantity.parse(await chain.send("eth_estimateGas", [request])));
    if (estimate > ceiling) throw new Error("recovery operation exceeds authenticated ceiling before signing");
    const nonce = quantity.parse(await chain.send("eth_getTransactionCount", [DEV, "latest"]));
    const result = await submit({ to: parent, input: data, value: "0x0", nonce });
    return { receipt: result.receipt, transactionHash: result.transactionHash,
      estimate: estimate.toString(), signedLimit: String(ceiling),
      gasUsed: String(BigInt(quantity.parse(result.receipt["gasUsed"]))), rawSignedTransaction: result.rawSignedTransaction };
  } });
  await save(join(evidence, "transactions.json"), records);
  await save(join(evidence, "operation-gas.json"), [...operations, ...samples]);
  console.log(JSON.stringify({ status: "two-bounded-deployments-pass", transactions: records.length, constrained }));
} finally {
  chain.close();
  await node.close();
  await save(join(evidence, "cleanup.json"), { node: "exited", port: 18561 });
}
