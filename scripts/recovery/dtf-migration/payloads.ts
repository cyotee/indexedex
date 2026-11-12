import { AbiCoder, keccak256 } from "ethers";
import { categories, PreparationError } from "./schema.js";
import type { Domain, NftOriginal, Original, PreparationInput, WeightedLiquidOriginal } from "./schema.js";

const coder = AbiCoder.defaultAbiCoder();
const independentTuple = "tuple(address recipient,bytes32 evidenceId,tuple(bytes32 entitlementId,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId)[] entitlements)";
const nftTuple = "tuple(address collection,uint256 tokenId,address originalWallet,uint256 originalUnits,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId,bool contributionsKnown)";
const weightedLiquidTuple = "tuple(bytes32 originalId,address originalWallet,address source,uint256 originalUnits,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId,bool contributionsKnown)";
export const dtfCustodySeSource = "0x2e9c1f705ab967c5af59249203d7495bdabb223b";
export const weightedSySource = "0xb55604cf4dcdabb362078e106d20f98512391edf";
export const weightedLiquidSource = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const weightedCollection = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const earlierCollection = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export type IndependentPayload = {
  readonly recipient: string;
  readonly evidenceId: string;
  readonly entitlements: readonly Original[];
};
export type ConfigurationPayload = {
  readonly independent: readonly IndependentPayload[];
  readonly nfts: readonly NftOriginal[];
  readonly weightedLiquid: readonly WeightedLiquidOriginal[];
  readonly weightedSy: readonly WeightedLiquidOriginal[];
  readonly dtfCustodySe: readonly WeightedLiquidOriginal[];
};

export function configurationId(domain: Domain, input: IndependentPayload | NftOriginal | WeightedLiquidOriginal): string {
  const tuple = "recipient" in input ? independentTuple : "collection" in input ? nftTuple : weightedLiquidTuple;
  return keccak256(coder.encode(["uint256", "address", "bytes32", tuple],
    [domain.chainId, domain.proxy, domain.snapshotId, input]));
}

export function nftOrigin(domain: Domain, input: NftOriginal): string {
  return keccak256(coder.encode(["string", "uint256", "address", "bytes32", "address", "uint256"],
    ["migration.nft", domain.chainId, domain.proxy, domain.snapshotId, input.collection, input.tokenId]));
}

const blockedGate = {
  "earlier-liquid": "H3/H6: original native-unit configuration and surrender not implemented; ED liquidation unproved",
  "weighted-receipt": "H3/H4: original gon/credit mapping and synchronized fungible surrender not implemented",
  "earlier-receipt": "H3/H6: original share denominator and fractional attribution unproved; earlier SE exits disabled",
  "token-staking": "H3/H5: reassign debits caller without recipient callback or approved pull; atomic raw-weight surrender unsupported",
  "claim-vault": "H3/H5: original direct-user 19-decimal share records and surrender integration absent; infrastructure ownership is not user authority",
  "underlying-se": "H3/H5/H6: direct-user records and surrender absent; earlier and weighted WETH SE disabled; fixed W-SD has its separate admitted category",
  "fungible-lp": "H3/H6: original records and surrender absent; legacy exits are owner-restricted, earlier exact-in unsupported",
  "earlier-liquidation": "SB-E1/E2/E3 disabled earlier SE exits; SB-E4 liquid conversion unproved",
} as const;

export function dispositions(input: PreparationInput) {
  return categories.map((category) => {
    switch (category) {
      case "independent": return { category, disposition: "bounded", gate: "verified disjoint originals only" };
      case "weighted-nft":
      case "earlier-nft": return { category, disposition: "bounded", gate: "explicit original-wallet configuration and actual same-wallet NFT surrender required" };
      case "dtf-custody-se": return { category, disposition: "bounded", gate: "fixed W-SD original-wallet native 28-decimal share inputs and measured custody; original operational allocations remain unapproved" };
      case "weighted-sy": return { category, disposition: "bounded", gate: "fixed WY original-wallet static-share/component inputs and measured custody; operational allocations remain unapproved" };
      case "weighted-liquid": return { category, disposition: "bounded", gate: "explicit original-wallet WD quantity/component allocation and measured surrender; operational allocations remain unapproved" };
      default: return { category, disposition: "blocked", gate: blockedGate[category] };
    }
  }).map((row) => ({ ...row, records: input.exposures.filter((e) => e.category === row.category).length.toString() }));
}

