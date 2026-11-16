# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Run: python3 relations.py RECOVERED_ROOT CANDIDATES_JSON OUTPUT_JSON
# Second independent oracle: source joins and historical diagnostic arithmetic.
import bisect
import csv
import io
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

root = Path(sys.argv[1])
candidate = json.loads(Path(sys.argv[2]).read_bytes())
tables = {
    census["path"]: list(csv.DictReader(io.StringIO((root / census["path"]).read_text(), newline=""), strict=True))
    for census in candidate["rawRecordCensus"]
}
sources = json.loads((root / "sources.json").read_bytes())
snapshot = json.loads((root / "../2026-09-16-dtf-pre-exploit/snapshot.json").read_bytes())
records = {r["locator"]: r for r in candidate["inventory"]}
source_ids = {s["id"] for s in sources["sources"]}
for row in records.values():
    for column in ("source_id", "source_ids"):
        assert set(filter(None, row["historicalFields"].get(column, "").split("|"))) <= source_ids
keys = {
    "positions.csv": "position_id", "held-exclusions.csv": "position_id",
    "custody-inventory.csv": "holding_id", "observed-recoveries.csv": "recovery_id",
    "conversions.csv": "conversion_id", "account-ledger.csv": "ledger_id", "exceptions.csv": "exception_id",
    "evidence/transfers.csv": "event_id", "evidence/index-events.csv": "source",
    "evidence/all-index-events.csv": "source",
}
indexes = {}
locators = {}
for path, key in keys.items():
    indexes[path] = {r[key]: r for r in tables[path]}
    locators[path] = {r[key]: f"{path}#row={i}" for i, r in enumerate(tables[path], 2)}
    assert len(indexes[path]) == len(tables[path]), (path, key)
account_members = defaultdict(set)
for account in tables["account-ledger.csv"]:
    assert account["ledger_id"] == account["product"] + ":" + account["account"]
    for column, path, owner in (
        ("position_ids", "positions.csv", "account"),
        ("current_holding_ids", "custody-inventory.csv", "observed_holder"),
        ("observed_recovery_ids", "observed-recoveries.csv", "recipient"),
    ):
        ids = list(filter(None, account[column].split("|")))
        assert len(ids) == len(set(ids))
        for key in ids:
            member = indexes[path][key]
            assert member[owner] == account["account"] and member["product"] == account["product"]
            assert key not in account_members[path]
            account_members[path].add(key)
            assert locators[path][key] in records[locators["account-ledger.csv"][account["ledger_id"]]]["links"]
    assert set(filter(None, account["exception_ids"].split("|"))) <= indexes["exceptions.csv"].keys()
for path in account_members:
    assert account_members[path] == indexes[path].keys()
all_indices = indexes["evidence/all-index-events.csv"]
assert all(all_indices[key] == row for key, row in indexes["evidence/index-events.csv"].items())
index_points = sorted(
    ((int(r["block"]), int(r["transaction_index"]), int(r["log_index"])), int(r["gons_per_unit"]))
    for r in all_indices.values()
)
points = [p for p, value in index_points]
gon_proofs = []
for row in tables["evidence/bond-accounting.csv"]:
    point = tuple(int(row["staking_" + key]) for key in ("block", "transaction_index", "log_index"))
    offset = bisect.bisect_left(points, point)
    divisor = index_points[offset - 1][1] if offset else 10**36
    assert divisor == int(row["gons_per_unit"])
    sign = 1 if row["event"] == "funding" else -1
    assert int(row["gons_delta"]) == sign * divisor * int(row["amount_raw"])
    gon_proofs.append({"source": row["source"], "eventIndex": str(divisor), "signedGons": row["gons_delta"]})
assert len({r["staking_source"] for r in tables["evidence/bond-accounting.csv"]}) == len(gon_proofs)
for row in tables["evidence/post-incident-bond-claims.csv"]:
    point = tuple(int(row[key]) for key in ("block", "transaction_index", "log_index"))
    offset = bisect.bisect_left(points, point)
    divisor = index_points[offset - 1][1] if offset else 10**36
    amount = int(row["sdetf_transferred_raw"])
    assert divisor == int(row["gons_per_unit"])
    assert amount == int(row["principal_claimed_raw"]) + int(row["rewards_claimed_raw"])
    assert amount * divisor == int(row["gons_debited"])
    matches = [r for r in tables["evidence/transfers.csv"] if r["tx"] == row["tx"]
               and r["to"] == row["recipient"] and r["amount_raw"] == row["sdetf_transferred_raw"]
               and r["asset"].lower() == snapshot["sdtfDetf"]["token"].lower()]
    assert len(matches) == 1
    assert matches[0]["log_index"] == row["log_index"]
    assert matches[0]["tx"] + ":" + matches[0]["log_index"] == row["staking_source"]
