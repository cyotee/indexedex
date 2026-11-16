import { AbiCoder, keccak256 } from "ethers";
import { categories, heldSeLpSources, nftContributionsAllowed, PreparationError, weightedCollection } from "./schema.js";
export { weightedCollection } from "./schema.js";
import type { Domain, NftOriginal, Original, PreparationInput, WeightedLiquidOriginal } from "./schema.js";
import { validateClaimedSyInputs } from "./claimed-sy.js";

const coder = AbiCoder.defaultAbiCoder();
const independentTuple = "tuple(address recipient,bytes32 evidenceId,tuple(bytes32 entitlementId,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId)[] entitlements)";
const nftTuple = "tuple(address collection,uint256 tokenId,address originalWallet,uint256 originalUnits,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId,bool contributionsKnown)";
const weightedLiquidTuple = "tuple(bytes32 originalId,address originalWallet,address source,uint256 originalUnits,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId,bool contributionsKnown)";
export const claimVaultSource = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
export const dtfCustodySeSource = "0x2e9c1f705ab967c5af59249203d7495bdabb223b";
export const weightedSySource = "0xb55604cf4dcdabb362078e106d20f98512391edf";
export const weightedLiquidSource = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const weightedReceiptSource = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
export const earlierLiquidSource = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const earlierReceiptSource = "0x4ac89ad061a531fa62ddceed53520c2750113b01";
export const earlierCollection = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export type IndependentPayload = {
  readonly recipient: string;
  readonly evidenceId: string;
  readonly entitlements: readonly Original[];
};
export type WeightedSyPayload = WeightedLiquidOriginal & {
  readonly claimBasis?: { readonly originalWeight: string; readonly eligibleWeight: string };
};
export type ConfigurationPayload = {
  readonly independent: readonly IndependentPayload[];
  readonly nfts: readonly NftOriginal[];
  readonly weightedLiquid: readonly WeightedLiquidOriginal[];
  readonly weightedSy: readonly WeightedSyPayload[];
  readonly dtfCustodySe: readonly WeightedLiquidOriginal[];
  readonly claimVault: readonly WeightedLiquidOriginal[];
  readonly weightedReceipt: readonly WeightedLiquidOriginal[];
  readonly earlierLiquid: readonly WeightedLiquidOriginal[];
  readonly earlierReceipt: readonly WeightedLiquidOriginal[];
  readonly heldSeLp: readonly WeightedLiquidOriginal[];
};
export const configurationKinds = [
  "independent", "nfts", "weightedLiquid", "weightedSy", "dtfCustodySe", "claimVault",
  "weightedReceipt", "earlierReceipt", "earlierLiquid", "heldSeLp",
] as const satisfies readonly (keyof ConfigurationPayload)[];

export function configurationId(domain: Domain, input: IndependentPayload | NftOriginal | WeightedLiquidOriginal | WeightedSyPayload): string {
  const tuple = "recipient" in input ? independentTuple : "collection" in input ? nftTuple : weightedLiquidTuple;
  if ("claimBasis" in input && input.claimBasis) {
    return keccak256(coder.encode(["uint256", "address", "bytes32",
      `tuple(${weightedLiquidTuple} original,uint256 originalWeight,uint256 eligibleWeight)`],
    [domain.chainId, domain.proxy, domain.bookId, { original: input, ...input.claimBasis }]));
  }
  if ("collection" in input && input.separateContributions) {
    return keccak256(coder.encode(["uint256", "address", "bytes32", tuple, "bool"],
      [domain.chainId, domain.proxy, domain.bookId, input, true]));
  }
  return keccak256(coder.encode(["uint256", "address", "bytes32", tuple],
    [domain.chainId, domain.proxy, domain.bookId, input]));
}

export function nftContributionOriginals(input: NftOriginal) {
  return input.separateContributions
    ? [{ originalEth: input.originalEth, originalDtf: "0" }, { originalEth: "0", originalDtf: input.originalDtf }]
    : [{ originalEth: input.originalEth, originalDtf: input.originalDtf }];
}

export function nftOrigin(domain: Domain, input: NftOriginal): string {
  return keccak256(coder.encode(["string", "uint256", "address", "address", "uint256"],
    ["migration.nft", domain.chainId, domain.proxy, input.collection, input.tokenId]));
}

const blockedGate = {
  "token-staking": "H3/H5: reassign debits caller without recipient callback or approved pull; atomic raw-weight surrender unsupported",
  "underlying-se": "Use fixed W-SD or held-se-lp E-S/W-SW categories; E-S/W-SW typed exits require external legacy enablement; arbitrary sources remain unsupported",
  "fungible-lp": "Use fixed held-se-lp E-P/W-P originals; W-P recovery requires actual legacy liquidity authority, while E-P remains in custody under its immutable owner-only restriction",
  "earlier-liquidation": "Recovery operation, not another compensation original: use earlier-liquid/earlier-receipt originals and the explicit typed swap or reward-funded redemption stages",
} as const;

