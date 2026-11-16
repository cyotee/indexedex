import { z } from "zod";
import { address, binding, hash, hex, identity, positive, sha256, source, uint } from "./schema.js";

export const stages = ["deploy", "fund", "capture", "configure", "independent-issue",
  "owner-bond", "verify", "activate", "harvest"] as const;
export const stage = z.enum(stages);
export type Stage = z.infer<typeof stage>;
export const quantity = z.string().regex(/^0x[0-9a-fA-F]+$/);
export const localIdentity = z.object({
  instanceId: z.string().min(1),
  forkBlockNumber: uint,
  forkBlockHash: identity,
}).strict().readonly();
const route = z.object({ token: address, vault: address }).strict().readonly();
const routeMode = z.enum(["0", "1"]);
export const packageArguments = z.object({
  baseArgs: z.object({
    name: z.string().min(1), symbol: z.string().min(1), hook: address, ownerOnlyLiquidity: z.boolean(),
    creationPairPerDetfWad: z.array(uint).readonly(), openingPairPerDetfWad: z.array(uint).readonly(),
    mintThreshold: uint, burnThreshold: uint, expansionClosureRatePerYearWad: uint,
    creator: z.string().regex(/^0x[0-9a-fA-F]{40}$/).transform((value) => value.toLowerCase()),
    claimName: z.string(), claimSymbol: z.string(), bondName: z.string(), bondSymbol: z.string(),
    mintRouteMode: routeMode, mintRoutes: z.array(route).readonly(),
    burnRouteMode: routeMode, burnRoutes: z.array(route).readonly(),
    bondRouteMode: routeMode, bondRoutes: z.array(route).readonly(),
    donateRouteMode: routeMode, donateRoutes: z.array(route).readonly(),
  }).strict().readonly(),
  owner: address, ownershipBufferPeriod: uint, weth: address, originalDtf: address,
}).strict().readonly();
export const funding = z.object({
  donations: z.array(z.object({
    id: identity,
    tokens: z.array(address).readonly(),
    amounts: z.array(positive).readonly(),
    nativeAmount: uint,
    minimum: uint,
    deadline: positive,
  }).strict().readonly()).readonly(),
  genesis: z.object({
    legs: z.array(z.object({ token: address, amount: positive, minSharesOut: positive }).strict().readonly()).min(1).readonly(),
    anchorIndex: uint, minimum: positive, deadline: positive,
  }).strict().readonly().nullable(),
}).strict().readonly();
// Pre-capture work has no fabricated snapshot. Post-capture work references the
// preparation manifest, which is reconstructed through validateManifest.
export const ownerBond = z.object({
  token: address, amount: positive, duration: positive, deadline: positive,
}).strict().readonly();
export const executionManifest = z.object({
  version: z.literal("dtf-operator-execution-v1"),
  purpose: z.enum(["synthetic-local", "operational-review"]),
  chainId: positive,
  rpcEnv: z.string().regex(/^[A-Z][A-Z0-9_]*$/),
  signer: address,
  local: localIdentity.nullable(),
  proxy: address,
  registry: address,
  package: address,
  snapshotId: identity.nullable(),
  bindings: z.array(binding).min(3).readonly(),
  sources: z.array(source).min(1).readonly(),
  preparedManifest: z.string().min(1).nullable(),
  deployment: packageArguments.nullable(),
  funding,
  ownerBond: ownerBond.nullable().default(null),
}).strict().readonly();
export type ExecutionManifest = z.infer<typeof executionManifest>;
export type Mode =
  | { readonly kind: "simulate" }
  | { readonly kind: "local"; readonly instanceId: string }
  | { readonly kind: "broadcast"; readonly chainId: string; readonly proxy: string;
      readonly snapshotId: string; readonly keyEnv: string };
export class ExecutionError extends Error {
  constructor(readonly code: "DOMAIN" | "INTENT" | "AMBIGUOUS" | "REVERT" | "STATE" | "LOCK" | "RPC", message: string) {
    super(message);
    this.name = "ExecutionError";
  }
}
export const transaction = z.object({
  from: address, to: address, data: hex, value: uint,
}).strict().readonly();
export type Operation = {
  readonly id: string;
  readonly stage: Stage;
  readonly method: string;
  readonly transaction: z.infer<typeof transaction>;
};
export const rpcLog = z.object({
  address, topics: z.array(hash), data: hex, logIndex: quantity,
}).passthrough().readonly();
export const receipt = z.object({
  transactionHash: hash, blockHash: hash, blockNumber: quantity,
  from: address, to: address.nullable(), status: quantity,
  transactionIndex: quantity, logs: z.array(rpcLog),
}).passthrough().readonly();
export type Receipt = z.infer<typeof receipt>;
export const intent = z.object({
  version: z.literal("dtf-operator-intent-v1"),
  domainHash: sha256, id: sha256, stage,
  method: z.string(), transaction,
  nonce: uint, startBlock: uint,
  signedTransaction: hex, transactionHash: identity,
}).strict().readonly();
export type Intent = z.infer<typeof intent>;
export const completion = z.object({
  intentHash: sha256, receipt,
  state: z.record(z.string(), z.string()),
  events: z.array(z.object({ name: z.string(), values: z.array(z.string()) }).strict()),
}).strict().readonly();
export type Completion = z.infer<typeof completion>;
