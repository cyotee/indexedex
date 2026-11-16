import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { Interface, Wallet, keccak256 } from "ethers";
import { fixture, a, h } from "./preparation.fixture.js";
import { canonical, fingerprint } from "./provenance.js";
import { prepareDomain, assemble, normalize } from "./preparation.js";
import type { PreparedDomain } from "./preparation.js";
import { executionManifest, intent } from "./execution-schema.js";
import type { Receipt } from "./execution-schema.js";
import { preparationInput } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { plan, erc20Abi } from "./execution-plan.js";
import { registryAbi, loupeAbi } from "./execution-domain.js";
import { claimedSources } from "../../../docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/census/claimed-source.fixture.js";

export async function executionFixture(independentOnly = false) {
  const f = await fixture();
  const { prepareDomain } = await import("./preparation.js");
  const { executionManifest } = await import("./execution-schema.js");
  const { sourceFile, interfaceFile } = await import("./rehearsal-data.js");
  const { DEV } = await import("./execution-rpc.js");
  const input = independentOnly ? { ...f.input, nfts: [], weightedLiquid: [], weightedSy: [], dtfCustodySe: [],
    claimVault: [], weightedReceipt: [], earlierReceipt: [], earlierLiquid: [], heldSeLp: [],
    exposures: f.input.exposures.filter((e) => e.category === "independent") } : f.input;
  const prepared = await prepareDomain(input);
  const preparedManifest = join(f.root, "prepared.json");
  await writeFile(preparedManifest, canonical(prepared), { flag: "wx" });
  const names = {
    migration: ["migration-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"],
    allocation: ["allocation-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json"],
    recovery: ["recovery-abi", "out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json"],
    pkg: ["package-abi", "out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json"],
    syPackage: ["sy-package-abi", "out/IUniswapV4DetfMigrationSYDFPkg.sol/IUniswapV4DetfMigrationSYDFPkg.json"],
  } as const;
  const sources = [...f.input.sources];
  for (const [id, path] of Object.values(names)) sources.push(await sourceFile(id, path));
  const manifest = executionManifest.parse({
    version: "dtf-operator-execution-v2", purpose: f.input.purpose, chainId: f.input.domain.chainId,
    rpcEnv: f.input.domain.rpcEnv, signer: DEV, local: null, proxy: f.input.domain.proxy,
    registry: a(11), package: a(12), bookId: f.input.domain.bookId, pricing: null,
    deployment: null, deploymentReceipt: null, deploymentBlockNumber: "90", deploymentBlockHash: h(90),
    bindings: f.input.domain.bindings, sources, preparedManifest, funding: { donations: [], genesis: null }, ownerBond: null,
  });
  const manifestPath = join(f.root, "execution.json");
  await writeFile(manifestPath, canonical(manifest), { flag: "wx" });
  const abis = {
    migration: await interfaceFile(names.migration[1]), allocation: await interfaceFile(names.allocation[1]),
    recovery: await interfaceFile(names.recovery[1]), pkg: await interfaceFile(names.pkg[1]),
    syPackage: await interfaceFile(names.syPackage[1]),
  };
  const domain = { manifest, prepared, abis,
    domain: { manifest, preparedHash: prepared.normalizedHash, payloadHash: prepared.payloadHash } };
  return { ...f, input, domain, manifestPath, preparedManifest };
}

