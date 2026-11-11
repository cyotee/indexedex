import { z } from "zod";

export const uint = z.string().regex(/^[0-9]+$/).transform((v) => BigInt(v).toString())
  .refine((v) => BigInt(v) < 2n ** 256n, "uint256 overflow");
export const positive = uint.refine((v) => BigInt(v) > 0n, "positive integer required");
export const address = z.string().regex(/^0x[0-9a-fA-F]{40}$/).transform((v) => v.toLowerCase())
  .refine((v) => v !== `0x${"0".repeat(40)}`, "zero address");
export const hash = z.string().regex(/^0x[0-9a-fA-F]{64}$/).transform((v) => v.toLowerCase());
export const identity = hash.refine((v) => v !== `0x${"0".repeat(64)}`, "zero identity");
export const sha256 = z.string().regex(/^[0-9a-f]{64}$/);
export const hex = z.string().regex(/^0x(?:[0-9a-fA-F]{2})*$/).transform((v) => v.toLowerCase());
export const categories = [
  "independent", "weighted-nft", "earlier-nft", "weighted-liquid", "earlier-liquid",
  "weighted-receipt", "earlier-receipt", "weighted-sy", "token-staking",
  "claim-vault", "underlying-se", "fungible-lp", "earlier-liquidation",
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
}).strict().readonly();
export const nft = z.object({ original: nftOriginal, proof }).strict().readonly();
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
    "WeightedConvert", "EarlierClaim", "EarlierSale", "Donate"]),
  tokenId: uint,
  amount: uint,
  minimum: uint,
}).strict().readonly();
export const preparationInput = z.object({
  version: z.literal("dtf-operator-preparation-v1"),
  purpose: z.enum(["synthetic-local", "operational-review"]),
  domain,
  sources: z.array(source).min(1).readonly(),
  exposures: z.array(exposure).readonly(),
  independent: z.array(independent).readonly(),
  nfts: z.array(nft).readonly(),
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
export type RecoveryStep = z.infer<typeof recoveryStep>;

export class PreparationError extends Error {
  constructor(readonly code: "INPUT" | "PROVENANCE" | "DOMAIN" | "BLOCKED" | "QUOTE", message: string) {
    super(message);
    this.name = "PreparationError";
  }
}
