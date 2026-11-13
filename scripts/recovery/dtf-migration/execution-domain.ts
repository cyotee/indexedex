import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Interface, Result, keccak256 } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { validateManifest } from "./preparation.js";
import { address, hex } from "./schema.js";
import { ExecutionError, executionManifest } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import type { Rpc } from "./execution-rpc.js";
import { loadSavedBundle } from "./bundle.js";

export const registryAbi = new Interface(["function vaultsOfPackage(address) view returns (address[])"]);
export const loupeAbi = new Interface([
  "function facetAddress(bytes4) view returns (address)",
  "function facets() view returns ((address facetAddress,bytes4[] functionSelectors)[])",
]);

export async function loadExecution(path: string) {
  const manifest = executionManifest.parse(JSON.parse(await readFile(resolve(path), "utf8")));
  if (manifest.bundle) {
    const saved = await loadSavedBundle(manifest.bundle.path, manifest.bundle);
    if (saved.kind !== "execution"
      || canonical(manifest) !== canonical({ ...saved.execution, preparedManifest: manifest.preparedManifest })
      || Boolean(saved.prepared) !== Boolean(manifest.preparedManifest)) {
      throw new ExecutionError("DOMAIN", "materialized execution differs from saved template");
    }
  }
  for (const source of manifest.sources) {
    if (!source.path.startsWith("/")) throw new ExecutionError("DOMAIN", "execution source paths must be absolute");
    const bytes = await readFile(source.path);
    if (fingerprint(bytes) !== source.sha256 || String(bytes.length) !== source.bytes) {
      throw new ExecutionError("DOMAIN", `source binding differs: ${source.id}`);
    }
  }
  const prepared = manifest.preparedManifest ? await validateManifest(manifest.preparedManifest) : undefined;
  if (manifest.bundle && prepared && canonical(prepared.input.bundle) !== canonical(manifest.bundle)) {
    throw new ExecutionError("DOMAIN", "execution and preparation bundles differ");
  }
  if (prepared && (prepared.input.domain.chainId !== manifest.chainId
    || prepared.input.domain.proxy !== manifest.proxy || prepared.input.domain.snapshotId !== manifest.snapshotId
    || prepared.input.purpose !== manifest.purpose || prepared.input.domain.rpcEnv !== manifest.rpcEnv
    || canonical(prepared.input.domain.bindings) !== canonical([...manifest.bindings].sort(
      (a, b) => a.role.localeCompare(b.role) || a.address.localeCompare(b.address))))) {
    throw new ExecutionError("DOMAIN", "preparation and execution domains disagree");
  }
  if (!prepared && manifest.snapshotId) throw new ExecutionError("DOMAIN", "snapshot requires validated preparation");
  const artifact = async (name: string) => {
    const item = manifest.sources.find((s) => s.id === name);
    if (!item) throw new ExecutionError("DOMAIN", `missing bound ABI artifact ${name}`);
    const value = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(await readFile(item.path, "utf8")));
    return new Interface(JSON.stringify(value.abi));
  };
  const migration = await artifact("migration-abi");
  const allocation = await artifact("allocation-abi");
  const recovery = await artifact("recovery-abi");
  const pkg = await artifact("package-abi");
  return { manifest, prepared, abis: { migration, allocation, recovery, pkg },
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
  if (m.snapshotId) {
    const snapshot = await rpc.call(m.proxy, domain.abis.migration, "migrationSnapshot");
    if (snapshot[0].id !== m.snapshotId) throw new ExecutionError("DOMAIN", "current snapshot changed");
  }
}

export function requirePrepared(domain: ExecutionDomain) {
  if (!domain.prepared) throw new ExecutionError("DOMAIN", "stage requires actual post-capture preparation");
  return domain.prepared;
}
