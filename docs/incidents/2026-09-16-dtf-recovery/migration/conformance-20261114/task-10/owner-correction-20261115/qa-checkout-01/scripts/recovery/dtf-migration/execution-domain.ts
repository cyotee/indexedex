import { resolve } from "node:path";
import { AbiCoder, Interface, Result, keccak256 } from "ethers";
import { z } from "zod";
import { canonical, fingerprint, readBoundFile, readReference } from "./provenance.js";
import { validateManifest } from "./preparation.js";
import type { PreparationContext } from "./preparation.js";
import { address, hex } from "./schema.js";
import { ExecutionError, executionManifest, intent, completion, rpcLog } from "./execution-schema.js";
import type { Intent, Completion } from "./execution-schema.js";
import type { AcceptedConfiguration, FileRef, PreparationInput } from "./schema.js";
import type { Rpc } from "./execution-rpc.js";
import { loadSavedBundle } from "./bundle.js";
import { configurationKinds } from "./payloads.js";

export const registryAbi = new Interface(["function vaultsOfPackage(address) view returns (address[])"]);
export const loupeAbi = new Interface([
  "function facetAddress(bytes4) view returns (address)",
  "function facets() view returns ((address facetAddress,bytes4[] functionSelectors)[])",
]);

export async function loadExecution(path: string, context?: PreparationContext, bundle?: FileRef) {
  const manifest = executionManifest.parse(JSON.parse((await readBoundFile(resolve(path), bundle)).toString("utf8")));
  if (manifest.bundle && !bundle) {
    const saved = await loadSavedBundle(manifest.bundle.path, manifest.bundle);
    if (saved.kind !== "execution"
      || canonical(manifest) !== canonical({ ...saved.execution, preparedManifest: manifest.preparedManifest })
      || Boolean(saved.prepared) !== Boolean(manifest.preparedManifest)) {
      throw new ExecutionError("DOMAIN", "materialized execution differs from saved template");
    }
  }
  for (const source of manifest.sources) {
    if (!source.path.startsWith("/")) throw new ExecutionError("DOMAIN", "execution source paths must be absolute");
    const bytes = await readBoundFile(source.path, bundle);
    if (fingerprint(bytes) !== source.sha256 || String(bytes.length) !== source.bytes) {
      throw new ExecutionError("DOMAIN", `source binding differs: ${source.id}`);
    }
  }
  const prepared = manifest.preparedManifest ? await validateManifest(manifest.preparedManifest, context, bundle) : undefined;
  if (manifest.bundle && prepared && canonical(prepared.input.bundle) !== canonical(manifest.bundle)) {
    throw new ExecutionError("DOMAIN", "execution and preparation bundles differ");
  }
  if (prepared && (prepared.input.domain.chainId !== manifest.chainId
    || prepared.input.domain.proxy !== manifest.proxy
    || prepared.input.domain.deploymentBlockNumber !== manifest.deploymentBlockNumber
    || prepared.input.domain.deploymentBlockHash !== manifest.deploymentBlockHash
    || prepared.input.purpose !== manifest.purpose || prepared.input.domain.rpcEnv !== manifest.rpcEnv
    || canonical(prepared.input.domain.bindings) !== canonical([...manifest.bindings].sort(
      (a, b) => a.role.localeCompare(b.role) || a.address.localeCompare(b.address))))) {
    throw new ExecutionError("DOMAIN", "preparation and execution domains disagree");
  }
  const artifact = async (name: string) => {
    const item = manifest.sources.find((s) => s.id === name);
    if (!item) throw new ExecutionError("DOMAIN", `missing bound ABI artifact ${name}`);
    const value = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse((await readBoundFile(item.path, bundle)).toString("utf8")));
    return new Interface(JSON.stringify(value.abi));
  };
  const migration = await artifact("migration-abi");
  const allocation = await artifact("allocation-abi");
  const recovery = await artifact("recovery-abi");
  const pkg = await artifact("package-abi");
  const syPackage = await artifact("sy-package-abi");
  const pricing = manifest.sources.some((s) => s.id === "pricing-abi") ? await artifact("pricing-abi") : undefined;
  return { manifest, prepared, abis: { migration, allocation, recovery, pkg, syPackage, ...(pricing ? { pricing } : {}) },
    domain: { manifest, preparedHash: prepared?.normalizedHash ?? null, payloadHash: prepared?.payloadHash ?? null } };
}
export type ExecutionDomain = Awaited<ReturnType<typeof loadExecution>>;

