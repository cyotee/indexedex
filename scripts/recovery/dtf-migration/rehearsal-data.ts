import { readFile, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { AbiCoder, Interface, Result, keccak256 } from "ethers";
import type { ParamType } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { address, hash, hex, preparationInput } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { executionManifest, ExecutionError, packageArguments } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { LEGACY } from "./rehearsal-chain.js";
import { DEV } from "./execution-rpc.js";
import { nftOrigin } from "./payloads.js";

// Standard public Anvil mnemonic, derivation indices 100-103. The commonly
// used indices 0-2 carry historical EIP-7702 code on this fork, so cannot receive
// these NFTs without an ERC721Receiver implementation.
export const RECIPIENTS = [
  "0x8c3229ec621644789d7f61faa82c6d0e5f97d43d",
  "0x9586a4833970847aef259ad5bfb7aa8901ddf746",
  "0x0e9971c0005d91336c1441b8f03c1c4fe5fb4584",
  "0xc4c81d5c1851702d27d602aa8ff830a7689f17cc",
] as const;
export async function sourceFile(id: string, path: string) {
  const fullPath = resolve(path);
  const bytes = await readFile(fullPath);
  return { id, path: fullPath, sha256: fingerprint(bytes), bytes: String(bytes.length),
    provenance: { kind: "file" as const, authority: "synthetic-local rehearsal; not approved historical allocation" } };
}
export async function save(path: string, data: unknown) { await writeFile(path, `${canonical(data)}\n`, { flag: "wx" }); }
export async function interfaceFile(path: string) {
  const artifact = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(await readFile(path, "utf8")));
  return new Interface(JSON.stringify(artifact.abi));
}
function nativeJson(parameter: ParamType, value: unknown): unknown {
  if (parameter.baseType === "array") {
    if (!Array.isArray(value) || !parameter.arrayChildren) throw new ExecutionError("DOMAIN", "invalid ABI array");
    const child = parameter.arrayChildren;
    return value.map((entry) => nativeJson(child, entry));
  }
  if (parameter.baseType === "tuple") {
    if (!(value instanceof Result) || !parameter.components) throw new ExecutionError("DOMAIN", "invalid ABI tuple");
    return Object.fromEntries(parameter.components.map((child, index) => [child.name, nativeJson(child, value[index])]));
  }
  if (typeof value === "bigint") return value.toString();
  return value;
}
export async function bootstrapManifest(chain: RehearsalChain, environmentPath: string): Promise<ExecutionManifest> {
  const environment = z.object({
    proxy: address, registry: address, package: address, weth: address,
    pairToken: address, arguments: hex, proxyCodeHash: hash, facets: z.array(address),
  }).strict().parse(JSON.parse(await readFile(environmentPath, "utf8")));
  const sources = await Promise.all([
    sourceFile("migration-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"),
    sourceFile("allocation-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json"),
    sourceFile("recovery-abi", "out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json"),
    sourceFile("package-abi", "out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json"),
    sourceFile("environment", environmentPath),
  ]);
  const pkg = await interfaceFile("out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json");
  const parameter = pkg.getFunction("deployVault")?.inputs[0];
  if (!parameter) throw new ExecutionError("DOMAIN", "missing genuine package arguments ABI");
  const deployment = packageArguments.parse(nativeJson(parameter, AbiCoder.defaultAbiCoder().decode([parameter], environment.arguments)[0]));
  const bindings = [{ role: "proxy" as const, address: environment.proxy, codeHash: environment.proxyCodeHash }];
  const bound = [
    { role: "registry", address: environment.registry }, { role: "package", address: environment.package },
    ...environment.facets.map((address) => ({ role: "facet", address })),
  ];
  const allBindings = [...bindings];
  // Runtime boundary is parsed by executionManifest below.
  const otherBindings = [];
  for (const binding of bound) {
    const code = hex.parse(await chain.send("eth_getCode", [binding.address, "latest"]));
    if (code === "0x") throw new ExecutionError("DOMAIN", `environment did not deploy ${binding.role}`);
    otherBindings.push({ ...binding, codeHash: keccak256(code) });
  }
  const metadata = z.object({
    instanceId: z.string(), forkedNetwork: z.object({ forkBlockNumber: z.number().int().safe(), forkBlockHash: hash }).passthrough(),
  }).passthrough().parse(await chain.send("anvil_metadata", []));
  const deadline = (await chain.timestamp() + 3600n).toString();
  return executionManifest.parse({
    version: "dtf-operator-execution-v1", purpose: "synthetic-local", chainId: "4663", rpcEnv: "DTF_OPERATOR_LOCAL_RPC",
    signer: DEV, local: { instanceId: metadata.instanceId, forkBlockNumber: String(metadata.forkedNetwork.forkBlockNumber),
      forkBlockHash: metadata.forkedNetwork.forkBlockHash }, proxy: environment.proxy, registry: environment.registry,
    package: environment.package, snapshotId: null, preparedManifest: null, deployment, sources,
    bindings: [...allBindings, ...otherBindings],
    funding: { donations: [{ id: `0x${fingerprint("synthetic donation one")}`, tokens: [environment.weth, LEGACY.dtf],
      amounts: ["900000000000000000000", "1000000000000000000000"], nativeAmount: "100000000000000000000", minimum: "0", deadline }],
    genesis: { legs: [
      { token: environment.weth, amount: "1000000000000000000000", minSharesOut: "1" },
      { token: LEGACY.dtf, amount: "1000000000000000000000", minSharesOut: "1" },
    ], anchorIndex: "0", minimum: "1", deadline } },
  });
}

