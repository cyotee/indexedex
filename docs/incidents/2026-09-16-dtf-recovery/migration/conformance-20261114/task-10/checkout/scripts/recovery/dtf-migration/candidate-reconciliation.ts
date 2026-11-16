import { z } from "zod";
import { candidateError, field, integer } from "./candidate-input.js";
import type { CandidateInput, TableRow } from "./candidate-input.js";
import type { NftObservation } from "./candidate-nfts.js";
import type { ReviewIssue } from "./candidate-inventory.js";

export function reconcileCandidateTotals(input: CandidateInput, tables: ReadonlyMap<string, readonly TableRow[]>) {
  const get = (p: string): readonly TableRow[] => tables.get(p) ?? candidateError(`missing table ${p}`);
  const sum = (rows: readonly TableRow[], k: string): string =>
    rows.reduce((s, r) => s + BigInt(integer(field(r, k))), 0n).toString();
  const weighted = get("positions.csv").filter((r) => field(r, "product") === "weighted");
  const held = get("held-exclusions.csv").filter((r) => field(r, "product") === "weighted");
  const raw = input.bytes.get("reconciliation.json");
  if (!raw) candidateError("missing reconciliation");
  const reported = z.record(z.union([z.string(), z.number().int().safe(), z.boolean()]))
    .parse(JSON.parse(new TextDecoder().decode(raw)));
  const computed: Readonly<Record<string, string | number>> = {
    weighted_position_rows: weighted.length,
    earlier_position_rows: get("positions.csv").length - weighted.length,
    account_rows: get("account-ledger.csv").length,
    weighted_snapshot_accounts: new Set(weighted.map((r) => field(r, "account"))).size,
    weighted_nominal_detf_exposure_raw: sum(weighted, "detf_equivalent_raw"),
    nft_pre_gons_reconstructed: sum(weighted.filter((r) => field(r, "kind") === "funded_bond"), "staking_gons"),
    recovery_observations: get("observed-recoveries.csv").length,
    recovery_raw_dtf_sum: sum(get("observed-recoveries.csv"), "observed_amount_raw"),
    conversions: get("conversions.csv").length,
    transfer_evidence_rows: get("evidence/transfers.csv").length,
    issuable_accounts: get("account-ledger.csv").filter((r) => field(r, "issuable") !== "false").length,
    weighted_confirmed_held_exclusion_lower_bound_raw: sum(held, "held_exclusion_detf_raw"),
    weighted_unresolved_snapshot_remainder_raw: sum(held, "unresolved_snapshot_remainder_detf_raw"),
    current_holding_inventory_rows: get("custody-inventory.csv").length,
    held_exclusion_rows: held.length + get("positions.csv").length - weighted.length,
    post_incident_bond_claim_proof_rows: get("evidence/post-incident-bond-claims.csv").length,
    staking_index_events_through_cutoff: get("evidence/all-index-events.csv").length,
  };
  const checks = Object.entries(computed).map(([key, actual]) => {
    const expected = reported[key];
    if (actual !== expected) candidateError(`reported total differs: ${key}, ${actual} != ${expected}`);
    return { key, computed: actual, reported: expected, status: "matched" as const };
  });
  return {
    checks,
    unverifiedReportedKeys: Object.keys(reported).filter((k) => !(k in computed)).sort(),
    unit: "historical diagnostic totals only; no awards and no sum across source units",
  };
}