export async function checkRelationships(rpc: Rpc, domain: ExecutionDomain, allowUndeployed: boolean): Promise<void> {
  const m = domain.manifest;
  for (const role of ["proxy", "registry", "package", "facet"] as const) {
    const bindings = m.bindings.filter((b) => b.role === role);
    if (bindings.length === 0 || (role !== "facet" && bindings.length !== 1)) {
      throw new ExecutionError("DOMAIN", `missing or ambiguous ${role} identity`);
    }
  }
  for (const binding of m.bindings) {
    if (binding.role !== "facet" && binding.address !== m[binding.role]) throw new ExecutionError("DOMAIN", "wrong role address");
    const code = hex.parse(await rpc.send("eth_getCode", [binding.address, "latest"]));
    if (allowUndeployed && binding.role === "proxy" && code === "0x") continue;
    if (code === "0x" || keccak256(code) !== binding.codeHash) throw new ExecutionError("DOMAIN", `${binding.role} runtime changed`);
  }
  if (allowUndeployed && hex.parse(await rpc.send("eth_getCode", [m.proxy, "latest"])) === "0x") return;
  const registered = z.array(address).parse((await rpc.call(m.registry, registryAbi, "vaultsOfPackage", [m.package]))[0]);
  if (!registered.includes(m.proxy)) throw new ExecutionError("DOMAIN", "proxy is not registered under bound package");
  const facets: unknown = (await rpc.call(m.proxy, loupeAbi, "facets"))[0];
  const rows = z.array(z.tuple([address, z.array(z.string())])).parse(facets);
  for (const [facet] of rows) {
    if (!m.bindings.some((b) => b.role === "facet" && b.address === facet)) {
      throw new ExecutionError("DOMAIN", "installed facet not in reviewed bindings");
    }
  }
  const activated = (await rpc.call(m.proxy, domain.abis.migration, "migrationActivated"))[0] === true;
  const cuts: unknown = (await rpc.call(m.package, new Interface([
    "function facetCuts() view returns((address facetAddress,uint8 action,bytes4[] functionSelectors)[])",
  ]), "facetCuts"))[0];
  if (!Array.isArray(cuts)) throw new ExecutionError("DOMAIN", "invalid package cuts");
  for (const raw of cuts) {
    if (!(raw instanceof Result)) throw new ExecutionError("DOMAIN", "invalid facet cut");
    const expected = address.parse(raw.getValue("facetAddress"));
    for (const selector of z.array(z.string()).parse(raw.getValue("functionSelectors"))) {
      const removable = domain.abis.allocation.getFunction(selector) !== null;
      const actual = String((await rpc.call(m.proxy, loupeAbi, "facetAddress", [selector]))[0]).toLowerCase();
      if (actual !== (activated && removable ? "0x0000000000000000000000000000000000000000" : expected)) {
        throw new ExecutionError("DOMAIN", "installed selector differs from bound package");
      }
    }
  }
}

export function requirePrepared(domain: ExecutionDomain) {
  if (!domain.prepared) throw new ExecutionError("DOMAIN", "stage requires actual manual-book preparation");
  return domain.prepared;
}

export function nextBookId(domain: ExecutionDomain): string {
  const { manifest: m } = domain;
  const output = domain.abis.migration.getFunction("migrationWeightedPricing")?.outputs[0];
  if (!m.deployment || !m.pricing || !output) throw new ExecutionError("DOMAIN", "manual pricing requires bound package arguments and complete Inputs");
  return keccak256(AbiCoder.defaultAbiCoder().encode(["string", output], [
    "IndexedEx.manual-weighted-original-credit", { version: 2, chainId: m.chainId, consumer: m.proxy,
      weth: m.deployment.weth, originalDtf: m.deployment.originalDtf, id: `0x${"0".repeat(64)}`, inputs: m.pricing },
  ]));
}

