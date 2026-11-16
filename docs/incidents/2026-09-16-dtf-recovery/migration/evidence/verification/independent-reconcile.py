"""Independent integer oracle. No producer code is imported or executed here."""
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Final

ROOT: Final = Path("/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01")
INCIDENT: Final = ROOT / "docs/incidents/2026-09-16-dtf-recovery"
OUT: Final = INCIDENT / "migration/evidence/verification"
assert Path.cwd() == ROOT


def table(relative: str):
    with (INCIDENT / relative).open(newline="") as handle:
        return list(csv.DictReader(handle, strict=True))


def document(path: Path):
    with path.open() as handle:
        return json.load(handle)


def digest(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


positions = table("positions.csv")
weighted = [row for row in positions if row["product"] == "weighted"]
earlier = [row for row in positions if row["product"] == "earlier_cp"]
held = [row for row in table("held-exclusions.csv") if row["product"] == "weighted"]
accounts = table("account-ledger.csv")
recoveries = table("observed-recoveries.csv")
inventory = table("custody-inventory.csv")
bonds = table("evidence/weighted-bonds.csv")
cp_bonds = table("evidence/earlier-cp-bonds.csv")
transfers = table("evidence/transfers.csv")
producer = document(INCIDENT / "migration/evidence/provenance/reconciliation.json")
rerun = document(OUT / "reconciliation.json")
frozen = document(INCIDENT / "reconciliation.json")
checks = []


def compare(name: str, actual, expected) -> None:
    checks.append({"name": name, "actual": str(actual), "expected": str(expected),
                   "pass": actual == expected})


# Bases are the frozen provenance report section 6.2, not producer return values.
lookthrough = []
for row in weighted:
    q = int(row["quantity_raw"])
    kind = row["kind"]
    match kind:
        case "liquid" | "staked":
            value = q
        case "sy":
            value = q * 73604571731 // 66535753862
        case "legacy_stake":
            shares = q * 35589506697 // 19712889616977499499766803
            value = shares * 73604571731 // 66535753862
        case "funded_bond":
            value = int(row["staking_gons"]) // 903962246886315724026911557873968023
        case _:
            raise AssertionError(("unhandled position kind", kind))
    lookthrough.append({"position": row["position_id"], "computed": str(value),
                        "saved": row["detf_equivalent_raw"],
                        "pass": value == int(row["detf_equivalent_raw"])})

totals = {
    "weighted_position_rows": len(weighted),
    "earlier_position_rows": len(earlier),
    "account_rows": len(accounts),
    "look_through_mismatches": sum(not row["pass"] for row in lookthrough),
    "weighted_nominal_detf_exposure_raw": str(sum(int(row["computed"]) for row in lookthrough)),
    "held_exclusion_lower_bound_raw": str(sum(int(row["held_exclusion_detf_raw"]) for row in held)),
    "unresolved_snapshot_remainder_raw": str(sum(int(row["unresolved_snapshot_remainder_detf_raw"]) for row in held)),
    "nft_pre_gons_raw": str(sum(int(row["staking_gons"]) for row in weighted if row["kind"] == "funded_bond")),
    "recovery_observations": len(recoveries),
    "recovery_raw_dtf_sum": str(sum(int(row["observed_amount_raw"]) for row in recoveries)),
    "issuable_accounts": sum(row["issuable"] == "true" for row in accounts),
    "upfront_credit_for_current_holdings_raw": str(sum(int(row["upfront_bond_credit_for_this_holding_raw"]) for row in inventory)),
}
for key, value in totals.items():
    compare(key, value, producer["historical_diagnostics"]["checks"][key])
    compare(f"rerun:{key}", value, rerun["historical_diagnostics"]["checks"][key])
compare("held partition", int(totals["held_exclusion_lower_bound_raw"]) +
        int(totals["unresolved_snapshot_remainder_raw"]), int(totals["weighted_nominal_detf_exposure_raw"]))
for row in held:
    compare(f"partition:{row['position_id']}",
            int(row["held_exclusion_detf_raw"]) + int(row["unresolved_snapshot_remainder_detf_raw"]),
            int(row["snapshot_exposure_detf_raw"]))

dtf = "0xee5576fa1bcaa380e591d01245f406f3f384eb01"
weth = "0x0bd7d308f8e1639fab988df18a8011f41eacad73"
detf = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7"
weighted_joins = []
for bond in bonds:
    inbound = [t for t in transfers if t["tx"].lower() == bond["purchase_tx"].lower()
               and t["to"].lower() == detf and t["asset"].lower() in {dtf, weth}]
    assert inbound
    assert all(t["from"].lower() == bond["purchase_recipient"].lower() for t in inbound)
    amounts = {asset: sum(int(t["amount_raw"]) for t in inbound if t["asset"].lower() == asset)
               for asset in (dtf, weth)}
    expected = next(j for j in producer["contribution_joins"]["weighted_nft"]
                    if j["token_id"] == bond["token_id"])
    compare(f"weighted:{bond['token_id']}:DTF", str(amounts[dtf]), expected["original_contribution_dtf"]["raw"])
    compare(f"weighted:{bond['token_id']}:WETH", str(amounts[weth]), expected["original_contribution_weth"]["raw"])
    remaining = int(bond["original_principal_detf_raw"]) - int(bond["claimed_principal_detf_raw"])
    compare(f"weighted:{bond['token_id']}:remaining", str(remaining), bond["remaining_principal_detf_raw"])
    weighted_joins.append({"token_id": bond["token_id"], "DTF": str(amounts[dtf]),
                           "WETH": str(amounts[weth]), "remaining": str(remaining),
                           "logs": [t["event_id"] for t in inbound]})
for row in cp_bonds:
    expected = next(j for j in producer["contribution_joins"]["earlier_cp_nft"]
                    if j["token_id"] == row["token_id"])
    for source, target in (("direct_dtf_paid_raw", "original_contribution_dtf"),
                           ("direct_weth_paid_raw", "original_contribution_weth"),
                           ("routed_dtf_received_by_detf_raw", "routed_intermediate_dtf")):
        compare(f"earlier:{row['token_id']}:{source}", row[source], expected[target]["raw"])

fingerprints = []
source_manifest = document(INCIDENT / "sources.json")
manifest = document(INCIDENT / "manifest.json")
for label, path, expected in (
    [(s["id"], s["path"], s["sha256"]) for s in source_manifest["sources"]]
    + [(path, path, meta["sha256"]) for path, meta in manifest["files"].items()]
):
    actual = digest(INCIDENT / path)
    fingerprints.append({"label": label, "path": path, "expected": expected,
                         "actual": actual, "pass": actual == expected})

blank_counts = {field: sum(row[field] == "" for row in accounts)
                for field in ("V_eth", "R_eth", "E_eth", "H_eth", "new_detf_bond_allocation_raw")}
compare("UNKNOWN recovery ETH count", sum(row["R_eth"] == "" for row in recoveries), 69)
for field, count in blank_counts.items():
    compare(f"UNKNOWN:{field}", count, 435)
duplicate_keys = {}
for filename, key in (("positions.csv", "position_id"), ("account-ledger.csv", "ledger_id"),
                      ("held-exclusions.csv", "position_id"), ("custody-inventory.csv", "holding_id"),
                      ("observed-recoveries.csv", "recovery_id"), ("conversions.csv", "conversion_id"),
                      ("evidence/transfers.csv", "event_id")):
    counts = Counter(row[key] for row in table(filename))
    duplicate_keys[filename] = {k: v for k, v in counts.items() if v > 1}
    compare(f"duplicates:{filename}", len(duplicate_keys[filename]), 0)

# Independent arbitrary-precision arithmetic. This is an oracle, not a Migration SUT.
rounding = []
for units in range(1, 33):
    for credit in range(33):
        for first in range(1, units + 1):
            award = credit * first // units
            remaining_credit = credit - award
            compare(f"rounding:{units}:{credit}:{first}", award + remaining_credit, credit)
            if first == units:
                compare(f"whole:{units}:{credit}", remaining_credit, 0)
rounding.append({"units": "7", "credit": "10", "awards": ["1", "1", "8"]})
compare("7/10 partial closure", 10 * 1 // 7, 1)
compare("remaining 6/9 partial", 9 * 1 // 6, 1)
compare("fixed principal 1000 * 60 / 100", 1000 * 60 // 100, 600)
cross_path = {"nft_award": "600", "unauthorized_descendant": "400",
              "overlapping_independent": "1000", "invalid_sum": "2000",
              "wrapper_credit": "901", "double_representation_sum": "1802",
              "mechanism_enforces_rejection": False}
compare("producer rerun byte determinism", digest(OUT / "reconciliation.json"),
        digest(OUT / "reconciliation-repeat.json"))
compare("producer output reproduced byte for byte", digest(OUT / "reconciliation.json"),
        digest(INCIDENT / "migration/evidence/provenance/reconciliation.json"))
result = {
    "scope": "independent Python integer recomputation; not operational allocations",
    "totals": totals, "weighted_joins": weighted_joins, "lookthrough": lookthrough,
    "fingerprints": fingerprints, "blank_counts": blank_counts,
    "duplicate_keys": duplicate_keys, "rounding": rounding, "cross_path": cross_path,
    "checks_count": len(checks), "failed": [c for c in checks if not c["pass"]],
    "checks": checks,
    "limits": ["No independent full-chain acquisition census.",
               "Held lower-bound partition is checked, not a new proportional ancestry proof.",
               "Rounding vectors do not prove deployed rejection or bond creation."],
}
with (OUT / "independent-reconciliation.json").open("w") as handle:
    json.dump(result, handle, indent=2)
    handle.write("\n")
print(f"INDEPENDENT_RECONCILIATION {'PASS' if not result['failed'] else 'FAIL'} "
      f"checks={len(checks)} failed={len(result['failed'])}")
raise SystemExit(0 if not result["failed"] else 2)
