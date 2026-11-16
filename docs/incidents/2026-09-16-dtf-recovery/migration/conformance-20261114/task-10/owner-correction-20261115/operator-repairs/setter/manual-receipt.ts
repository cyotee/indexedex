import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";
import { z } from "zod";
import { loadExecution, nextBookId } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { captureCompletion } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { intent, receipt, ExecutionError } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { setterContext } from "./setter-context.js";

// Replay of saved real local-chain evidence; no new transaction or network request.
const root = process.cwd();
const evidence = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const blocker = z.object({
  receipt: z.string(), runtime: z.string(), expectedBookId: z.string(), transactionHash: z.string(),
}).parse(JSON.parse(await readFile(resolve(evidence, "operator-setter-blocker.json"), "utf8")));
const raw = await readFile(blocker.receipt);
const saved = z.object({
  header: z.object({ hash: z.string(), number: z.string(), transactions: z.array(z.string()) }).passthrough(),
  receipt, transaction: z.object({ hash: z.string() }).passthrough(),
  trace: z.object({ output: z.string() }).passthrough(),
}).parse(JSON.parse(raw.toString("utf8")));
const domain = await loadExecution(resolve(blocker.runtime, "pricing-execution.json"));
const record = intent.parse(JSON.parse(await readFile(resolve(dirname(blocker.receipt),
  "b596ce099567412a62c0e767258f360d97f8d3562b37cbb422e14becf2a2ced2.intent.json"), "utf8")));
const journal = JSON.parse(await readFile(resolve(dirname(blocker.receipt), "domain.json"), "utf8"));
assert.equal(canonical(journal), canonical(domain.domain));
assert.equal(record.domainHash, fingerprint(canonical(domain.domain)));
assert.equal(nextBookId(domain), blocker.expectedBookId);
assert.equal(saved.trace.output, blocker.expectedBookId);
assert.equal(saved.receipt.status, "0x1");
assert.equal(saved.receipt.transactionHash, blocker.transactionHash);

class SavedRpc extends Rpc {
  override async send(method: string, _params: readonly unknown[]): Promise<unknown> {
    switch (method) {
      case "eth_getTransactionReceipt": return saved.receipt;
      case "eth_getBlockByNumber": return saved.header;
      case "eth_getLogs": return saved.receipt.logs;
      case "eth_getTransactionByHash": return saved.transaction;
      default: throw new ExecutionError("RPC", `offline replay forbids ${method}`);
    }
  }
}

process.env[domain.manifest.rpcEnv] = "http://127.0.0.1:1";
const rpc = new SavedRpc(domain.manifest);
try {
  const mined = await rpc.canonicalReceipt(record.transactionHash);
  assert.ok(mined);
  const pricingPath = resolve(root,
    "out/IUniswapV4DetfMigrationWeightedPricing.sol/IUniswapV4DetfMigrationWeightedPricing.json");
  const pricingRaw = await readFile(pricingPath);
  const generated = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(pricingRaw.toString("utf8")));
  const pricing = new Interface(JSON.stringify(generated.abi));
  const log = mined.logs[0];
  assert.ok(log);
  const decoded = pricing.parseLog({ topics: [...log.topics], data: log.data });
  assert.equal(decoded?.args[0], blocker.expectedBookId);
  console.log(JSON.stringify({
    kind: "saved-real-local-chain-replay", receiptSha256: fingerprint(raw),
    transactionHash: record.transactionHash, expectedBookId: blocker.expectedBookId,
    immutableDomainHash: record.domainHash, generatedPricingArtifact: pricingPath,
    generatedPricingArtifactSha256: fingerprint(pricingRaw),
    generatedDecode: decoded?.args[0], pricingArtifactBound: domain.manifest.sources.some((s) => s.path === pricingPath),
    note: "Standalone generated decode is diagnostic only; it is not admitted authority for production receipt verification.",
  }));
  await assert.rejects(captureCompletion(rpc, domain, record, mined), /missing bound pricing event ABI/);
  console.log(JSON.stringify({ kind: "original-immutable-domain", status: "still-rejected",
    reason: "missing bound pricing event ABI", originalDomainWasNotRebound: true }));
} finally {
  rpc.close();
}

const fresh = await setterContext();
try {
  const actual = await fresh.verify(fresh.mined);
  assert.equal(actual.state.bookId, fresh.expected);
  console.log(JSON.stringify({ kind: "new-synthetic-wire-context", status: "accepted",
    expectedBookId: fresh.expected, originalSavedBookId: blocker.expectedBookId,
    transactionHash: fresh.record.transactionHash, domainHash: fresh.record.domainHash,
    source: fresh.domain.manifest.sources.find((s) => s.id === "pricing-abi"),
    note: "New fixture signature and mocked canonical wire evidence; not a new Anvil transaction or historical proof." }));
  const log = fresh.mined.logs[0];
  assert.ok(log);
  const topic = log.topics[0];
  assert.ok(topic);
  const wrong = `0x${"ff".repeat(32)}`;
  const cases = [
    { name: "wrong book", logs: [{ ...log, topics: [topic, wrong] }] },
    { name: "wrong emitter", logs: [{ ...log, address: `0x${"ff".repeat(20)}` }] },
    { name: "wrong topic", logs: [{ ...log, topics: [wrong, fresh.expected] }] },
    { name: "missing event", logs: [] },
    { name: "missing indexed book", logs: [{ ...log, topics: [topic] }] },
    { name: "extra topic", logs: [{ ...log, topics: [...log.topics, wrong] }] },
    { name: "malformed data", logs: [{ ...log, data: wrong }] },
    { name: "duplicate event", logs: [log, { ...log, logIndex: "0x1" }] },
    { name: "wrong transaction identity", logs: [{ ...log, transactionHash: wrong }] },
    { name: "wrong block identity", logs: [{ ...log, blockHash: wrong }] },
    { name: "wrong transaction index", logs: [{ ...log, transactionIndex: "0x1" }] },
    { name: "wrong log order", logs: [{ ...log, logIndex: "0x1" }] },
  ];
  for (const example of cases) {
    await assert.rejects(fresh.verify(receipt.parse({ ...fresh.mined, logs: example.logs })));
    console.log(JSON.stringify({ kind: "new-synthetic-corrupted-receipt", probe: example.name, status: "rejected" }));
  }
  assert.equal(fresh.methods.includes("eth_sendRawTransaction"), false);
} finally {
  await fresh.close();
}
