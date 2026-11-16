import { readFile, writeFile } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { AbiCoder, Interface, Result, keccak256 } from "ethers";
import type { ParamType } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { address, hash, hex, preparationInput } from "./schema.js";
import type { AcceptedConfiguration, ClaimedSyCertificate, PreparationInput, PricingDirective } from "./schema.js";
import { claimedSyEvidenceId } from "./claimed-sy.js";
import { executionManifest, ExecutionError, packageArguments } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { LEGACY } from "./rehearsal-chain.js";
import { DEV } from "./execution-rpc.js";
import { dtfCustodySeSource, claimVaultSource, weightedReceiptSource, earlierReceiptSource, earlierLiquidSource, nftOrigin } from "./payloads.js";
import { authorityInput } from "./bundle.js";

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
export async function captureOriginalInputBytes(input: PreparationInput, path: string) {
  const records = [];
  for (const source of input.sources) {
    const raw = await readFile(source.path);
    if (fingerprint(raw) !== source.sha256 || String(raw.length) !== source.bytes) {
      throw new ExecutionError("DOMAIN", "original source changed before lossless capture");
    }
    records.push({ ...source, rawBase64: raw.toString("base64"), terminalNewline: raw.at(-1) === 10 });
  }
  await save(path, { encoding: "lossless original bytes, not normalized JSON or reconstructed ABI", records });
}
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
export async function bootstrapManifest(chain: RehearsalChain, environmentPath: string,
  authorities: z.infer<typeof authorityInput>["sources"]): Promise<ExecutionManifest> {
  authorityInput.parse({ version: "dtf-operator-authorities-v1", sources: authorities });
  const environment = z.object({
    proxy: address, registry: address, package: address, weth: address,
    pairToken: address, arguments: hex, proxyCodeHash: hash, facets: z.array(address),
  }).strict().parse(JSON.parse(await readFile(environmentPath, "utf8")));
  const sources = await Promise.all([
    sourceFile("migration-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"),
    sourceFile("allocation-abi", "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json"),
    sourceFile("recovery-abi", "out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json"),
    sourceFile("package-abi", "out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json"),
    sourceFile("sy-package-abi", "out/IUniswapV4DetfMigrationSYDFPkg.sol/IUniswapV4DetfMigrationSYDFPkg.json"),
    sourceFile("environment", environmentPath),
    sourceFile("claim-vault-acquisition", join(dirname(environmentPath), "claim-vault-acquisition.json")),
    sourceFile("dtf-custody-acquisition", join(dirname(environmentPath), "dtf-custody-se-acquisition.json")),
    sourceFile("weighted-receipt-acquisition", join(dirname(environmentPath), "weighted-receipt-acquisition.json")),
    sourceFile("earlier-liquid-acquisition", join(dirname(environmentPath), "earlier-liquid-acquisition.json")),
    sourceFile("held-se-lp-acquisition", join(dirname(environmentPath), "held-se-lp-acquisition.json")),
    sourceFile("earlier-receipt-acquisition", join(dirname(environmentPath), "earlier-receipt-acquisition.json")),
    ...authorities,
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
  const runtimeCode = [];
  for (const binding of bound) {
    const code = hex.parse(await chain.send("eth_getCode", [binding.address, "latest"]));
    if (code === "0x") throw new ExecutionError("DOMAIN", `environment did not deploy ${binding.role}`);
    otherBindings.push({ ...binding, codeHash: keccak256(code) });
    runtimeCode.push({ ...binding, code, codeHash: keccak256(code) });
  }
  await save(join(dirname(environmentPath), "runtime-code.json"), runtimeCode);
  const metadata = z.object({
    instanceId: z.string(), forkedNetwork: z.object({ forkBlockNumber: z.number().int().safe(), forkBlockHash: hash }).passthrough(),
  }).passthrough().parse(await chain.send("anvil_metadata", []));
  const deadline = (await chain.timestamp() + 3600n).toString();
  return executionManifest.parse({
    version: "dtf-operator-execution-v2", purpose: "synthetic-local", chainId: "4663", rpcEnv: "DTF_OPERATOR_LOCAL_RPC",
    signer: DEV, local: { instanceId: metadata.instanceId, forkBlockNumber: String(metadata.forkedNetwork.forkBlockNumber),
      forkBlockHash: metadata.forkedNetwork.forkBlockHash }, proxy: environment.proxy, registry: environment.registry,
    package: environment.package, bookId: null, pricing: null,
    deploymentReceipt: null, deploymentBlockNumber: null, deploymentBlockHash: null,
    preparedManifest: null, deployment, sources,
    bindings: [...allBindings, ...otherBindings],
    ownerBond: { token: environment.weth, amount: "1000000000000000000", duration: "7776000", deadline },
    funding: { donations: [{ id: `0x${fingerprint("synthetic donation one")}`, tokens: [environment.weth, LEGACY.dtf],
      amounts: ["900000000000000000000", "1000000000000000000000"], nativeAmount: "100000000000000000000", minimum: "0", deadline }],
    genesis: { legs: [
      { token: environment.weth, amount: "1000000000000000000000", minSharesOut: "1" },
      { token: LEGACY.dtf, amount: "1000000000000000000000", minSharesOut: "1" },
    ], anchorIndex: "0", minimum: "1", deadline } },
  });
}

export async function preparationFixture(chain: RehearsalChain, manifest: ExecutionManifest, directory: string,
  acquisition: { readonly custodySe: { readonly originalWallet: string; readonly shares: string };
    readonly claimVault: { readonly originalWallet: string; readonly shares: string };
    readonly weightedReceipt: { readonly originalWallet: string; readonly gons: string };
    readonly earlierReceipt: { readonly originalWallet: string; readonly internalShares: string };
    readonly earlierLiquid: { readonly originalWallet: string; readonly units: string };
    readonly heldSeLp: readonly { readonly source: string; readonly originalWallet: string; readonly units: string }[];
    readonly claimedSy?: readonly { readonly q0: string; readonly certificate: Omit<ClaimedSyCertificate, "pricingSet"> }[] }) {
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const book: unknown = (await chain.call(manifest.proxy, migration, "migrationWeightedPricing"))[0];
  if (!(book instanceof Result)) throw new ExecutionError("STATE", "manual book tuple");
  if (!manifest.deploymentReceipt || manifest.deploymentBlockNumber === null || manifest.deploymentBlockHash === null) {
    throw new ExecutionError("DOMAIN", "rehearsal preparation needs its actual deployment receipt");
  }
  const block = z.object({ hash, number: z.string() }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["latest", false]));
  const domain = { chainId: "4663", proxy: manifest.proxy, bookId: hash.parse(book.getValue("id")),
    blockNumber: BigInt(block.number).toString(), blockHash: block.hash, rpcEnv: manifest.rpcEnv,
    deploymentBlockNumber: manifest.deploymentBlockNumber, deploymentBlockHash: manifest.deploymentBlockHash,
    deploymentProof: { sourceId: "deployment-receipt", pointer: "" },
    pricingArtifact: resolve("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json"), bindings: manifest.bindings };
  const recipients = RECIPIENTS;
  for (const recipient of recipients) {
    if (await chain.send("eth_getCode", [recipient, "latest"]) !== "0x") throw new ExecutionError("DOMAIN", "synthetic recipient is no longer an EOA");
  }
  await save(join(directory, "recipient-identity.json"), { recipients, derivationIndices: [100, 101, 102, 103], observedCode: "0x" });
  const originals = recipients.map((_, i) => ({ entitlementId: `0x${fingerprint(`synthetic independent ${i}`)}`,
    originalEth: "1000000000000", originalDtf: "0", evidenceId: `0x${fingerprint(`synthetic proof ${i}`)}` }));
  const nfts = [
    { collection: LEGACY.weighted, tokenId: "4", originalWallet: "0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8",
      originalUnits: "281387179", originalEth: "30000000000000000",
      originalDtf: "0", evidenceId: "0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe", contributionsKnown: true as const },
    { collection: LEGACY.weighted, tokenId: "26", originalWallet: "0xc379feb4182211abe71a34858265e4bf5ff35e06",
      originalUnits: "56299", originalEth: "0",
      originalDtf: "50000000000000000000", evidenceId: "0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d", contributionsKnown: true as const },
    { collection: LEGACY.earlier, tokenId: "3", originalWallet: "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed",
      originalUnits: "562524912595035608166", originalEth: "2000000000000000000",
      originalDtf: "0", evidenceId: "0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75", contributionsKnown: true as const },
    { collection: LEGACY.weighted, tokenId: "6", originalWallet: "0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8",
      originalUnits: "740825635", originalEth: "80000000000000000", originalDtf: "0",
      evidenceId: "0xeefb57d4fd369c08c6050f125d93f19c7171c557f0280270049ed4c6e613a917", contributionsKnown: true as const },
    { collection: LEGACY.earlier, tokenId: "9", originalWallet: "0x76b60dcf71da2294f8aa034432d925d1eed8cf68",
      originalUnits: "26355776123062198039", originalEth: "100000000000000", originalDtf: "0",
      evidenceId: "0xf504bc3b5ec0452769f18c7c53f759dd4579afe9622ea72db6736bddb83d6e55", contributionsKnown: true as const },
  ];
  const weightedLiquid = [{
    originalId: `0x${fingerprint("synthetic W-L original allocation")}`,
    originalWallet: "0x082cb14f04d9c485473dedc00d604d7e9abca303",
    source: LEGACY.detf, originalUnits: "21225531", originalEth: "10000000000000000",
    originalDtf: "0", evidenceId: `0x${fingerprint("synthetic W-L Q0 and components; not an approved user allocation")}`,
    contributionsKnown: true as const,
  }];
  const weightedSy = [{
    originalId: `0x${fingerprint("synthetic W-Y original allocation")}`,
    originalWallet: "0x11c17f25e958e4637dd26ca362adeae12e24ed5b",
    source: LEGACY.sy, originalUnits: "8094", originalEth: "10000000000000000",
    originalDtf: "0", evidenceId: `0x${fingerprint("synthetic WY Q0 and components; not an approved allocation")}`,
    contributionsKnown: true as const,
  }];
  const captureBlock = z.object({ hash, number: z.string(), transactions: z.array(hash) }).passthrough().parse(
    await chain.send("eth_getBlockByNumber", [block.number, false]));
  const captureTransaction = captureBlock.transactions[0];
  if ((acquisition.claimedSy?.length ?? 0) > 0 && (captureBlock.transactions.length !== 1 || !captureTransaction)) {
    throw new ExecutionError("DOMAIN", "fixture requires actual isolated snapshot capture receipt");
  }
  const claimedSy = (acquisition.claimedSy ?? []).map(({ q0, certificate: sourceCertificate }) => {
    if (!captureTransaction) throw new ExecutionError("DOMAIN", "missing snapshot capture transaction");
    const certificate = { ...sourceCertificate, pricingSet: { bookId: domain.bookId, transactionHash: captureTransaction,
      blockNumber: domain.blockNumber, blockHash: domain.blockHash } };
    const review = certificate.review;
    const original = {
      originalId: review.originalId, originalWallet: review.originalWallet, source: certificate.sy,
      originalUnits: q0, originalEth: review.originalEth, originalDtf: review.originalDtf,
      evidenceId: `0x${fingerprint("unsealed certificate placeholder")}`, contributionsKnown: true as const,
    };
    return { original: { ...original, evidenceId: claimedSyEvidenceId(domain, original, certificate) },
      claimedOrigin: certificate };
  });
  weightedSy.push(...claimedSy.map((row) => row.original));
  const dtfCustodySe = [{
    originalId: `0x${fingerprint("synthetic W-SD original allocation")}`,
    originalWallet: acquisition.custodySe.originalWallet, source: dtfCustodySeSource, originalUnits: acquisition.custodySe.shares,
    originalEth: "0", originalDtf: "1000000000000000000",
    evidenceId: `0x${fingerprint("synthetic W-SD components; real controlled-wallet source acquisition")}`,
    contributionsKnown: true as const,
  }];
  const claimVault = [{
    originalId: `0x${fingerprint("synthetic direct claim-vault original")}`,
    originalWallet: acquisition.claimVault.originalWallet, source: claimVaultSource, originalUnits: acquisition.claimVault.shares,
    originalEth: "0", originalDtf: "1000000000000000000",
    evidenceId: `0x${fingerprint("synthetic native19 originals; actual controlled source acquisition")}`,
    contributionsKnown: true as const,
  }];
  const weightedReceipt = [{
    originalId: `0x${fingerprint("synthetic WS original eligible gons")}`,
    originalWallet: acquisition.weightedReceipt.originalWallet, source: weightedReceiptSource,
    originalUnits: acquisition.weightedReceipt.gons, originalEth: "10000000000000000", originalDtf: "0",
    evidenceId: `0x${fingerprint("synthetic WS original exposure; exact genuine101-native acquisition gons")}`,
    contributionsKnown: true as const,
  }];
  const earlierReceipt = [{
    originalId: `0x${fingerprint("synthetic ER eligible original internal shares")}`,
    originalWallet: acquisition.earlierReceipt.originalWallet, source: earlierReceiptSource,
    originalUnits: acquisition.earlierReceipt.internalShares, originalEth: "10000000000000000", originalDtf: "0",
    evidenceId: `0x${fingerprint("synthetic original ER components; genuine transfer10000 allocation; no reward exposure")}`,
    contributionsKnown: true as const,
  }];
  const earlierLiquid = [{
    originalId: `0x${fingerprint("synthetic ED native18 original") }`,
    originalWallet: acquisition.earlierLiquid.originalWallet, source: earlierLiquidSource,
    originalUnits: acquisition.earlierLiquid.units, originalEth: "10000000000000000", originalDtf: "0",
    evidenceId: `0x${fingerprint("synthetic ED components; genuine controlled acquisition; not NFT purchase inputs")}`,
    contributionsKnown: true as const,
  }];
  const heldSeLp = acquisition.heldSeLp.map((row) => ({
    originalId: `0x${fingerprint(`synthetic original native18 held SE LP ${row.source}`)}`,
    originalWallet: row.originalWallet, source: row.source, originalUnits: row.units,
    originalEth: "10000000000000000", originalDtf: "0",
    evidenceId: `0x${fingerprint(`synthetic components only; authentic controlled donation ${row.source}`)}`,
    contributionsKnown: true as const,
  }));
  const origins = [...originals.map((o) => ({ id: o.entitlementId, units: "1", category: "independent" })),
    ...nfts.map((n) => ({ id: nftOrigin(domain, n), units: n.originalUnits, category: n.collection === LEGACY.weighted ? "weighted-nft" : "earlier-nft" })),
    ...weightedLiquid.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "weighted-liquid" })),
    ...weightedSy.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "weighted-sy" })),
    ...dtfCustodySe.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "dtf-custody-se" })),
    ...claimVault.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "claim-vault" })),
    ...weightedReceipt.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "weighted-receipt" })),
    ...earlierReceipt.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "earlier-receipt" })),
    ...earlierLiquid.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "earlier-liquid" })),
    ...heldSeLp.map((n) => ({ id: n.originalId, units: n.originalUnits, category: "held-se-lp" }))];
  const exposures = origins.map((o) => ({ originId: o.id, category: o.category, originalUnits: o.units,
    descendants: [{ id: `0x${fingerprint(`${o.id}:descendant`)}`, units: o.units }], recoveredUnits: "0", excludedUnits: "0" }));
  const evidencePath = join(directory, "synthetic-originals.json");
  await save(evidencePath, { originals, nfts, weightedLiquid, weightedSy, claimedSy, dtfCustodySe, claimVault, weightedReceipt, earlierReceipt, earlierLiquid, heldSeLp, exposures });
  const proof = (pointer: string) => ({ sourceId: "synthetic-proof", pointer });
  const pricing = { kind: "load", bookId: domain.bookId, replaces: null };
  if (!captureTransaction) throw new ExecutionError("DOMAIN", "manual setter receipt missing");
  const input = preparationInput.parse({
    version: "dtf-operator-preparation-v2", purpose: "synthetic-local", domain,
    books: [{ bookId: domain.bookId, encodedBook: migration.encodeFunctionResult("migrationWeightedPricing", [book]),
      observationBlockNumber: domain.blockNumber, observationBlockHash: domain.blockHash, setTransactionHash: captureTransaction }],
    issuedHistory: [],
    sources: [...manifest.sources, await sourceFile("synthetic-proof", evidencePath)],
    exposures: exposures.map((e, i) => ({ ...e, proof: proof(`/exposures/${i}`) })),
    independent: recipients.map((recipient, i) => ({ pricing, recipient, evidenceId: `0x${fingerprint(`synthetic group ${i}`)}`,
      entitlements: [{ original: originals[i], proof: proof(`/originals/${i}`) }] })),
    nfts: nfts.map((original, i) => ({ pricing, original, proof: proof(`/nfts/${i}`) })),
    weightedLiquid: weightedLiquid.map((original, i) => ({ pricing, original, proof: proof(`/weightedLiquid/${i}`) })),
    weightedSy: weightedSy.map((original, i) => i === 0
      ? { pricing, original, proof: proof(`/weightedSy/${i}`) }
      : { ...claimedSy[i - 1], pricing, proof: proof(`/claimedSy/${i - 1}`) }),
    dtfCustodySe: dtfCustodySe.map((original, i) => ({ pricing, original, proof: proof(`/dtfCustodySe/${i}`) })),
    claimVault: claimVault.map((original, i) => ({ pricing, original, proof: proof(`/claimVault/${i}`) })),
    weightedReceipt: weightedReceipt.map((original, i) => ({ pricing, original, proof: proof(`/weightedReceipt/${i}`) })),
    earlierLiquid: earlierLiquid.map((original, i) => ({ pricing, original, proof: proof(`/earlierLiquid/${i}`) })),
    heldSeLp: heldSeLp.map((original, i) => ({ pricing, original, proof: proof(`/heldSeLp/${i}`) })),
    earlierReceipt: earlierReceipt.map((original, i) => ({ pricing, original, proof: proof(`/earlierReceipt/${i}`) })),
    issueRecipients: recipients.slice(0, 3),
    harvest: { steps: [{ stage: "WeightedClaim", tokenId: "4", amount: "0", minimum: "0" }],
      deadline: (await chain.timestamp() + 365n * 86400n).toString() },
  });
  await save(join(directory, "input.json"), input);
  return input;
}