export async function verifyDeployment(rpc: Rpc, domain: ExecutionDomain): Promise<void> {
  const m = domain.manifest;
  if (!m.deploymentReceipt || !m.deployment || m.deploymentBlockNumber === null || m.deploymentBlockHash === null) {
    throw new ExecutionError("DOMAIN", "deployed execution requires authenticated package receipt and arguments");
  }
  const saved = JSON.parse((await readReference(m.deploymentReceipt, m.bundle)).toString("utf8"));
  const txHash = z.object({ transactionHash: z.string() }).passthrough().parse(saved).transactionHash;
  const mined = await rpc.canonicalReceipt(txHash);
  const tx = z.object({ input: hex, to: address, blockHash: z.string() }).passthrough()
    .parse(await rpc.send("eth_getTransactionByHash", [txHash]));
  const registry = new Interface(["event NewVault(address indexed vault,address indexed package,bytes32 vaultFeeIds,bytes32 indexed contentsId,bytes4[] vaultTypes,address[] tokens)"]);
  if (!mined || BigInt(mined.status) !== 1n || canonical(saved) !== canonical(mined)
    || BigInt(mined.blockNumber).toString() !== m.deploymentBlockNumber || mined.blockHash !== m.deploymentBlockHash
    || tx.blockHash !== mined.blockHash || tx.to !== m.package
    || tx.input !== domain.abis.pkg.encodeFunctionData("deployVault", [m.deployment])
    || !mined.logs.some((l) => {
      if (l.address !== m.registry) return false;
      const event = registry.parseLog({ topics: [...l.topics], data: l.data });
      return event?.name === "NewVault" && String(event.args[0]).toLowerCase() === m.proxy
        && String(event.args[1]).toLowerCase() === m.package;
    })) throw new ExecutionError("DOMAIN", "bound deployment receipt/arguments differ");
}

export function compensationEventTopics(migration: Interface, scope: "configuration" | "all"): readonly string[] {
  const configured = {
    independent: "IndependentAllocationConfigured", nfts: "NftEntitlementConfigured",
    weightedLiquid: "WeightedLiquidEntitlementConfigured", weightedSy: "WeightedSyEntitlementConfigured",
    dtfCustodySe: "DtfCustodySeEntitlementConfigured", claimVault: "ClaimVaultEntitlementConfigured",
    weightedReceipt: "WeightedReceiptEntitlementConfigured", earlierReceipt: "EarlierReceiptEntitlementConfigured",
    earlierLiquid: "EarlierLiquidEntitlementConfigured", heldSeLp: "HeldSeLpEntitlementConfigured",
  } as const satisfies Record<(typeof configurationKinds)[number], string>;
  const configuration = configurationKinds.map((kind) => configured[kind]);
  const names = { configuration, all: [...configuration, "IndependentAllocationIssued"] }[scope];
  return names.map((name) => {
    const event = migration.getEvent(name);
    if (!event) throw new ExecutionError("DOMAIN", `missing compensation census event ABI: ${name}`);
    return event.topicHash;
  });
}

export async function verifyEmptyCensus(rpc: Rpc, domain: ExecutionDomain): Promise<void> {
  await verifyDeployment(rpc, domain);
  const topics = compensationEventTopics(domain.abis.migration, "all");
  const logs = z.array(rpcLog).parse(await rpc.send("eth_getLogs", [{
    address: domain.manifest.proxy, fromBlock: `0x${BigInt(domain.manifest.deploymentBlockNumber ?? "0").toString(16)}`,
    toBlock: "latest", topics: [topics],
  }]));
  if (logs.length) throw new ExecutionError("STATE", "nonempty configuration/issuance census requires exact preparation evidence");
}

export type HistoricalContext = {
  readonly domain: ExecutionDomain;
  readonly record: Intent;
  readonly saved: Completion | undefined;
};

