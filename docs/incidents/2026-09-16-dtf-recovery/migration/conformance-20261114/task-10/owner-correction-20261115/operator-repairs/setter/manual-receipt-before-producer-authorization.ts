import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { Interface } from "ethers";
import { z } from "zod";
import { loadExecution, nextBookId } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { captureCompletion } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { intent, receipt, ExecutionError } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";

// Replay of saved real local-chain evidence; no new transaction or network request.
const root = process.cwd();
const evidence = dirname(dirname(dirname(import.meta.path)));
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
  try {
    await captureCompletion(rpc, domain, record, mined);
    throw new ExecutionError("STATE", "unexpected production success: baseline regression did not reproduce");
  } catch (error) {
    if (!(error instanceof ExecutionError) || error.message !== "manual setter event differs from exact Inputs") throw error;
    console.error(JSON.stringify({ status: "blocked-outside-allowed-writes", productionError: error.message,
      requiredProducer: "scripts/recovery/dtf-migration/rehearsal-data.ts:69-75",
      cause: "bootstrapManifest omits the separate generated pricing event ABI from immutable manifest.sources",
      regression: "Successful saved setter receipt rejected by unchanged production captureCompletion",
      afterFixAndCorruptedCopyChecks: "not run: no authorized producer binding exists; no fabricated domain substituted" }));
    process.exitCode = 1;
  }
} finally {
  rpc.close();
}