export async function preparationFixture(chain: RehearsalChain, manifest: ExecutionManifest, directory: string) {
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const snapshot: unknown = (await chain.call(manifest.proxy, migration, "migrationSnapshot"))[0];
  if (!(snapshot instanceof Result)) throw new ExecutionError("STATE", "snapshot tuple");
  const block = z.object({ hash, number: z.string() }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["latest", false]));
  const domain = { chainId: "4663", proxy: manifest.proxy, snapshotId: hash.parse(snapshot.getValue("id")),
    blockNumber: BigInt(block.number).toString(), blockHash: block.hash, rpcEnv: manifest.rpcEnv,
    snapshotArtifact: resolve("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"), bindings: manifest.bindings };
  const recipients = RECIPIENTS;
  for (const recipient of recipients) {
    if (await chain.send("eth_getCode", [recipient, "latest"]) !== "0x") throw new ExecutionError("DOMAIN", "synthetic recipient is no longer an EOA");
  }
  await save(join(directory, "recipient-identity.json"), { recipients, derivationIndices: [100, 101, 102, 103], observedCode: "0x" });
  const originals = recipients.map((_, i) => ({ entitlementId: `0x${fingerprint(`synthetic independent ${i}`)}`,
    originalEth: "1000000000000", originalDtf: "0", evidenceId: `0x${fingerprint(`synthetic proof ${i}`)}` }));
  const nfts = [
    { collection: LEGACY.weighted, tokenId: "4", originalUnits: "281387179", originalEth: "30000000000000000",
      originalDtf: "0", evidenceId: "0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe", contributionsKnown: true as const },
    { collection: LEGACY.weighted, tokenId: "26", originalUnits: "56299", originalEth: "0",
      originalDtf: "50000000000000000000", evidenceId: "0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d", contributionsKnown: true as const },
    { collection: LEGACY.earlier, tokenId: "3", originalUnits: "562524912595035608166", originalEth: "2000000000000000000",
      originalDtf: "0", evidenceId: "0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75", contributionsKnown: true as const },
  ];
  const origins = [...originals.map((o) => ({ id: o.entitlementId, units: "1", category: "independent" })),
    ...nfts.map((n) => ({ id: nftOrigin(domain, n), units: n.originalUnits, category: n.collection === LEGACY.weighted ? "weighted-nft" : "earlier-nft" }))];
  const exposures = origins.map((o) => ({ originId: o.id, category: o.category, originalUnits: o.units,
    descendants: [{ id: `0x${fingerprint(`${o.id}:descendant`)}`, units: o.units }], recoveredUnits: "0", excludedUnits: "0" }));
  const evidencePath = join(directory, "synthetic-originals.json");
  await save(evidencePath, { originals, nfts, exposures });
  const proof = (pointer: string) => ({ sourceId: "synthetic-proof", pointer });
  const input = preparationInput.parse({
    version: "dtf-operator-preparation-v1", purpose: "synthetic-local", domain,
    sources: [...manifest.sources, await sourceFile("synthetic-proof", evidencePath)],
    exposures: exposures.map((e, i) => ({ ...e, proof: proof(`/exposures/${i}`) })),
    independent: recipients.map((recipient, i) => ({ recipient, evidenceId: `0x${fingerprint(`synthetic group ${i}`)}`,
      entitlements: [{ original: originals[i], proof: proof(`/originals/${i}`) }] })),
    nfts: nfts.map((original, i) => ({ original, proof: proof(`/nfts/${i}`) })),
    issueRecipients: recipients.slice(0, 3),
    harvest: { steps: [{ stage: "WeightedClaim", tokenId: "4", amount: "0", minimum: "0" }],
      deadline: (await chain.timestamp() + 365n * 86400n).toString() },
  });
  await save(join(directory, "input.json"), input);
  return input;
}

export async function replacementFixture(input: PreparationInput, directory: string) {
  const independent = input.independent.map((row) => row.recipient !== RECIPIENTS[0] ? row : {
    ...row, entitlements: row.entitlements.map((e) => ({
      ...e, original: { ...e.original, originalEth: (BigInt(e.original.originalEth) * 2n).toString() },
    })),
  });
  const evidencePath = join(directory, "synthetic-replacement-originals.json");
  await save(evidencePath, {
    originals: independent.flatMap((row) => row.entitlements.map((e) => e.original)),
    nfts: input.nfts.map((row) => row.original),
    exposures: input.exposures.map(({ proof: _proof, ...exposure }) => exposure),
  });
  const replacement = preparationInput.parse({ ...input, independent,
    sources: [...input.sources.filter((s) => s.id !== "synthetic-proof"), await sourceFile("synthetic-proof", evidencePath)] });
  await save(join(directory, "replacement-input.json"), replacement);
  return replacement;
}