export async function acceptedContext(
  accepted: AcceptedConfiguration, current: PreparationInput, ancestors: Set<string>, bundle?: FileRef,
  expectedStage: "configure" | "independent-issue" = "configure",
): Promise<HistoricalContext> {
  const originalPrepared = await readReference(accepted.manifest, bundle);
  await readReference(accepted.executionManifest, bundle);
  const journal = JSON.parse((await readReference(accepted.journalDomain, bundle)).toString("utf8"));
  const record = intent.parse(JSON.parse((await readReference(accepted.intent, bundle)).toString("utf8")));
  const domain = await loadExecution(accepted.executionManifest.path, { ancestors, census: "historical" }, bundle);
  if (!domain.prepared || domain.manifest.preparedManifest !== accepted.manifest.path
    || canonical(JSON.parse(originalPrepared.toString("utf8"))) !== canonical(domain.prepared)
    || canonical(journal) !== canonical(domain.domain)
    || fingerprint(canonical(domain.domain)) !== record.domainHash
    || domain.manifest.chainId !== current.domain.chainId || domain.manifest.proxy !== current.domain.proxy
    || domain.manifest.purpose !== current.purpose || domain.manifest.rpcEnv !== current.domain.rpcEnv
    || canonical(domain.prepared.input.domain.bindings) !== canonical(current.domain.bindings)
    || record.stage !== expectedStage) {
    throw new ExecutionError("DOMAIN", "historical intent does not bind its original execution/preparation/journal domain");
  }
  const { plan } = await import("./execution-plan.js");
  const { validateIntent } = await import("./execution.js");
  const operation = plan(domain, record.stage).find((o) => o.id === record.id);
  if (!operation) throw new ExecutionError("INTENT", "historical operation is outside original plan");
  validateIntent(record, operation, domain.manifest.chainId);
  const configs = Object.values(domain.prepared.payloads.configure).flat();
  if (!configs.some((r) => r.configurationId === accepted.configurationId)) {
    throw new ExecutionError("DOMAIN", "historical configuration is outside original preparation");
  }
  const decoded = domain.abis.allocation.decodeFunctionData(record.method, record.transaction.data);
  if (expectedStage === "configure") {
    const matching = plan(domain, "configure").find((o) => o.id === record.id);
    if (!matching || !configs.some((r) => r.configurationId === accepted.configurationId
      && r.pricing.bookId === String(decoded[1])
      && domain.abis.allocation.encodeFunctionData(record.method, [[
        "claimBasis" in r.input && r.input.claimBasis ? { original: r.input, ...r.input.claimBasis } : r.input,
      ], r.pricing.bookId]) === record.transaction.data)) {
      throw new ExecutionError("INTENT", "historical configure intent does not select accepted row");
    }
  } else if (!Array.from(decoded[0]).some((row) =>
    row instanceof Result && row.getValue("configurationId") === accepted.configurationId)) {
    throw new ExecutionError("INTENT", "historical issuance intent does not select accepted configuration");
  }
  const saved = accepted.completion ? completion.parse(JSON.parse(
    (await readReference(accepted.completion, bundle)).toString("utf8"))) : undefined;
  if (saved && (saved.intentHash !== fingerprint(canonical(record)) || saved.receipt.transactionHash !== record.transactionHash)) {
    throw new ExecutionError("INTENT", "historical completion does not bind exact intent");
  }
  return { domain, record, saved };
}

export async function authenticateHistory(context: HistoricalContext): Promise<Completion> {
  const { Rpc } = await import("./execution-rpc.js");
  const { captureCompletion } = await import("./execution-state.js");
  const rpc = new Rpc(context.domain.manifest);
  try {
    await rpc.guard({ kind: "simulate" });
    const mined = await rpc.canonicalReceipt(context.record.transactionHash);
    if (!mined) throw new ExecutionError("AMBIGUOUS", "historical intent has no canonical receipt");
    const actual = await captureCompletion(rpc, context.domain, context.record, mined);
    if (context.saved && canonical(context.saved) !== canonical(actual)) {
      throw new ExecutionError("STATE", "historical completion differs from canonical transaction-local evidence");
    }
    return actual;
  } finally { rpc.close(); }
}