export function dispositions(input: PreparationInput) {
  return categories.map((category) => {
    switch (category) {
      case "independent": return { category, disposition: "bounded", gate: "verified disjoint originals only" };
      case "weighted-nft":
      case "earlier-nft": return { category, disposition: "bounded", gate: "explicit original-wallet configuration and actual same-wallet NFT surrender required" };
      case "claim-vault": return { category, disposition: "bounded", gate: "fixed direct native19 shares, explicit original-wallet inputs and actual custody; raw weights remain unsupported and operational originals unapproved" };
      case "dtf-custody-se": return { category, disposition: "bounded", gate: "fixed W-SD original-wallet native 28-decimal share inputs and measured custody; original operational allocations remain unapproved" };
      case "weighted-sy": return { category, disposition: "bounded", gate: "fixed WY original-wallet static-share/component inputs and measured custody; operational allocations remain unapproved" };
      case "weighted-liquid": return { category, disposition: "bounded", gate: "explicit original-wallet WD quantity/component allocation and measured surrender; operational allocations remain unapproved" };
      case "weighted-receipt": return { category, disposition: "bounded", gate: "fixed WS eligible original gons and known grouped components; synchronized native9 custody only; positive nonrepresentable Q/C remains recorded without promised future redemption; operational originals unapproved" };
      case "earlier-liquid": return { category, disposition: "bounded", gate: "fixed ED native18 originals, custody and frozen bonded credit; fixed public EL swap recovers DTF after legacy SE enablement without relying on the broken native burn; operational originals unapproved" };
      case "held-se-lp": return { category, disposition: "bounded", gate: "fixed W-SW/E-P/W-P/E-S custody and frozen credit; SE recovery requires legacy enablement, W-P recovery actual source liquidity authority; E-P remains in custody under immutable owner-only rules; local fixtures are not public governance approvals" };
      case "earlier-receipt": return { category, disposition: "bounded", gate: "fixed ER exact internal originals and frozen credit; singleton-rate custody; reward-funded parent redemption to ED then fixed DTF swap; NFT external shares/remainder and standalone internal shares remain separate; positive Q/C residue preserved and operational originals unapproved" };
      default: return { category, disposition: "blocked", gate: blockedGate[category] };
    }
  }).map((row) => ({ ...row, records: input.exposures.filter((e) => e.category === row.category).length.toString() }));
}

export function buildPayloads(input: PreparationInput): ConfigurationPayload {
  validateClaimedSyInputs(input);
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
    if (!nftContributionsAllowed(input.domain.chainId, original)) {
      throw new PreparationError("INPUT", "weighted NFT 3 requires separate exact raw18 ETH and DTF originals");
    }
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
  const weightedSy = input.weightedSy.map(({ original, claimedOrigin }) => {
    if (input.domain.chainId !== "4663" || original.source !== weightedSySource) {
      throw new PreparationError("DOMAIN", "weighted SY source requires fixed WY on chain 4663");
    }
    claimOrigin(original.originalId, "weighted-sy");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "weighted SY original units differ from reconciled origin");
    }
    const originalWeight = claimedOrigin?.review.originalWeight;
    if (!claimedOrigin || originalWeight === undefined) return original;
    return { ...original,
      claimBasis: { originalWeight, eligibleWeight: claimedOrigin.review.eligibleWeight } };
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
  const claimVault = input.claimVault.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== claimVaultSource) {
      throw new PreparationError("DOMAIN", "claim-vault source requires fixed native19 vault on chain 4663");
    }
    claimOrigin(original.originalId, "claim-vault");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "claim-vault original units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const weightedReceipt = input.weightedReceipt.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== weightedReceiptSource) {
      throw new PreparationError("DOMAIN", "weighted receipt requires fixed WS on chain 4663");
    }
    claimOrigin(original.originalId, "weighted-receipt");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "weighted receipt eligible original gons differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const earlierReceipt = input.earlierReceipt.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== earlierReceiptSource) {
      throw new PreparationError("DOMAIN", "earlier receipt requires fixed ER on chain 4663");
    }
    claimOrigin(original.originalId, "earlier-receipt");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "earlier receipt eligible original internal shares differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const earlierLiquid = input.earlierLiquid.map(({ original }) => {
    if (input.domain.chainId !== "4663" || original.source !== earlierLiquidSource) {
      throw new PreparationError("DOMAIN", "earlier liquid requires fixed native18 ED on chain 4663");
    }
    claimOrigin(original.originalId, "earlier-liquid");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "earlier liquid original native18 units differ from reconciled origin");
    }
    return original;
  }).sort((a, b) => a.originalId.localeCompare(b.originalId));
  const heldSeLp = input.heldSeLp.map(({ original }) => {
    if (input.domain.chainId !== "4663" || !heldSeLpSources.some((source) => source === original.source)) {
      throw new PreparationError("DOMAIN", "held SE/LP custody requires one of three fixed native18 sources on chain 4663");
    }
    claimOrigin(original.originalId, "held-se-lp");
    if (origins.get(original.originalId)?.originalUnits !== original.originalUnits) {
      throw new PreparationError("PROVENANCE", "held SE/LP original native18 units differ from reconciled origin");
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
      case "ClaimVaultRedeem":
      case "WeightedConvert":
      case "EarlierConvert":
      case "WeightedWethSeConvert":
      case "EarlierSeConvert":
      case "WeightedLpRedeem":
      case "EarlierNftReceiptRedeem":
      case "EarlierStandaloneReceiptRedeem":
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
  return { independent, nfts, weightedLiquid, weightedSy, dtfCustodySe, claimVault, weightedReceipt, earlierReceipt, earlierLiquid, heldSeLp };
}