export async function replacementFixture(input: PreparationInput, directory: string) {
  const reload = (pricing: PricingDirective): PricingDirective => pricing.kind === "retain"
    ? { kind: "load", bookId: input.domain.bookId, replaces: pricing.accepted } : pricing;
  const independent = input.independent.map((row) => row.recipient !== RECIPIENTS[0] ? row : {
    ...row, pricing: reload(row.pricing), entitlements: row.entitlements.map((e) => ({
      ...e, original: { ...e.original, originalEth: (BigInt(e.original.originalEth) * 2n).toString() },
    })),
  });
  const weightedLiquid = input.weightedLiquid.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original,
      originalEth: (BigInt(row.original.originalEth) * 3n / 5n).toString(),
      originalUnits: (BigInt(row.original.originalUnits) - 1n).toString(),
    },
  }));
  const weightedSy = input.weightedSy.map((row) => row.claimedOrigin ? row : ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalEth: "6000000000000000", originalUnits: "8087" },
  }));
  const dtfCustodySe = input.dtfCustodySe.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalDtf: "600000000000000000",
      originalUnits: (BigInt(row.original.originalUnits) - 7n).toString() },
  }));
  const claimVault = input.claimVault.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalDtf: "600000000000000000",
      originalUnits: (BigInt(row.original.originalUnits) - 7n).toString() },
  }));
  const weightedReceipt = input.weightedReceipt.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const earlierReceipt = input.earlierReceipt.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const earlierLiquid = input.earlierLiquid.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const heldSeLp = input.heldSeLp.map((row) => ({
    ...row, pricing: reload(row.pricing), original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const exposures = input.exposures.map((row) => {
    const liquid = [...weightedLiquid, ...weightedSy, ...dtfCustodySe, ...claimVault, ...weightedReceipt, ...earlierReceipt, ...earlierLiquid, ...heldSeLp].find((entry) => entry.original.originalId === row.originId);
    return liquid ? { ...row, originalUnits: liquid.original.originalUnits,
      descendants: row.descendants.map((entry) => ({ ...entry, units: liquid.original.originalUnits })) } : row;
  });
  const evidencePath = join(directory, "synthetic-replacement-originals.json");
  await save(evidencePath, {
    originals: independent.flatMap((row) => row.entitlements.map((e) => e.original)),
    nfts: input.nfts.map((row) => row.original),
    weightedLiquid: weightedLiquid.map((row) => row.original),
    weightedSy: weightedSy.map((row) => row.original),
    claimedSy: weightedSy.filter((row) => row.claimedOrigin).map(({ original, claimedOrigin }) => ({ original, claimedOrigin })),
    dtfCustodySe: dtfCustodySe.map((row) => row.original),
    claimVault: claimVault.map((row) => row.original),
    weightedReceipt: weightedReceipt.map((row) => row.original),
    earlierReceipt: earlierReceipt.map((row) => row.original),
    earlierLiquid: earlierLiquid.map((row) => row.original),
    heldSeLp: heldSeLp.map((row) => row.original),
    exposures: exposures.map(({ proof: _proof, ...exposure }) => exposure),
  });
  const { bundle: _bundle, ...native } = input;
  // The newly written document has this array order, which need not match the
  // earlier raw document after normalization. Bind to its actual new positions.
  const proof = (pointer: string) => ({ sourceId: "synthetic-proof", pointer });
  const repoint = <T extends { readonly proof: { readonly sourceId: string; readonly pointer: string } }>(
    rows: readonly T[], field: string,
  ) => rows.map((row, index) => ({ ...row, proof: proof(`/${field}/${index}`) }));
  let originalIndex = 0;
  let claimedIndex = 0;
  const replacement = preparationInput.parse({ ...native,
    independent: independent.map((row) => ({ ...row, entitlements: row.entitlements.map((entry) => ({
      ...entry, proof: proof(`/originals/${originalIndex++}`),
    })) })),
    nfts: repoint(input.nfts, "nfts"),
    weightedLiquid: repoint(weightedLiquid, "weightedLiquid"),
    weightedSy: weightedSy.map((row, index) => ({ ...row,
      proof: proof(row.claimedOrigin ? `/claimedSy/${claimedIndex++}` : `/weightedSy/${index}`) })),
    dtfCustodySe: repoint(dtfCustodySe, "dtfCustodySe"),
    claimVault: repoint(claimVault, "claimVault"), weightedReceipt: repoint(weightedReceipt, "weightedReceipt"),
    earlierReceipt: repoint(earlierReceipt, "earlierReceipt"), earlierLiquid: repoint(earlierLiquid, "earlierLiquid"),
    heldSeLp: repoint(heldSeLp, "heldSeLp"), exposures: repoint(exposures, "exposures"),
    sources: [...input.sources.filter((s) => s.id !== "synthetic-proof"), await sourceFile("synthetic-proof", evidencePath)] });
  await save(join(directory, "replacement-input.json"), replacement);
  return replacement;
}

/** Fresh v2 evidence references only; this never imports, moves, or rewrites a journal. */
export async function reconciledFixtureInput(manifestPath: string, configureCheckpoint: string, issueCheckpoint: string) {
  const { loadExecution, requirePrepared } = await import("./execution-domain.js");
  const { plan } = await import("./execution-plan.js");
  const { selectedConfiguration } = await import("./execution-state.js");
  const domain = await loadExecution(manifestPath);
  const prepared = requirePrepared(domain);
  if (!domain.manifest.preparedManifest) throw new ExecutionError("DOMAIN", "reconciliation requires original preparation");
  const reference = async (path: string) => {
    const bytes = await readFile(path);
    return { path: resolve(path), sha256: fingerprint(bytes), bytes: String(bytes.length) };
  };
  const manifest = await reference(domain.manifest.preparedManifest);
  const execution = await reference(manifestPath);
  const configured = new Map<string, AcceptedConfiguration>();
  for (const operation of plan(domain, "configure")) {
    const { row } = selectedConfiguration(domain, operation);
    configured.set(row.configurationId, {
      manifest, executionManifest: execution, journalDomain: await reference(join(configureCheckpoint, "domain.json")),
      configurationId: row.configurationId, intent: await reference(join(configureCheckpoint, `${operation.id}.intent.json`)),
      completion: await reference(join(configureCheckpoint, `${operation.id}.receipt.json`)),
    });
  }
  const retain = (configurationId: string): PricingDirective => {
    const accepted = configured.get(configurationId);
    const row = Object.values(prepared.payloads.configure).flat().find((r) => r.configurationId === configurationId);
    if (!accepted || !row) throw new ExecutionError("STATE", "configuration has no original journal evidence");
    return { kind: "retain", bookId: row.pricing.bookId, accepted };
  };
  const history = [];
  for (const operation of plan(domain, "independent-issue")) {
    const requests = z.array(z.instanceof(Result)).parse(domain.abis.allocation.decodeFunctionData(operation.method, operation.transaction.data)[0]);
    for (const request of requests) {
      const configuration = configured.get(String(request.getValue("configurationId")));
      if (!configuration) throw new ExecutionError("STATE", "issuance has no original configure evidence");
      history.push({ recipient: String(request.getValue("recipient")).toLowerCase(), configuration,
        issuancePreparedManifest: manifest, issuanceExecutionManifest: execution,
        issuanceJournalDomain: await reference(join(issueCheckpoint, "domain.json")),
        issuanceIntent: await reference(join(issueCheckpoint, `${operation.id}.intent.json`)),
        issuanceCompletion: await reference(join(issueCheckpoint, `${operation.id}.receipt.json`)),
      });
    }
  }
  const categories = ["independent", "nfts", "weightedLiquid", "weightedSy", "dtfCustodySe", "claimVault",
    "weightedReceipt", "earlierReceipt", "earlierLiquid", "heldSeLp"] as const;
  const rows = Object.fromEntries(categories.map((key) => [key, prepared.input[key].map((row, i) => {
    const prior = prepared.payloads.configure[key][i];
    if (!prior) throw new ExecutionError("STATE", "missing normalized configuration row");
    return { ...row, pricing: retain(prior.configurationId) };
  })]));
  const { bundle: _bundle, ...native } = prepared.input;
  return preparationInput.parse({ ...native, ...rows, issuedHistory: history });
}
