import { readFile, writeFile } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { AbiCoder, Interface, Result, keccak256 } from "ethers";
import type { ParamType } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { address, hash, hex, preparationInput } from "./schema.js";
import type { ClaimedSyCertificate, PreparationInput } from "./schema.js";
import { claimedSyEvidenceId } from "./claimed-sy.js";
import { executionManifest, ExecutionError, packageArguments } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { LEGACY } from "./rehearsal-chain.js";
import { DEV } from "./execution-rpc.js";
import { dtfCustodySeSource, claimVaultSource, weightedReceiptSource, earlierReceiptSource, earlierLiquidSource, nftOrigin } from "./payloads.js";

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
    sourceFile("dtf-custody-se-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase15-dtf-custody-se-brief.md"),
    sourceFile("dtf-custody-source-archive", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json"),
    sourceFile("claim-vault-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase16-claim-vault-brief.md"),
    sourceFile("claim-vault-acquisition", join(dirname(environmentPath), "claim-vault-acquisition.json")),
    sourceFile("dtf-custody-acquisition", join(dirname(environmentPath), "dtf-custody-se-acquisition.json")),
    sourceFile("weighted-sy-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase14-weighted-sy-brief.md"),
    sourceFile("owner-first-bond-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase13-owner-first-bond-correction.md"),
    sourceFile("current-main-plan", "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md"),
    sourceFile("current-main-prd", "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md"),
    sourceFile("weighted-receipt-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase17-weighted-receipt-implementation-brief.md"),
    sourceFile("weighted-receipt-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt/docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/source/contract.md"),
    sourceFile("weighted-receipt-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt/docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/source-verification/report.md"),
    sourceFile("weighted-receipt-acquisition", join(dirname(environmentPath), "weighted-receipt-acquisition.json")),
    sourceFile("earlier-receipt-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/source/contract.md"),
    sourceFile("earlier-receipt-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/source-verification/report.md"),
    sourceFile("earlier-liquid-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/contract.md"),
    sourceFile("earlier-liquid-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source-verification/report.md"),
    sourceFile("earlier-liquid-acquisition", join(dirname(environmentPath), "earlier-liquid-acquisition.json")),
    sourceFile("held-se-lp-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase21-admitted-se-lp-implementation-brief.md"),
    sourceFile("held-se-lp-source-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/source/contract.md"),
    sourceFile("held-se-lp-source-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/source-verification/report.md"),
    sourceFile("held-se-lp-owner-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/owner-funding/contract.md"),
    sourceFile("held-se-lp-owner-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources/owner-funding-verification/report.md"),
    sourceFile("held-se-lp-acquisition", join(dirname(environmentPath), "held-se-lp-acquisition.json")),
    sourceFile("earlier-receipt-acquisition", join(dirname(environmentPath), "earlier-receipt-acquisition.json")),
    sourceFile("claimed-sy-authority", "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase23-claimed-sy-integration-brief.md"),
    sourceFile("claimed-sy-source-contract", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-22-claimed-sy-source/docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-source/source/contract.md"),
    sourceFile("claimed-sy-source-admission", "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-22-claimed-sy-source/docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-source/verification/report.md"),
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
    version: "dtf-operator-execution-v1", purpose: "synthetic-local", chainId: "4663", rpcEnv: "DTF_OPERATOR_LOCAL_RPC",
    signer: DEV, local: { instanceId: metadata.instanceId, forkBlockNumber: String(metadata.forkedNetwork.forkBlockNumber),
      forkBlockHash: metadata.forkedNetwork.forkBlockHash }, proxy: environment.proxy, registry: environment.registry,
    package: environment.package, snapshotId: null, preparedManifest: null, deployment, sources,
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
    readonly claimedSy?: readonly { readonly q0: string; readonly certificate: Omit<ClaimedSyCertificate, "snapshotCapture"> }[] }) {
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
    const certificate = { ...sourceCertificate, snapshotCapture: { transactionHash: captureTransaction,
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
  const input = preparationInput.parse({
    version: "dtf-operator-preparation-v1", purpose: "synthetic-local", domain,
    sources: [...manifest.sources, await sourceFile("synthetic-proof", evidencePath)],
    exposures: exposures.map((e, i) => ({ ...e, proof: proof(`/exposures/${i}`) })),
    independent: recipients.map((recipient, i) => ({ recipient, evidenceId: `0x${fingerprint(`synthetic group ${i}`)}`,
      entitlements: [{ original: originals[i], proof: proof(`/originals/${i}`) }] })),
    nfts: nfts.map((original, i) => ({ original, proof: proof(`/nfts/${i}`) })),
    weightedLiquid: weightedLiquid.map((original, i) => ({ original, proof: proof(`/weightedLiquid/${i}`) })),
    weightedSy: weightedSy.map((original, i) => i === 0
      ? { original, proof: proof(`/weightedSy/${i}`) }
      : { ...claimedSy[i - 1], proof: proof(`/claimedSy/${i - 1}`) }),
    dtfCustodySe: dtfCustodySe.map((original, i) => ({ original, proof: proof(`/dtfCustodySe/${i}`) })),
    claimVault: claimVault.map((original, i) => ({ original, proof: proof(`/claimVault/${i}`) })),
    weightedReceipt: weightedReceipt.map((original, i) => ({ original, proof: proof(`/weightedReceipt/${i}`) })),
    earlierLiquid: earlierLiquid.map((original, i) => ({ original, proof: proof(`/earlierLiquid/${i}`) })),
    heldSeLp: heldSeLp.map((original, i) => ({ original, proof: proof(`/heldSeLp/${i}`) })),
    earlierReceipt: earlierReceipt.map((original, i) => ({ original, proof: proof(`/earlierReceipt/${i}`) })),
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
  const weightedLiquid = input.weightedLiquid.map((row) => ({
    ...row, original: { ...row.original,
      originalEth: (BigInt(row.original.originalEth) * 3n / 5n).toString(),
      originalUnits: (BigInt(row.original.originalUnits) - 1n).toString(),
    },
  }));
  const weightedSy = input.weightedSy.map((row) => row.claimedOrigin ? row : ({
    ...row, original: { ...row.original, originalEth: "6000000000000000", originalUnits: "8087" },
  }));
  const dtfCustodySe = input.dtfCustodySe.map((row) => ({
    ...row, original: { ...row.original, originalDtf: "600000000000000000",
      originalUnits: (BigInt(row.original.originalUnits) - 7n).toString() },
  }));
  const claimVault = input.claimVault.map((row) => ({
    ...row, original: { ...row.original, originalDtf: "600000000000000000",
      originalUnits: (BigInt(row.original.originalUnits) - 7n).toString() },
  }));
  const weightedReceipt = input.weightedReceipt.map((row) => ({
    ...row, original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const earlierReceipt = input.earlierReceipt.map((row) => ({
    ...row, original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const earlierLiquid = input.earlierLiquid.map((row) => ({
    ...row, original: { ...row.original, originalEth: "6000000000000000" },
  }));
  const heldSeLp = input.heldSeLp.map((row) => ({
    ...row, original: { ...row.original, originalEth: "6000000000000000" },
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
  const replacement = preparationInput.parse({ ...input, independent, weightedLiquid, weightedSy, dtfCustodySe, claimVault, weightedReceipt, earlierReceipt, earlierLiquid, heldSeLp, exposures,
    sources: [...input.sources.filter((s) => s.id !== "synthetic-proof"), await sourceFile("synthetic-proof", evidencePath)] });
  await save(join(directory, "replacement-input.json"), replacement);
  return replacement;
}