// This census deliberately includes categories with no observed direct-user row.
// Infrastructure backing and historical wallet observations do not prove absence.
export function candidateCoverage(nfts: readonly NftObservation[], tables: ReadonlyMap<string, readonly TableRow[]>) {
  const assets = [
    ["W-L", "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "native9"],
    ["E-L", "0xaf0e1967c8f755c747615c5427108bc549ca1122", "native18"],
    ["W-N", "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e", "fixed-principal-native9"],
    ["E-N", "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391", "LP-accounting-shares"],
    ["W-R", "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c", "eligible-original-gons-not-display-native9"],
    ["E-R", "0x4ac89ad061a531fa62ddceed53520c2750113b01", "internal-shares-unknown-not-display-native18"],
    ["W-Y", "0xb55604cf4dcdabb362078e106d20f98512391edf", "native9-static-shares"],
    ["T", "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00", "raw-weight-native18"],
    ["C", "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", "native19"],
    ["E-S", "0xb7d4bb379d361ad442cddee53ea71a33957826a7", "native18"],
    ["W-SW", "0x999dae02d22e5fee1c4508430d5196d31d631009", "native18"],
    ["W-SD", "0x2e9c1f705ab967c5af59249203d7495bdabb223b", "native28"],
    ["E-P", "0x923877336b14662cfb5b3a60b14e7d716d54a888", "native18-physical-LP"],
    ["W-P", "0x46e068c2393e189fbc86632f67210af253a42aa8", "native18-physical-LP"],
    ["ETH", "native", "wei-contribution-recovery-only"],
    ["WETH", "0x0bd7d308f8e1639fab988df18a8011f41eacad73", "native18-contribution-recovery-only"],
  ] as const;
  return assets.map(([category, asset, unit]) => {
    const positions = (tables.get("positions.csv") ?? []).filter((r) => field(r, "asset").toLowerCase() === asset);
    const holdings = (tables.get("custody-inventory.csv") ?? []).filter((r) => field(r, "asset").toLowerCase() === asset);
    const purchases = nfts.filter((n) => n.collection === asset);
    const provenance = (tables.get("evidence/transfers.csv") ?? []).filter((r) => field(r, "asset").toLowerCase() === asset);
    return { category, asset, unit, positionLocators: positions.map((r) => r.locator),
      holdingLocators: holdings.map((r) => r.locator), purchaseKeys: purchases.map((n) => n.key),
      provenanceLocators: provenance.map((r) => r.locator),
      status: positions.length || holdings.length || purchases.length ? "observed-unreviewed" : "unobserved-not-proven-absent",
      provenanceStatus: provenance.length ? "observed-subset-not-complete-category-coverage" : "unobserved-not-proven-absent",
      use: category === "ETH" || category === "WETH" ? "contribution-recovery-provenance-not-surrender" : "source-review",
      originalBasis: "unresolved", currentControl: "unverified", priorDelivery: "unknown",
    };
  });
}
export const coverageIssues: readonly ReviewIssue[] = [
  { code: "missing-original-inputs-wallet-review", records: [], detail: "Historical observations do not establish original eligibility, configured original wallet or current control under MIG-R42." },
  { code: "partial-claims-prior-delivery", records: [], detail: "Reconcile all surviving raw rights, claimed descendants, excluded rewards and previous delivery. Never infer zero prior credit or assign full credit per partial slice." },
  { code: "representation-overlap-aliases", records: [], detail: "Independent compensation, NFTs, receipts, SY, raw weights, backing and LP representations can overlap; no unique economic origin is assigned here." },
  { code: "incomplete-WETH-native-recovery", records: [], detail: "S011 has inbound WETH only through 69999999 and selected DTF flows; native/refunds/net contributions and broader recovery remain unproved." },
  { code: "stale-current-state", records: [], detail: "Weighted observations end at 108944663. Earlier receipt reads are latest November 8, 2026 and unpinned. Neither is current control or the funded snapshot." },
  { code: "earlier-receipt-discrepancy", records: [], detail: "Reported positive balances 57880198310224980583 versus supply 57898677945502333609; gap not allocated." },
  { code: "missing-earlier-raw-receipts", records: [], detail: "S009 is a normalized observation, not original receipt archival; direct inputs and routed DTF remain separate." },
  { code: "unobserved-accepted-categories", records: [], detail: "No direct-user row does not prove no E-S, C, W-SW, W-SD or physical LP exposure. Infrastructure cannot be assigned as a second personal claim." },
  { code: "historical-policy-not-authority", records: [], detail: "Raw fields and exceptions retain obsolete loss/held/bearer policy as history only. Current plan/PRD govern; no old formula or zero upfront field becomes an award or prior credit." },
  { code: "review-acquisition-funded-snapshot-open", records: [], detail: "Acquire missing data only under separate authorization; review original units/components, disjointness and prior delivery, then fund/capture/quote before separate loader preparation. No intermediate-holder ancestry prerequisite." },
];