/** Synthetic canonical RPC facts drive real preparation/history/verify/resume code. No EVM or sends. */
export async function censusFixture() {
  const f = await executionFixture(true);
  try {
    const originals = await claimedSources(f);
    const [x, y] = originals;
    assert.ok(x && y);
    const abi = f.domain.abis.migration;
    const deployment = {
      baseArgs: { name: "Census fixture", symbol: "DETF", hook: a(40), ownerOnlyLiquidity: false,
        creationPairPerDetfWad: [], openingPairPerDetfWad: [], mintThreshold: "0", burnThreshold: "0",
        expansionClosureRatePerYearWad: "0", creator: a(0), claimName: "", claimSymbol: "", bondName: "", bondSymbol: "",
        mintRouteMode: "0", mintRoutes: [], burnRouteMode: "0", burnRoutes: [],
        bondRouteMode: "0", bondRoutes: [], donateRouteMode: "0", donateRoutes: [] },
      owner: f.domain.manifest.signer, ownershipBufferPeriod: "0", weth: a(14), originalDtf: a(15),
    };
    const ref = async (path: string) => {
      const bytes = await readFile(path);
      return { path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
    };
    const deploymentSource = f.input.sources.find((s) => s.id === "deployment");
    assert.ok(deploymentSource);
    f.changes.transactions.set(h(901), { hash: h(901), to: a(12), blockHash: h(90),
      input: f.domain.abis.pkg.encodeFunctionData("deployVault", [deployment]) });
    f.changes.reads.set(registryAbi.encodeFunctionData("vaultsOfPackage", [a(12)]),
      registryAbi.encodeFunctionResult("vaultsOfPackage", [[a(10)]]));
    f.changes.reads.set(loupeAbi.encodeFunctionData("facets"), loupeAbi.encodeFunctionResult("facets", [[[a(13), []]]]));
    const cuts = new Interface(["function facetCuts() view returns((address facetAddress,uint8 action,bytes4[] functionSelectors)[])"]);
    f.changes.reads.set(cuts.encodeFunctionData("facetCuts"), cuts.encodeFunctionResult("facetCuts", [[]]));
    f.changes.reads.set(erc20Abi.encodeFunctionData("totalSupply"), erc20Abi.encodeFunctionResult("totalSupply", [0]));
    const inputFor = async (label: string, rows: readonly PreparationInput["weightedSy"][number][]) => {
      const exposures = rows.map((r, i) => ({ originId: r.original.originalId, category: "weighted-sy",
        originalUnits: r.original.originalUnits, descendants: [{ id: h(400 + i), units: r.original.originalUnits }],
        recoveredUnits: "0", excludedUnits: "0" }));
      const path = join(f.root, `${label}-sources.json`);
      const raw = canonical({ rows: rows.map(({ original, claimedOrigin }) => ({ original, claimedOrigin })), exposures });
      await writeFile(path, raw, { flag: "wx" });
      return preparationInput.parse({ ...f.input, independent: [], issueRecipients: [],
        domain: { ...f.input.domain, blockNumber: label === "A" ? "100" : "102", blockHash: h(label === "A" ? 100 : 102) },
        sources: [...f.input.sources.filter((s) => s.id !== "proof"), { id: "proof", ...await ref(path),
          provenance: { kind: "file", authority: "synthetic complete original review; not an allocation" } }],
        weightedSy: rows.map((r, i) => ({ ...r, proof: { sourceId: "proof", pointer: `/rows/${i}` } })),
        exposures: exposures.map((e, i) => ({ ...e, proof: { sourceId: "proof", pointer: `/exposures/${i}` } })) });
    };
    const save = async (label: string, prepared: PreparedDomain) => {
      const preparedPath = join(f.root, `${label}-prepared.json`);
      await writeFile(preparedPath, canonical(prepared), { flag: "wx" });
      const manifest = executionManifest.parse({ ...f.domain.manifest, preparedManifest: preparedPath,
        deployment, deploymentReceipt: await ref(deploymentSource.path) });
      const manifestPath = join(f.root, `${label}-execution.json`);
      await writeFile(manifestPath, canonical(manifest), { flag: "wx" });
      const domain = { manifest, prepared, abis: f.domain.abis,
        domain: { manifest, preparedHash: prepared.normalizedHash, payloadHash: prepared.payloadHash } };
      return { domain, preparedPath, manifestPath };
    };
    const signer = new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
    const savedIntent = async (context: Awaited<ReturnType<typeof save>>, nonce: number) => {
      const operation = plan(context.domain, "configure")[0];
      assert.ok(operation);
      const raw = await signer.signTransaction({ to: operation.transaction.to, data: operation.transaction.data,
        value: 0, chainId: 4663, nonce, gasLimit: 500000, gasPrice: 2, type: 0 });
      const record = intent.parse({ version: "dtf-operator-intent-v2", ...operation,
        domainHash: fingerprint(canonical(context.domain.domain)), nonce: String(nonce),
        startBlock: context.domain.prepared.input.domain.blockNumber,
        gasLimit: "500000", gasPrice: "2", signedTransaction: raw, transactionHash: keccak256(raw) });
      const checkpoint = join(f.root, `checkpoint-${nonce}`);
      await mkdir(checkpoint);
      const journalPath = join(checkpoint, "domain.json");
      const intentPath = join(checkpoint, `${record.id}.intent.json`);
      await writeFile(journalPath, canonical(context.domain.domain), { flag: "wx" });
      await writeFile(intentPath, canonical(record), { flag: "wx" });
      await writeFile(join(checkpoint, "run.json"), canonical({ stage: "configure", operationIds: [record.id] }), { flag: "wx" });
      return { ...context, checkpoint, journalPath, intentPath, record };
    };
    const configured: Receipt["logs"][number][] = [];
    const topic = abi.getEvent("WeightedSyEntitlementConfigured");
    assert.ok(topic);
    const allTopics = abi.fragments.filter((f) => f.type === "event").map((f) => abi.getEvent(f.format("sighash")))
      .filter((e) => e?.name.endsWith("Configured")).map((e) => e?.topicHash);
    const mine = (context: Awaited<ReturnType<typeof savedIntent>>, blockNumber: number) => {
      const row = context.domain.prepared.payloads.configure.weightedSy.find((r) => r.pricing.kind === "load");
      assert.ok(row);
      const { record } = context;
      const tag = `0x${blockNumber.toString(16)}`;
      const log = { ...abi.encodeEventLog(topic, [row.input.originalId, row.configurationId,
        row.input.originalWallet, row.input.originalUnits, row.quotedCredit]), address: a(10),
        blockHash: h(blockNumber), blockNumber: tag, transactionHash: record.transactionHash,
        transactionIndex: "0x0", logIndex: "0x0", removed: false };
      configured.push(log);
      const header = { number: tag, hash: h(blockNumber), parentHash: h(blockNumber - 1), transactions: [record.transactionHash] };
      f.changes.blocks.set(tag, header);
      f.changes.blocks.set("latest", header);
      f.changes.receipts.set(record.transactionHash, { transactionHash: record.transactionHash,
        blockHash: h(blockNumber), blockNumber: tag, transactionIndex: "0x0", from: record.transaction.from,
        to: record.transaction.to, status: "0x1", logs: [log] });
      f.changes.logs.set(h(blockNumber), [log]);
      f.changes.transactions.set(record.transactionHash, { hash: record.transactionHash, from: record.transaction.from,
        to: record.transaction.to, input: record.transaction.data, value: "0x0", chainId: "0x1237",
        nonce: `0x${BigInt(record.nonce).toString(16)}`, gas: "0x7a120", gasPrice: "0x2",
        blockHash: h(blockNumber), blockNumber: tag, transactionIndex: "0x0" });
      for (const toBlock of ["latest", "0x64", "0x66"]) for (const topics of [[topic.topicHash], [allTopics]]) {
        f.changes.logs.set(canonical({ address: a(10), fromBlock: "0x5a", toBlock, topics }),
          configured.filter((l) => toBlock === "latest" || BigInt(l.blockNumber) <= BigInt(toBlock)));
      }
      const args = [row.input.originalId];
      f.changes.reads.set(abi.encodeFunctionData("weightedSyEntitlement", args),
        abi.encodeFunctionResult("weightedSyEntitlement", [{ original: row.input, configurationId: row.configurationId,
          credit: row.quotedCredit, configured: true }]));
      f.changes.reads.set(abi.encodeFunctionData("weightedSySurrender", args),
        abi.encodeFunctionResult("weightedSySurrender", [[0, 0, row.input.originalUnits, row.quotedCredit]]));
      f.changes.reads.set(abi.encodeFunctionData("claimedSyWeights", args),
        abi.encodeFunctionResult("claimedSyWeights", [0, 0]));
    };
    const load = { kind: "load", bookId: f.input.domain.bookId, replaces: null } as const;
    const proof = { sourceId: "proof", pointer: "" };
    const aInput = await inputFor("A", [{ ...x, pricing: load, proof }]);
    const A = await savedIntent(await save("A", await prepareDomain(aInput)), 7);
    mine(A, 101);
    const rowA = A.domain.prepared.payloads.configure.weightedSy[0];
    assert.ok(rowA);
    const accepted = { manifest: await ref(A.preparedPath), executionManifest: await ref(A.manifestPath),
      journalDomain: await ref(A.journalPath), intent: await ref(A.intentPath), completion: null, configurationId: rowA.configurationId };
    f.changes.blocks.set("latest", { number: "0x66", hash: h(102), parentHash: h(101), transactions: [] });
    const bInput = await inputFor("B", [{ ...x, proof, pricing: { kind: "retain", bookId: load.bookId, accepted } },
      { ...y, proof, pricing: load }]);
    const B = await savedIntent(await save("B", await prepareDomain(bInput)), 8);
    const incomplete = async (keep: readonly string[]) => {
      const input = normalize({ ...B.domain.prepared.input,
        weightedSy: B.domain.prepared.input.weightedSy.filter((r) => keep.includes(r.original.originalId)),
        exposures: B.domain.prepared.input.exposures.filter((r) => keep.includes(r.originId)) });
      return save(`incomplete-${keep.join("-") || "empty"}`, assemble(input, B.domain.prepared.quoteEvidence));
    };
    return { ...f, A, B, accepted, configured, ref, incomplete, publishY: () => mine(B, 103) };
  } catch (error) {
    await f.close();
    throw error;
  }
}