export function buildPayloads(input: PreparationInput): ConfigurationPayload {
  const origins = new Map(input.exposures.map((e) => [e.originId, e]));
  if (origins.size !== input.exposures.length) throw new PreparationError("PROVENANCE", "duplicate origin");
  const used = new Set<string>();
  const claimOrigin = (id: string, category: string): void => {
    const origin = origins.get(id);
    if (!origin || origin.category !== category) throw new PreparationError("PROVENANCE", `missing matching origin ${id}`);
    if (used.has(id)) throw new PreparationError("PROVENANCE", `overlapping original ${id}`);
    used.add(id);
  };
  for (const row of dispositions(input)) {
    if (row.disposition === "blocked" && row.records !== "0") throw new PreparationError("BLOCKED", `${row.category}: ${row.gate}`);
  }
  const independent = input.independent.map((row) => {
    for (const item of row.entitlements) claimOrigin(item.original.entitlementId, "independent");
    return { recipient: row.recipient, evidenceId: row.evidenceId,
      entitlements: row.entitlements.map((e) => e.original).sort((a, b) => a.entitlementId.localeCompare(b.entitlementId)) };
  }).sort((a, b) => a.recipient.localeCompare(b.recipient));
  if (new Set(independent.map((r) => r.recipient)).size !== independent.length) {
    throw new PreparationError("INPUT", "duplicate recipient; supply one complete replacement");
  }
  const nfts = input.nfts.map(({ original }) => {
    if (input.domain.chainId !== "4663") throw new PreparationError("DOMAIN", "NFT sources require chain 4663");
    const category = original.collection === weightedCollection ? "weighted-nft"
      : original.collection === earlierCollection ? "earlier-nft" : undefined;
    if (!category) throw new PreparationError("BLOCKED", `unsupported NFT collection ${original.collection}`);
    const id = nftOrigin(input.domain, original);
    claimOrigin(id, category);
    if (origins.get(id)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "NFT original units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.collection.localeCompare(b.collection)
    || (BigInt(a.tokenId) < BigInt(b.tokenId) ? -1 : BigInt(a.tokenId) > BigInt(b.tokenId) ? 1 : 0));
  const weightedLiquid = input.weightedLiquid.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== weightedLiquidSource) {
      throw new PreparationError("DOMAIN", "weighted liquid source requires fixed WD on chain 4663");
    }
    claimOrigin(original.originalId, "weighted-liquid");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "weighted liquid original units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const weightedSy = input.weightedSy.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== weightedSySource) {
      throw new PreparationError("DOMAIN", "weighted SY source requires fixed WY on chain 4663");
    }
    claimOrigin(original.originalId, "weighted-sy");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "weighted SY original units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const dtfCustodySe = input.dtfCustodySe.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== dtfCustodySeSource) {
      throw new PreparationError("DOMAIN", "DTF-custody SE source requires fixed W-SD on chain 4663");
    }
    claimOrigin(original.originalId, "dtf-custody-se");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "DTF-custody SE original units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  if (used.size !== origins.size) throw new PreparationError("PROVENANCE", "unassigned origin; no silent omission");
  if (new Set(input.issueRecipients).size !== input.issueRecipients.length) {
    throw new PreparationError("INPUT", "duplicate issuance recipient");
  }
  for (const recipient of input.issueRecipients) {
    if (!independent.some((r) => r.recipient === recipient)) throw new PreparationError("INPUT", "issuance lacks configuration");
  }
  if (input.harvest.steps.length > 1 && input.harvest.steps.some((step) =>
    !["WeightedClaim", "WeightedPrincipal", "WeightedRewards"].includes(step.stage))) {
    throw new PreparationError("INPUT", "batch bound is eight weighted claims or one other recovery step");
  }
  for (const step of input.harvest.steps) {
    switch (step.stage) {
      case "WeightedClaim":
      case "WeightedPrincipal":
      case "WeightedRewards":
      case "EarlierClaim":
      case "EarlierSale":
        if (BigInt(step.tokenId) < 3n || step.amount !== "0"
          || (step.stage !== "EarlierSale" && step.minimum !== "0")) {
          throw new PreparationError("INPUT", "invalid NFT recovery fields");
        }
        break;
      case "WeightedUnstake":
      case "WeightedSyRedeem":
      case "DtfCustodySeRedeem":
      case "WeightedConvert":
      case "Donate":
        if (step.tokenId !== "0" || step.amount === "0"
          || (step.stage === "WeightedUnstake" && step.minimum !== "0")) {
          throw new PreparationError("INPUT", "invalid conversion recovery fields");
        }
        break;
      default: step.stage satisfies never;
    }
  }
  if (input.harvest.steps.length > 0 && (input.domain.chainId !== "4663" || input.harvest.deadline === "0")) {
    throw new PreparationError("DOMAIN", "recovery requires chain 4663 and deadline");
  }
  return { independent, nfts, weightedLiquid, weightedSy, dtfCustodySe };
}
