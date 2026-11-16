import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { Interface } from "ethers";
import { z } from "zod";
import { censusContext, compensationEvents } from "../empty-census/census-context.js";
import { executionFixture, a, h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { loadExecution, loupeAbi, registryAbi } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { execute } from "../../../../../../../../../scripts/recovery/dtf-migration/execution.js";
import { prepareDomain } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.js";
import { normalize } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { verifyConfiguration } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { receipt, quantity } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import type { Receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { erc20Abi } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-plan.js";

/** A wire-level range filter; canonical block lookups still use the existing fixture map. */
export class RangeLogs extends Map<string, unknown> {
  rows: Receipt["logs"] = [];
  malformed = false;
  override get(key: string): unknown {
    if (!key.startsWith("{")) return super.get(key);
    if (this.malformed) return [{}];
    const filter = z.object({ address: z.string(), fromBlock: quantity,
      toBlock: z.union([quantity, z.literal("latest")]), topics: z.array(z.union([z.string(), z.array(z.string()), z.null()])) })
      .parse(JSON.parse(key));
    return this.rows.filter((row) => row.address === filter.address
      && BigInt(row.blockNumber) >= BigInt(filter.fromBlock)
      && (filter.toBlock === "latest" || BigInt(row.blockNumber) <= BigInt(filter.toBlock))
      && filter.topics.every((topic, i) => topic === null || (typeof topic === "string"
        ? row.topics[i] === topic : topic.includes(row.topics[i] ?? ""))));
  }
}

export async function preparedContext() {
  const actual = await censusContext();
  try { await actual.rpc.canonicalReceipt(actual.mined.transactionHash); } finally { await actual.close(); }
  const f = await executionFixture(true);
  try {
    const deploymentSource = f.input.sources.find((s) => s.id === "deployment");
    const actualInitialization = actual.initialization[0];
    assert.ok(deploymentSource && actualInitialization && actual.domain.manifest.deployment);
    const baseReceipt = receipt.parse(JSON.parse(await readFile(deploymentSource.path, "utf8")));
    const initialization = { ...actualInitialization, address: f.domain.manifest.proxy,
      blockHash: baseReceipt.blockHash, blockNumber: baseReceipt.blockNumber,
      transactionHash: baseReceipt.transactionHash, transactionIndex: baseReceipt.transactionIndex, logIndex: "0x1" };
    const deployed = { ...baseReceipt, logs: [...baseReceipt.logs, initialization] };
    const deploymentPath = join(f.root, "initialized-deployment.json");
    await writeFile(deploymentPath, canonical(deployed), { flag: "wx" });
    const ref = async (path: string) => {
      const bytes = await readFile(path);
      return { path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
    };
    const deploymentBinding = { ...deploymentSource, ...await ref(deploymentPath) };
    const sources = f.domain.manifest.sources.map((s) => s.id === "deployment" ? deploymentBinding : s);
    const logs = new RangeLogs();
    logs.rows = deployed.logs;
    logs.set(deployed.blockHash, deployed.logs);
    f.changes.logs = logs;
    f.changes.receipts.set(deployed.transactionHash, deployed);
    const deployment = { ...actual.domain.manifest.deployment,
      owner: f.domain.manifest.signer, weth: a(14), originalDtf: a(15) };
    f.changes.transactions.set(deployed.transactionHash, { hash: deployed.transactionHash, to: f.domain.manifest.package,
      blockHash: deployed.blockHash, input: f.domain.abis.pkg.encodeFunctionData("deployVault", [deployment]) });
    const prepared = await prepareDomain({ ...f.input, issueRecipients: [], sources });
    const preparedPath = join(f.root, "initialized-prepared.json");
    await writeFile(preparedPath, canonical(prepared), { flag: "wx" });
    const manifest = { ...f.domain.manifest, sources, preparedManifest: preparedPath,
      deployment, deploymentReceipt: await ref(deploymentPath) };
    const manifestPath = join(f.root, "initialized-execution.json");
    await writeFile(manifestPath, canonical(manifest), { flag: "wx" });
    const domain = await loadExecution(manifestPath);
    const row = prepared.payloads.configure.independent[0];
    assert.ok(row);
    const abi = domain.abis.migration;
    const event = abi.getEvent("IndependentAllocationConfigured");
    assert.ok(event);
    const configured = { ...abi.encodeEventLog(event, [row.input.recipient, row.configurationId, row.input.evidenceId, row.quotedCredit]),
      address: manifest.proxy, blockHash: h(101), blockNumber: "0x65", transactionHash: h(1001), transactionIndex: "0x0", logIndex: "0x0" };
    const configuredReceipt = { transactionHash: configured.transactionHash, blockHash: configured.blockHash,
      blockNumber: configured.blockNumber, transactionIndex: "0x0", from: manifest.signer, to: manifest.proxy, status: "0x1", logs: [configured] };
    f.changes.blocks.set("0x65", { number: "0x65", hash: h(101), parentHash: h(100), transactions: [configured.transactionHash] });
    f.changes.receipts.set(configured.transactionHash, configuredReceipt);
    logs.set(h(101), [configured]);
    logs.rows = [...deployed.logs, configured];
    const stored = { configurationId: row.configurationId, evidenceId: row.input.evidenceId, totalCredit: row.quotedCredit,
      entitlements: row.input.entitlements.map((original) => ({ original, credit: row.quotedCredit })) };
    f.changes.reads.set(abi.encodeFunctionData("independentAllocation", [row.input.recipient]),
      abi.encodeFunctionResult("independentAllocation", [stored]));
    f.changes.reads.set(erc20Abi.encodeFunctionData("totalSupply"), erc20Abi.encodeFunctionResult("totalSupply", [0]));
    f.changes.reads.set(registryAbi.encodeFunctionData("vaultsOfPackage", [manifest.package]),
      registryAbi.encodeFunctionResult("vaultsOfPackage", [[manifest.proxy]]));
    f.changes.reads.set(loupeAbi.encodeFunctionData("facets"), loupeAbi.encodeFunctionResult("facets", [[[a(13), []]]]));
    const cuts = new Interface(["function facetCuts() view returns((address facetAddress,uint8 action,bytes4[] functionSelectors)[])"]);
    f.changes.reads.set(cuts.encodeFunctionData("facetCuts"), cuts.encodeFunctionResult("facetCuts", [[]]));
    const invoke = (command: "verify" | "activate") => execute({ command, manifestPath,
      checkpoint: join(f.root, "readonly-checkpoint"), mode: { kind: "simulate" }, reverse: false, faultAfterMined: false });
    const omitted = (candidate: (typeof compensationEvents)[number], offset: bigint) => {
      const fragment = abi.getEvent(candidate[0]);
      assert.ok(fragment);
      const values: readonly unknown[] = candidate[0] === "IndependentAllocationConfigured"
        ? [a(999), ...candidate[1].slice(1)] : candidate[1];
      const at = `0x${(90n + offset).toString(16)}`;
      const entry = { ...abi.encodeEventLog(fragment, [...values]), address: manifest.proxy,
        blockHash: h(Number(90n + offset)), blockNumber: at, transactionHash: h(2001),
        transactionIndex: offset === 0n ? "0x1" : "0x0", logIndex: offset === 0n ? "0x2" : "0x0" };
      f.changes.blocks.set(at, { number: at, hash: entry.blockHash, parentHash: h(Number(89n + offset)),
        transactions: offset === 0n ? [deployed.transactionHash, entry.transactionHash] : [entry.transactionHash] });
      f.changes.receipts.set(entry.transactionHash, { ...configuredReceipt, transactionHash: entry.transactionHash,
        blockHash: entry.blockHash, blockNumber: at, transactionIndex: entry.transactionIndex, logs: [entry] });
      logs.set(entry.blockHash, offset === 0n ? [...deployed.logs, entry] : [entry]);
      logs.rows = [...deployed.logs, configured, entry];
      return entry;
    };
    const rpc = new Rpc(domain.manifest);
    return { ...f, domain, manifestPath, preparedPath, prepared, row, stored, logs, configured, configuredReceipt,
      actual: { initialization: actualInitialization, bindings: actual.bindings, domainHash: fingerprint(canonical(actual.domain.domain)) },
      initialization, invoke, omitted, verify: () => verifyConfiguration(rpc, domain),
      async close() { rpc.close(); await f.close(); } };
  } catch (error) { await f.close(); throw error; }
}

export const preparedFaults = [
  "missing receipt", "wrong receipt transaction", "wrong receipt header", "wrong range block",
  "malformed range", "changed full input", "missing issuance history", "duplicate original", "stale preparation boundary",
] as const;
export async function probePreparedFault(f: Awaited<ReturnType<typeof preparedContext>>, fault: (typeof preparedFaults)[number]) {
  const abi = f.domain.abis.migration;
  switch (fault) {
    case "missing receipt":
      f.changes.receipts.set(f.configured.transactionHash, null);
      return f.verify();
    case "wrong receipt transaction":
      f.changes.receipts.set(f.configured.transactionHash, { ...f.configuredReceipt, transactionHash: h(777) });
      return f.verify();
    case "wrong receipt header":
      f.changes.blocks.set("0x65", { number: "0x65", hash: h(777), transactions: [f.configured.transactionHash] });
      return f.verify();
    case "wrong range block":
      f.logs.rows = f.logs.rows.map((l) => l.transactionHash === f.configured.transactionHash ? { ...l, blockHash: h(777) } : l);
      return f.verify();
    case "malformed range": f.logs.malformed = true; return f.verify();
    case "changed full input":
      f.changes.reads.set(abi.encodeFunctionData("independentAllocation", [f.row.input.recipient]),
        abi.encodeFunctionResult("independentAllocation", [{ ...f.stored, entitlements: f.stored.entitlements.map((e) =>
          ({ ...e, original: { ...e.original, originalEth: String(BigInt(e.original.originalEth) + 1n) } })) }]));
      return f.verify();
    case "missing issuance history":
      f.changes.reads.set(abi.encodeFunctionData("independentIssuance", [f.row.input.recipient]),
        abi.encodeFunctionResult("independentIssuance", [{ issued: true, configurationId: f.row.configurationId,
          credit: f.row.quotedCredit, bondTokenId: 3, issuedAt: 2000 }]));
      return f.verify();
    case "duplicate original": {
      const input = normalize({ ...f.prepared.input, independent: [...f.prepared.input.independent, ...f.prepared.input.independent] });
      const preparedPath = join(f.root, "duplicate-prepared.json");
      await writeFile(preparedPath, canonical({ ...f.prepared, input, normalizedHash: fingerprint(canonical(input)) }), { flag: "wx" });
      const path = join(f.root, "duplicate-execution.json");
      await writeFile(path, canonical({ ...f.domain.manifest, preparedManifest: preparedPath }), { flag: "wx" });
      return loadExecution(path);
    }
    case "stale preparation boundary":
      f.changes.blocks.set("0x64", { number: "0x64", hash: h(777), parentHash: h(99), transactions: [] });
      return f.invoke("verify");
    default: { const unreachable: never = fault; throw new Error(unreachable); }
  }
}
export const preparedFaultReasons = {
  "missing receipt": /noncanonical configuration census/,
  "wrong receipt transaction": /receipt is not canonical or transaction order differs/,
  "wrong receipt header": /receipt is not canonical or transaction order differs/,
  "wrong range block": /noncanonical configuration census/,
  "malformed range": /Required/,
  "changed full input": /stored full independent originals differ/,
  "missing issuance history": /issued recipient requires immutable issuance history/,
  "duplicate original": /overlapping original|duplicate recipient/,
  "stale preparation boundary": /wrong canonical block/,
} as const satisfies Record<(typeof preparedFaults)[number], RegExp>;
