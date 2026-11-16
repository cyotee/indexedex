import { candidateError, field, integer, signedInteger } from "./candidate-input.js";
import type { TableRow } from "./candidate-input.js";
import type { ReviewIssue } from "./candidate-inventory.js";
import { order } from "./candidate-inventory.js";

export function reconcileHistoricalProofs(tables: ReadonlyMap<string, readonly TableRow[]>) {
  const get = (p: string): readonly TableRow[] => tables.get(p) ?? candidateError(`missing proof table ${p}`);
  const claims = get("evidence/post-incident-bond-claims.csv");
  const accounting = get("evidence/bond-accounting.csv");
  const indices = get("evidence/all-index-events.csv");
  const transfers = get("evidence/transfers.csv");
  const point = (r: TableRow, prefix = ""): readonly bigint[] =>
    [`${prefix}block`, `${prefix}transaction_index`, `${prefix}log_index`].map((k) => BigInt(integer(field(r, k))));
  const compare = (a: readonly bigint[], b: readonly bigint[]): number => {
    for (let i = 0; i < 3; i++) {
      const x = a[i], y = b[i];
      if (x === undefined || y === undefined) candidateError("missing event coordinate");
      if (x !== y) return x < y ? -1 : 1;
    }
    return 0;
  };
  const sortedIndices = [...indices].sort((a, b) => compare(point(a), point(b)));
  const indexAt = (p: readonly bigint[]): bigint => {
    const prior = sortedIndices.filter((i) => compare(point(i), p) < 0).at(-1);
    return prior ? BigInt(integer(field(prior, "gons_per_unit"))) : 10n ** 36n;
  };
  const used = new Set<string>();
  const links: { readonly record: string; readonly evidence: readonly string[]; readonly check: string }[] = [];
  const unresolved: ReviewIssue[] = [];
  for (const r of accounting) {
    const amount = BigInt(integer(field(r, "amount_raw")));
    const divisor = BigInt(integer(field(r, "gons_per_unit")));
    const sign = field(r, "event") === "funding" ? 1n : -1n;
    if (sign * amount * divisor !== BigInt(signedInteger(field(r, "gons_delta"))) || divisor !== indexAt(point(r, "staking_")))
      candidateError(`event-time gons proof differs: ${r.locator}`);
    const id = field(r, "staking_source");
    if (used.has(id)) candidateError(`duplicate staking proof ${id}`);
    used.add(id);
    links.push({ record: r.locator, evidence: sortedIndices.filter((i) =>
      field(i, "gons_per_unit") === divisor.toString()).map((i) => i.locator), check: "amount-times-event-index" });
  }
  for (const p of get("positions.csv").filter((r) => field(r, "kind") === "funded_bond")) {
    const id = field(p, "source_key");
    const proofs = accounting.filter((r) => field(r, "token_id") === id);
    const funding = proofs.filter((r) => field(r, "event") === "funding");
    if (funding.length !== 1) candidateError(`missing/duplicate NFT funding ${p.locator}`);
    const balance = proofs.reduce((s, r) => s + BigInt(signedInteger(field(r, "gons_delta"))), 0n);
    if (balance !== BigInt(integer(field(p, "staking_gons")))) candidateError(`NFT snapshot gons differ: ${p.locator}`);
    links.push({ record: p.locator, evidence: proofs.map((r) => r.locator), check: "funding-minus-claims-snapshot-gons" });
  }
  for (const r of claims) {
    const amount = BigInt(integer(field(r, "sdetf_transferred_raw")));
    const divisor = BigInt(integer(field(r, "gons_per_unit")));
    if (amount !== BigInt(integer(field(r, "principal_claimed_raw"))) + BigInt(integer(field(r, "rewards_claimed_raw")))
      || amount * divisor !== BigInt(integer(field(r, "gons_debited"))) || divisor !== indexAt(point(r)))
      candidateError(`post-incident claim proof differs: ${r.locator}`);
    const matches = transfers.filter((t) => field(t, "tx") === field(r, "tx") &&
      field(t, "to") === field(r, "recipient") && field(t, "amount_raw") === amount.toString()
      && field(t, "asset") === "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c");
    if (matches.length !== 1) candidateError(`claim transfer ambiguous/missing: ${r.locator}`);
    const match = matches[0];
    if (!match || used.has(match.locator)) candidateError(`claim transfer reused: ${r.locator}`);
    used.add(match.locator);
    links.push({ record: r.locator, evidence: matches.map((m) => m.locator), check: "principal-plus-rewards-and-event-time-gons" });
  }
  for (const a of get("account-ledger.csv")) {
    if (field(a, "product") !== "weighted") continue;
    const positions = get("positions.csv").filter((p) => field(p, "account") === field(a, "account") && field(p, "product") === "weighted");
    const exposure = positions.reduce((s, p) => s + BigInt(integer(field(p, "detf_equivalent_raw"))), 0n);
    if (exposure !== BigInt(integer(field(a, "nominal_detf_exposure_raw")))) candidateError(`account nominal sum differs: ${a.locator}`);
    links.push({ record: a.locator, evidence: positions.map((p) => p.locator), check: "same-unit-historical-account-sum" });
  }
  // Some conversion records decode non-Transfer events; their original logs are
  // not independently archived. Keep that limit, rather than fabricate locators.
  for (const r of get("conversions.csv")) if (field(r, "kind") === "legacy_weight_to_sy")
    unresolved.push({ code: "raw-claim-event-archive-missing", records: [r.locator],
      detail: "Normalized raw-weight consumption is historical evidence; original claim receipt/decoded event archival and remaining/prior-delivered partition are not supplied." });
  return { links: links.sort((a, b) => order(a.record, b.record)), unresolved };
}
