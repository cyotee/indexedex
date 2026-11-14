import { z } from "zod";

export const uint = z.string().regex(/^[0-9]+$/).transform((v) => BigInt(v).toString())
  .refine((v) => BigInt(v) < 2n ** 256n, "uint256 overflow");
export const positive = uint.refine((v) => BigInt(v) > 0n, "positive integer required");
export const address = z.string().regex(/^0x[0-9a-fA-F]{40}$/).transform((v) => v.toLowerCase())
  .refine((v) => v !== `0x${"0".repeat(40)}`, "zero address");
export const hash = z.string().regex(/^0x[0-9a-fA-F]{64}$/).transform((v) => v.toLowerCase());
export const identity = hash.refine((v) => v !== `0x${"0".repeat(64)}`, "zero identity");
export const sha256 = z.string().regex(/^[0-9a-f]{64}$/);
export const bundleReference = z.object({
  path: z.string().min(1), sha256, bytes: uint,
}).strict().readonly();
export const hex = z.string().regex(/^0x(?:[0-9a-fA-F]{2})*$/).transform((v) => v.toLowerCase());
export const categories = [
  "independent", "weighted-nft", "earlier-nft", "weighted-liquid", "earlier-liquid",
  "weighted-receipt", "earlier-receipt", "weighted-sy", "token-staking",
  "claim-vault", "dtf-custody-se", "underlying-se", "fungible-lp", "earlier-liquidation",
  "held-se-lp",
] as const;
export const proof = z.object({
  sourceId: z.string().min(1),
  pointer: z.string().regex(/^(?:\/(?:[^~]|~[01])*)*$/),
}).strict().readonly();
export const original = z.object({
  entitlementId: identity,
  originalEth: uint,
  originalDtf: uint,
  evidenceId: identity,
}).strict().readonly();
export const independent = z.object({
  recipient: address,
  evidenceId: identity,
  entitlements: z.array(z.object({ original, proof }).strict().readonly()).min(1).readonly(),
}).strict().readonly();
export const nftOriginal = z.object({
  collection: address,
  tokenId: uint.refine((v) => BigInt(v) >= 3n, "reserved NFT ID"),
  originalWallet: address,
  originalUnits: positive,
  originalEth: uint,
  originalDtf: uint,
  evidenceId: identity,
  contributionsKnown: z.literal(true),
  separateContributions: z.literal(true).optional(),
}).strict().refine((row) => !row.separateContributions
  || (BigInt(row.originalEth) > 0n && BigInt(row.originalDtf) > 0n),
"separate NFT contributions require both ETH and DTF").readonly();
export const nft = z.object({ original: nftOriginal, proof }).strict().readonly();
export const weightedLiquidOriginal = z.object({
  originalId: identity,
  originalWallet: address,
  source: address,
  originalUnits: positive,
  originalEth: uint,
  originalDtf: uint,
  evidenceId: identity,
  contributionsKnown: z.literal(true),
}).strict().readonly();
export const weightedLiquid = z.object({ original: weightedLiquidOriginal, proof }).strict().readonly();
export const weightedSyOriginal = weightedLiquidOriginal;
// Historical eligibility and exclusions are reviewed owner inputs, not chain facts.
// Legacy members require isolation; witnessed members authenticate transaction-local reads.
export const claimedSyCertificate = z.object({
  kind: z.enum(["complete-original-token-staking", "complete-remaining-token-staking"]),
  chainId: z.literal("4663"),
  source: z.literal("0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00"),
  vault: z.literal("0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0"),
  sy: z.literal("0xb55604cf4dcdabb362078e106d20f98512391edf"),
  snapshotCapture: z.object({
    transactionHash: identity, blockNumber: positive, blockHash: identity,
  }).strict().readonly(),
  review: z.object({
    authority: z.string().min(1),
    originalId: identity,
    originalWallet: address,
    originalEth: uint,
    originalDtf: uint,
    eligibleWeight: positive,
    originalWeight: positive.optional(),
    priorDeliveredCredit: z.literal("0"),
    contributionsKnown: z.literal(true),
    eligiblePrincipalOnly: z.literal(true),
    rewardsExcluded: z.literal(true),
    aliasesReconciled: z.literal(true),
    competingRepresentationsExcluded: z.literal(true),
    unrelatedWeightFloor: uint,
    unrelatedSyFloor: uint,
  }).strict().readonly(),
  members: z.array(z.object({
    transactionHash: identity,
    rawSignedTransaction: hex,
    blockNumber: positive,
    blockHash: identity,
    consumedWeight: positive,
    receivedSy: uint,
    redeemedVaultShares: uint,
    execution: z.union([z.object({
      kind: z.enum(["direct-eip7702-v1", "relayed-eip7702-v1"]),
      delegate: address,
      delegateCodeHash: identity,
    }).strict().readonly(), z.object({
      kind: z.literal("witnessed-eip7702-v1"),
      delegate: address,
      delegateCodeHash: identity,
      witness: address,
    }).strict().readonly(), z.object({
      kind: z.literal("indirect-transaction-v1"),
      walletCodeHash: identity,
    }).strict().readonly()]).optional(),
  }).strict().readonly()).min(1).readonly(),
}).strict().readonly();
export const weightedSy = z.object({
  original: weightedSyOriginal,
  proof,
  claimedOrigin: claimedSyCertificate.optional(),
}).strict().readonly();
// Q0 is documented eligible original ownership gons, not native9 WS or a live balance.
export const weightedReceiptOriginal = weightedLiquidOriginal;
export const weightedReceipt = z.object({ original: weightedReceiptOriginal, proof }).strict().readonly();
// Exact internal ER shares. Displayed native18 and external floor shares are not Q0.
export const earlierLiquidOriginal = weightedLiquidOriginal;
export const earlierLiquid = z.object({ original: earlierLiquidOriginal, proof }).strict().readonly();
export const heldSeLpSources = [
  "0x999dae02d22e5fee1c4508430d5196d31d631009",
  "0x923877336b14662cfb5b3a60b14e7d716d54a888",
  "0x46e068c2393e189fbc86632f67210af253a42aa8",
  "0xb7d4bb379d361ad442cddee53ea71a33957826a7",
] as const;
// Source-native18 shares/physical LP; neither native28 W-SD nor NFT accounting shares.
export const heldSeLpOriginal = weightedLiquidOriginal.refine(
  (row) => heldSeLpSources.some((source) => source === row.source), "unsupported fixed held SE/LP source");