sy_backing = int(snapshot["sySdtfDetf"]["sdtfDetfBalanceRaw"])
sy_supply = int(snapshot["sySdtfDetf"]["supplyRaw"])
vault_sy = int(snapshot["sySdtfDetf"]["claimVaultSyRaw"])
total_weight = int(snapshot["stakePrincipalWei"])
snapshot_index = int(snapshot["sdtfDetf"]["gonsPerUnit"])
source_receipts = {r["address"].lower(): r for r in tables["../2026-09-16-dtf-pre-exploit/sdtf-detf-holders.csv"]}
observed = {r["address"].lower(): r for r in tables["evidence/weighted-candidates.csv"]}
balances = defaultdict(int)
outgoing = defaultdict(int)
outgoing_gons = defaultdict(int)
for row in tables["evidence/transfers.csv"]:
    if not row["amount_raw"]:
        continue
    asset, sender, recipient = row["asset"].lower(), row["from"].lower(), row["to"].lower()
    amount = int(row["amount_raw"])
    if int(row["block"]) < sources["incident"]["attackBlock"]:
        balances[asset, sender] -= amount
        balances[asset, recipient] += amount
    elif sender != recipient:
        outgoing[asset, sender] += amount
        point = tuple(int(row[key]) for key in ("block", "transaction_index", "log_index"))
        offset = bisect.bisect_left(points, point)
        divisor = index_points[offset - 1][1] if offset else 10**36
        outgoing_gons[asset, sender] += amount * divisor
position_proofs = []
for position in tables["positions.csv"]:
    if position["product"] != "weighted":
        assert position["detf_equivalent_raw"] == ""
        continue
    quantity = int(position["quantity_raw"])
    account, asset = position["account"], position["asset"].lower()
    h = indexes["held-exclusions.csv"][position["position_id"]]
    match position["kind"]:
        case "liquid":
            assert balances[asset, account] == quantity
            exposure = quantity
            retained = min(int(h["current_observed_quantity_raw"]), max(0, quantity - outgoing[asset, account]))
            assert int(h["outgoing_source_units_raw"]) == outgoing[asset, account]
            held_value = retained
        case "staked":
            exposure = int(source_receipts[account]["balance_raw"])
            assert exposure == quantity
            retained = max(0, int(source_receipts[account]["gons"]) - outgoing_gons[asset, account])
            assert int(h["outgoing_source_units_raw"]) == outgoing_gons[asset, account]
            held_value = retained // snapshot_index
        case "sy":
            exposure = quantity * sy_backing // sy_supply
            retained = min(int(h["current_observed_quantity_raw"]), max(0, quantity - outgoing[asset, account]))
            assert int(h["outgoing_source_units_raw"]) == outgoing[asset, account]
            held_value = retained * sy_backing // sy_supply
        case "legacy_stake":
            intermediate = quantity * vault_sy // total_weight
            assert intermediate == int(position["intermediate_sy_raw"])
            exposure = intermediate * sy_backing // sy_supply
            retained = min(quantity, int(observed[account]["current_legacy_stake_dtf_raw"]))
            held_value = (retained * vault_sy // total_weight) * sy_backing // sy_supply
        case "funded_bond":
            proofs = [r for r in tables["evidence/bond-accounting.csv"] if r["token_id"] == position["source_key"]]
            assert sum(int(r["gons_delta"]) for r in proofs) == int(position["staking_gons"])
            assert sum(r["event"] == "funding" for r in proofs) == 1
            exposure = int(position["staking_gons"]) // snapshot_index
            debited = sum(int(r["gons_debited"]) for r in tables["evidence/post-incident-bond-claims.csv"] if r["token_id"] == position["source_key"])
            retained = max(0, int(position["staking_gons"]) - debited) if int(h["current_observed_quantity_raw"]) else 0
            held_value = retained // snapshot_index
        case unexpected:
            raise AssertionError(unexpected)
    assert exposure == int(position["detf_equivalent_raw"]), position["position_id"]
    assert retained == int(h["retained_source_units_lower_bound_raw"]), position["position_id"]
    assert held_value == int(h["held_exclusion_detf_raw"]), position["position_id"]
    position_proofs.append({"position": position["position_id"], "exposureNative9": str(exposure),
                            "heldNative9": str(held_value), "retainedSourceUnits": str(retained), "unit": h["source_unit"]})
conversion_proofs = []
for row in tables["conversions.csv"]:
    matches = [r for r in tables["evidence/transfers.csv"] if r["tx"] == row["tx"]
               and r["asset"].lower() == row["output_asset"].lower() and r["to"] == row["recipient"]
               and r["amount_raw"] == row["output_raw"]]
    assert len(matches) == 1, row["conversion_id"]
    assert row["is_external_recovery"] == "false"
    conversion_proofs.append({"conversion": row["conversion_id"], "event": matches[0]["event_id"]})
for account in tables["account-ledger.csv"]:
    if account["product"] == "weighted":
        assert sum(int(p["detf_equivalent_raw"]) for p in tables["positions.csv"] if p["product"] == "weighted" and p["account"] == account["account"]) == int(account["nominal_detf_exposure_raw"])
result = {"version": "independent-relations-v1", "positions": position_proofs, "eventTimeGons": gon_proofs,
          "postIncidentClaims": len(tables["evidence/post-incident-bond-claims.csv"]),
          "conversions": conversion_proofs, "allAccountMembershipsComplete": True,
          "proofLinks": Counter(r["check"] for r in candidate["historicalProofLinks"]),
          "sourceUnitLimit": "Earlier native18 display is not internal shares; no fabricated Q0; no user native19/native28 evidence invented."}
with Path(sys.argv[3]).open("x") as stream:
    json.dump(result, stream, indent=2)
    stream.write("\n")
print(json.dumps({"positionsRecomputed": len(position_proofs), "eventTimeProofs": len(gon_proofs),
                  "claims": result["postIncidentClaims"], "conversions": len(conversion_proofs)}))
