import { candidateError, field, integer, optionalInteger, table, unique } from "./candidate-input.js";
import type { CandidateInput, TableRow } from "./candidate-input.js";

export const legacy = {
  weightedNft: "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e",
  earlierNft: "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391",
  weighted: "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7",
  dtf: "0xee5576fa1bcaa380e591d01245f406f3f384eb01",
  weth: "0x0bd7d308f8e1639fab988df18a8011f41eacad73",
  zero: `0x${"0".repeat(40)}`,
} as const;
export type NftObservation = {
  readonly key: string; readonly model: "fixed-principal" | "lp-accounting-lock";
  readonly collection: string; readonly tokenId: string; readonly purchaseTx: string;
  readonly recipientObservation: string; readonly currentOwnerObservation: string | null;
  readonly periodObservation: string; readonly basis: { readonly unit: string; readonly value: string | null };
  readonly directInputs: readonly { readonly asset: string; readonly unit: "native18"; readonly observedRaw: string | null;
    readonly attributedRaw: string | null; readonly payers: readonly string[]; readonly locators: readonly string[] }[];
  readonly routedDtfRaw: string | null; readonly mintLocators: readonly string[];
  readonly corroboratingLocators: readonly string[]; readonly purchaseLocator: string;
  readonly flags: readonly string[];
};
const lower = (r: TableRow, k: string): string => field(r, k).toLowerCase();
export function deriveNfts(input: CandidateInput): readonly NftObservation[] {
  const purchases = table(input, "evidence/weighted-bonds.csv");
  const cp = table(input, "evidence/earlier-cp-bonds.csv");
  const transfers = table(input, "evidence/transfers.csv");
  const details = table(input, "../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv");
  unique(purchases, "token_id"); unique(cp, "token_id"); unique(transfers, "event_id");
  const byTx = new Map<string, TableRow[]>();
  for (const r of transfers) {
    const tx = lower(r, "tx");
    byTx.set(tx, [...(byTx.get(tx) ?? []), r]);
    const expected = `${lower(r, "asset")}:${tx}:${integer(field(r, "log_index"))}`;
    if (lower(r, "event_id") !== expected) candidateError(`event ID differs: ${r.locator}`);
    integer(field(r, "block")); integer(field(r, "transaction_index"));
    optionalInteger(field(r, "amount_raw")); optionalInteger(field(r, "token_id"));
  }
  const rows: NftObservation[] = purchases.map((r) => {
    const id = integer(field(r, "token_id")), tx = lower(r, "purchase_tx");
    const recipient = lower(r, "purchase_recipient");
    const events = byTx.get(tx) ?? [];
    const mints = events.filter((e) => lower(e, "asset") === legacy.weightedNft && lower(e, "from") === legacy.zero);
    const ownMints = mints.filter((e) => field(e, "token_id") === id && lower(e, "to") === recipient);
    const shared = purchases.filter((p) => lower(p, "purchase_tx") === tx).length !== 1 || mints.length !== 1;
    const flags = ["wallet-control-review-required", "current-state-stale", "native-refunds-net-contribution-unproved", "prior-delivery-unknown", "representation-overlap-review"];
    if (shared) flags.push("ambiguous-transaction-sharing");
    if (ownMints.length !== 1) flags.push("mint-match-conflict");
    if (ownMints.some((m) => field(m, "block") !== field(r, "purchase_block"))) flags.push("purchase-block-conflict");
    const pre = BigInt(integer(field(r, "purchase_block"))) < BigInt(input.sources.incident.attackBlock);
    if (field(r, "pre_attack") !== String(pre)) flags.push("period-conflict");
    const corroboration = details.filter((d) => lower(d, "tx") === tx && field(d, "category") === "bond" && field(d, "bond_token_id") === id);
    const directInputs = [legacy.dtf, legacy.weth].map((asset) => {
      const inbound = events.filter((e) => lower(e, "asset") === asset && lower(e, "to") === legacy.weighted);
      const payers = [...new Set(inbound.map((e) => lower(e, "from")))].sort();
      const conflict = payers.some((payer) => payer !== recipient);
      if (conflict) flags.push(`payer-or-routing-conflict:${asset}`);
      // Zero means zero in the saved inbound subset, never zero net cost.
      const observedRaw = inbound.reduce((s, e) => s + BigInt(integer(field(e, "amount_raw"))), 0n).toString();
      return { asset, unit: "native18" as const, observedRaw,
        attributedRaw: shared || conflict || ownMints.length !== 1 ? null : observedRaw,
        payers, locators: inbound.map((e) => e.locator).sort() };
    });
    const dtf = directInputs.find((i) => i.asset === legacy.dtf);
    if (pre && dtf?.observedRaw !== "0") {
      const sum = corroboration.reduce((s, d) => s + BigInt(integer(field(d, "dtf_wei"))), 0n).toString();
      if (sum !== dtf?.observedRaw || corroboration.some((d) => lower(d, "payer") !== recipient
        || lower(d, "bond_recipient") !== recipient)) flags.push("S006-input-conflict");
    }
    return { key: `${input.sources.chainId}:${legacy.weightedNft}:${id}`, collection: legacy.weightedNft, tokenId: id,
      model: "fixed-principal", purchaseTx: tx, recipientObservation: recipient,
      currentOwnerObservation: lower(r, "current_owner"), periodObservation: pre ? "pre_incident" : "post_incident",
      basis: { unit: "weighted-principal-native9", value: optionalInteger(field(r, "original_principal_detf_raw")) },
      directInputs: flags.some((flag) => /conflict/.test(flag))
        ? directInputs.map((i) => ({ ...i, attributedRaw: null })) : directInputs,
      routedDtfRaw: null, mintLocators: ownMints.map((e) => e.locator).sort(),
      corroboratingLocators: corroboration.map((d) => d.locator).sort(), purchaseLocator: r.locator, flags };
  });
  for (const r of cp) {
    const id = integer(field(r, "token_id"));
    rows.push({
      key: `${input.sources.chainId}:${legacy.earlierNft}:${id}`, model: "lp-accounting-lock",
      collection: legacy.earlierNft, tokenId: id, purchaseTx: lower(r, "purchase_tx"),
      recipientObservation: lower(r, "owner"), currentOwnerObservation: null, periodObservation: "historical-earlier-purchase",
      basis: { unit: "original-LP-accounting-shares-not-physical-LP", value: optionalInteger(field(r, "original_lp_shares_raw")) },
      directInputs: [["direct_dtf_paid_raw", legacy.dtf], ["direct_weth_paid_raw", legacy.weth]].map(([key, asset]) => {
        if (!key || !asset) return candidateError("invalid CP input mapping");
        const value = optionalInteger(field(r, key));
        return { asset, unit: "native18", observedRaw: value, attributedRaw: null,
          payers: [lower(r, "owner")], locators: [`${r.locator}/${key}`] };
      }),
      routedDtfRaw: optionalInteger(field(r, "routed_dtf_received_by_detf_raw")),
      mintLocators: [], corroboratingLocators: [], purchaseLocator: r.locator,
      flags: ["original-raw-receipts-missing", "wallet-control-review-required", "current-state-stale",
        "prior-delivery-unknown", "representation-overlap-review", "routed-DTF-not-an-additional-contribution"],
    });
  }
  return rows.sort((a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : 0);
}