export const heldSeLp = z.object({ original: heldSeLpOriginal, proof }).strict().readonly();
export const earlierReceiptOriginal = weightedLiquidOriginal;
export const earlierReceipt = z.object({ original: earlierReceiptOriginal, proof }).strict().readonly();
export const claimVaultOriginal = weightedLiquidOriginal;
export const claimVault = z.object({ original: claimVaultOriginal, proof }).strict().readonly();
export const dtfCustodySeOriginal = weightedLiquidOriginal;
export const dtfCustodySe = z.object({ original: dtfCustodySeOriginal, proof }).strict().readonly();
export const binding = z.object({
  role: z.enum(["proxy", "registry", "package", "facet"]),
  address,
  codeHash: identity,
}).strict().readonly();
export const domain = z.object({
  chainId: positive,
  proxy: address,
  snapshotId: identity,
  blockNumber: uint,
  blockHash: identity,
  rpcEnv: z.string().regex(/^[A-Z][A-Z0-9_]*$/),
  snapshotArtifact: z.string().min(1),
  bindings: z.array(binding).min(4).readonly(),
}).strict().readonly();
export const source = z.object({
  id: z.string().min(1),
  path: z.string().min(1),
  sha256,
  bytes: uint,
  provenance: z.discriminatedUnion("kind", [
    z.object({ kind: z.literal("file"), authority: z.string().min(1) }).strict(),
    z.object({
      kind: z.literal("chain"), chainId: positive, blockNumber: uint, blockHash: identity,
      contract: address, method: z.enum(["eth_getLogs", "eth_getTransactionReceipt", "eth_call", "eth_getCode"]),
      locator: z.string().min(1),
    }).strict(),
  ]).readonly(),
}).strict().readonly();
// Every economic origin is partitioned, in its own source-specific unit.
// Descendants/recoveries are accounting observations, never extra quote inputs.
export const exposure = z.object({
  originId: identity,
  category: z.enum(categories),
  originalUnits: positive,
  descendants: z.array(z.object({ id: identity, units: uint }).strict().readonly()).readonly(),
  recoveredUnits: uint,
  excludedUnits: uint,
  proof,
}).strict().readonly();
export const recoveryStep = z.object({
  stage: z.enum(["WeightedClaim", "WeightedPrincipal", "WeightedRewards", "WeightedUnstake",
    "WeightedConvert", "EarlierClaim", "EarlierSale", "Donate", "WeightedSyRedeem", "DtfCustodySeRedeem", "ClaimVaultRedeem", "EarlierConvert", "WeightedWethSeConvert", "EarlierSeConvert", "WeightedLpRedeem", "EarlierNftReceiptRedeem", "EarlierStandaloneReceiptRedeem"]),
  tokenId: uint,
  amount: uint,
  minimum: uint,
}).strict().readonly();
export const preparationInput = z.object({
  version: z.literal("dtf-operator-preparation-v1"),
  bundle: bundleReference.optional(),
  purpose: z.enum(["synthetic-local", "operational-review"]),
  domain,
  sources: z.array(source).min(1).readonly(),
  exposures: z.array(exposure).readonly(),
  independent: z.array(independent).readonly(),
  nfts: z.array(nft).readonly(),
  weightedLiquid: z.array(weightedLiquid).readonly(),
  weightedSy: z.array(weightedSy).readonly(),
  dtfCustodySe: z.array(dtfCustodySe).readonly(),
  claimVault: z.array(claimVault).readonly(),
  weightedReceipt: z.array(weightedReceipt).readonly(),
  earlierReceipt: z.array(earlierReceipt).readonly().default([]),
  earlierLiquid: z.array(earlierLiquid).readonly().default([]),
  heldSeLp: z.array(heldSeLp).readonly().default([]),
  issueRecipients: z.array(address).readonly(),
  harvest: z.object({
    steps: z.array(recoveryStep).max(8).readonly(),
    deadline: uint,
  }).strict().readonly(),
}).strict().readonly();

export type PreparationInput = z.infer<typeof preparationInput>;
export type Domain = z.infer<typeof domain>;
export type Proof = z.infer<typeof proof>;
export type Original = z.infer<typeof original>;
export type NftOriginal = z.infer<typeof nftOriginal>;
export type WeightedLiquidOriginal = z.infer<typeof weightedLiquidOriginal>;
export type WeightedSyOriginal = z.infer<typeof weightedSyOriginal>;
export type ClaimedSyCertificate = z.infer<typeof claimedSyCertificate>;
export type WeightedReceiptOriginal = z.infer<typeof weightedReceiptOriginal>;
export type EarlierReceiptOriginal = z.infer<typeof earlierReceiptOriginal>;
export type ClaimVaultOriginal = z.infer<typeof claimVaultOriginal>;
export type DtfCustodySeOriginal = z.infer<typeof dtfCustodySeOriginal>;
export type RecoveryStep = z.infer<typeof recoveryStep>;

export class PreparationError extends Error {
  constructor(readonly code: "INPUT" | "PROVENANCE" | "DOMAIN" | "BLOCKED" | "QUOTE", message: string) {
    super(message);
    this.name = "PreparationError";
  }
}
