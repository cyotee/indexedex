import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { z } from "zod";
import { fixture, a, h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { loadExecution } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { receipt, rpcLog, quantity } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import type { Receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";

export const blockerPath = resolve("docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-empty-census-blocker.json");
// Independent ABI contract cases, with synthetic compensation amounts/identities.
export const compensationEvents = [
  ["IndependentAllocationConfigured", [a(20), h(1), h(2), 12]],
  ["IndependentAllocationIssued", [a(20), h(1), 3, 12, 2000]],
  ["NftEntitlementConfigured", [a(21), 3, h(1), a(20), h(2), 12]],
  ["WeightedLiquidEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["WeightedSyEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["DtfCustodySeEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["ClaimVaultEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["WeightedReceiptEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["EarlierReceiptEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["EarlierLiquidEntitlementConfigured", [h(1), h(2), a(20), 3, 12]],
  ["HeldSeLpEntitlementConfigured", [h(1), h(2), a(20), a(22), 3, 12]],
] as const;

const filterSchema = z.object({ address, fromBlock: quantity, toBlock: z.union([quantity, z.literal("latest")]),
  topics: z.array(z.union([hash, z.array(hash), z.null()])) });
/** Fixture transport filtering, not a replacement for any production census function. */
class CensusLogs extends Map<string, unknown> {
  rows: Receipt["logs"] = [];
  malformed = false;
  override get(key: string): unknown {
    if (!key.startsWith("{")) return super.get(key);
    if (this.malformed) return [{}];
    const filter = filterSchema.parse(JSON.parse(key));
    return this.rows.filter((row) => row.address === filter.address
      && BigInt(row.blockNumber) >= BigInt(filter.fromBlock)
      && (filter.toBlock === "latest" || BigInt(row.blockNumber) <= BigInt(filter.toBlock))
      && filter.topics.every((topic, i) => topic === null || (typeof topic === "string"
        ? row.topics[i] === topic : topic.some((candidate) => candidate === row.topics[i]))));
  }
}

export async function censusContext() {
  const blocker = z.object({ runtime: z.string(), manifest: z.string(), deploymentReceipt: z.string(),
    mandatoryDeploymentLogs: z.array(rpcLog) }).passthrough().parse(JSON.parse(await readFile(blockerPath, "utf8")));
  const domain = await loadExecution(blocker.manifest);
  assert.equal(domain.prepared, undefined);
  assert.equal(domain.manifest.pricing, null);
  assert.ok(domain.abis.pricing?.getEvent("MigrationWeightedPricingSet"));
  const mined = receipt.parse(JSON.parse(await readFile(blocker.deploymentReceipt, "utf8")));
  const chainPath = resolve(blocker.runtime, "journal-deploy/17918fb30b629655bba3525c0d075970ad103105dd38d80270271398bdf9d238.canonical-chain.json");
  const chain = z.object({ receipt, header: z.object({ hash, number: quantity, transactions: z.array(hash) }).passthrough(),
    transaction: z.object({ hash, to: address, input: hex, blockHash: hash }).passthrough(),
  }).passthrough().parse(JSON.parse(await readFile(chainPath, "utf8")));
  assert.equal(canonical(chain.receipt), canonical(mined));
  assert.equal(chain.transaction.hash, mined.transactionHash);
  const ownerDomainPath = resolve(blocker.runtime, "journal-owner-bond/domain.json");
  assert.equal(canonical(JSON.parse(await readFile(ownerDomainPath, "utf8"))), canonical(domain.domain));
  const threshold = domain.abis.migration.getEvent("ThresholdsConfigured");
  assert.ok(threshold);
  const initialization = mined.logs.filter((log) => log.address === domain.manifest.proxy && log.topics[0] === threshold.topicHash);
  assert.equal(canonical(initialization), canonical(blocker.mandatoryDeploymentLogs));
  assert.equal(initialization.length, 1);
  const paths = [...new Set([blockerPath, blocker.manifest, blocker.deploymentReceipt, chainPath, ownerDomainPath,
    resolve(blocker.runtime, "journal-deploy/domain.json"), ...domain.manifest.sources.map((s) => s.path)])];
  const bindings = await Promise.all(paths.map(async (path) => {
    const bytes = await readFile(path);
    return { path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
  }));
  const f = await fixture();
  try {
    const logs = new CensusLogs();
    logs.rows = mined.logs;
    logs.set(mined.blockHash, mined.logs);
    f.changes.logs = logs;
    f.changes.blocks.set(mined.blockNumber, chain.header);
    f.changes.receipts.set(mined.transactionHash, mined);
    f.changes.transactions.set(mined.transactionHash, chain.transaction);
    // Only provider construction temporarily selects loopback. Saved domains stay exact.
    const previous = process.env[domain.manifest.rpcEnv];
    let rpc: Rpc;
    try {
      process.env[domain.manifest.rpcEnv] = process.env[f.input.domain.rpcEnv];
      rpc = new Rpc(domain.manifest);
    } finally {
      if (previous === undefined) delete process.env[domain.manifest.rpcEnv];
      else process.env[domain.manifest.rpcEnv] = previous;
    }
    const inject = (event: (typeof compensationEvents)[number], offset: bigint) => {
      const fragment = domain.abis.migration.getEvent(event[0]);
      assert.ok(fragment);
      const entry = { ...domain.abis.migration.encodeEventLog(fragment, [...event[1]]),
        address: domain.manifest.proxy, blockNumber: `0x${(BigInt(mined.blockNumber) + offset).toString(16)}`,
        blockHash: h(9000), transactionHash: h(9001), transactionIndex: "0x0", logIndex: "0x0" };
      logs.rows = [...mined.logs, entry];
      return entry;
    };
    return { ...f, domain, rpc, mined, chain, logs, initialization, bindings, inject,
      async close() { rpc.close(); await f.close(); } };
  } catch (error) {
    await f.close();
    throw error;
  }
}
