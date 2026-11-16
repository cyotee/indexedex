# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Run: python3 independent.py RECOVERED_ROOT CANDIDATES_JSON OUTPUT_JSON
# Read-only independent oracle: stdlib CSV and arbitrary-precision integers.
# No imports from producer code and no network, pricing or eligibility decisions.
import csv
import hashlib
import io
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

root = Path(sys.argv[1])
candidate_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
manifest = json.loads((root / "manifest.json").read_bytes())
source_bytes = (root / "sources.json").read_bytes()
assert len(source_bytes) == manifest["files"]["sources.json"]["bytes"]
assert hashlib.sha256(source_bytes).hexdigest() == manifest["files"]["sources.json"]["sha256"]
sources = json.loads(source_bytes)
declarations = sources["sources"] + [
    {"path": name, **binding} for name, binding in manifest["files"].items()
]
raw = {"manifest.json": (root / "manifest.json").read_bytes()}
for declaration in declarations:
    body = (root / declaration["path"]).read_bytes()
    assert len(body) == declaration["bytes"], declaration
    assert hashlib.sha256(body).hexdigest() == declaration["sha256"], declaration
    raw[declaration["path"]] = body
tables = {
    name: list(csv.DictReader(io.StringIO(body.decode("utf-8"), newline=""), strict=True))
    for name, body in raw.items() if name.endswith(".csv")
}
candidate = json.loads(candidate_path.read_bytes())
assert candidate["version"] == "dtf-historical-review-candidates-v1"
assert candidate["status"] == "NON-ISSUABLE-REVIEW-CANDIDATES"
assert candidate["chainId"] == str(sources["chainId"])
assert candidate["observationBoundaries"]["incident"] == sources["incident"]
assert candidate["observationBoundaries"]["evidenceCutoff"] == sources["evidenceCutoff"]
assert candidate["observationBoundaries"]["historicalNotes"] == sources["sourceNotes"]
assert len(candidate["declarations"]) == len(declarations)
assert Counter((d["path"], d["bytes"], d["sha256"]) for d in candidate["declarations"]) == Counter(
    (d["path"], d["bytes"], d["sha256"]) for d in declarations)
assert {d["path"] for d in candidate["inputIdentities"]} == set(raw)
for identity in candidate["inputIdentities"]:
    body = raw[identity["path"]]
    assert identity["bytes"] == len(body)
    assert identity["sha256"] == hashlib.sha256(body).hexdigest()
    assert identity["sourceIds"] == sorted(s["id"] for s in sources["sources"] if s["path"] == identity["path"])
rows = {
    f"{name}#row={index}": fields
    for name, records in tables.items() for index, fields in enumerate(records, 2)
}
inventory = {record["locator"]: record for record in candidate["inventory"]}
assert len(inventory) == len(candidate["inventory"]) == len(rows)
assert inventory.keys() == rows.keys()
quantity_count = 0
for locator, fields in rows.items():
    record = inventory[locator]
    assert record["historicalFields"] == fields, locator
    assert locator == f'{record["path"]}#row={record["row"]}'
    assert len(record["links"]) == len(set(record["links"]))
    for link in record["links"]:
        assert link in rows, (locator, link)
        assert locator in inventory[link]["links"], (locator, link)
    expected_columns = {key for key in fields if re.search(
        r"(_raw$|_wei$|^dtf_wei_|^gons$|^staking_gons$|^gons_delta$|^gons_per_unit$|^gons_debited$|^[VRHE]_eth$)", key)}
    assert record["quantities"].keys() == expected_columns, locator
    for key, quantity in record["quantities"].items():
        value = fields[key]
        assert quantity["raw"] == (value if value else None), (locator, key)
        if value:
            assert re.fullmatch(r"0|-?[1-9][0-9]*" if key == "gons_delta" else r"0|[1-9][0-9]*", value)
            int(value)
        quantity_count += 1
assert {r["path"]: r["records"] for r in candidate["rawRecordCensus"]} == {
    name: len(records) for name, records in tables.items()}
transfers = tables["evidence/transfers.csv"]
events = {r["event_id"]: r for r in transfers}
assert len(events) == len(transfers)
by_tx = defaultdict(list)
for row in transfers:
    assert row["event_id"] == f'{row["asset"].lower()}:{row["tx"].lower()}:{int(row["log_index"])}'
    by_tx[row["tx"]].append(row)
nfts = {n["key"]: n for n in candidate["nfts"]}
assert len(nfts) == len(candidate["nfts"])
weighted_collection = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e"
earlier_collection = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391"
weighted_detf = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7"
dtf = "0xee5576fa1bcaa380e591d01245f406f3f384eb01"
weth = "0x0bd7d308f8e1639fab988df18a8011f41eacad73"
zero = "0x" + "0" * 40
weighted = tables["evidence/weighted-bonds.csv"]
purchase_transactions = Counter(r["purchase_tx"] for r in weighted)
weighted_proofs = []
details = tables["../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv"]
for index, row in enumerate(weighted, 2):
    key = f'4663:{weighted_collection}:{row["token_id"]}'
    n = nfts[key]
    tx_events = by_tx[row["purchase_tx"]]
    mints = [e for e in tx_events if e["asset"].lower() == weighted_collection and e["from"].lower() == zero]
    assert purchase_transactions[row["purchase_tx"]] == len(mints) == 1
    mint = mints[0]
    assert (mint["token_id"], mint["to"], mint["block"]) == (row["token_id"], row["purchase_recipient"], row["purchase_block"])
    assert n["mintLocators"] == [next(loc for loc, f in rows.items() if f is mint)]
    assert n["recipientObservation"] == row["purchase_recipient"].lower()
    assert n["currentOwnerObservation"] == row["current_owner"].lower()
    assert n["purchaseLocator"] == f"evidence/weighted-bonds.csv#row={index}"
    assert n["purchaseTx"] == row["purchase_tx"]
    assert n["basis"]["value"] == row["original_principal_detf_raw"]
    period = "pre_incident" if int(row["purchase_block"]) < sources["incident"]["attackBlock"] else "post_incident"
    assert n["periodObservation"] == period
    amounts = {}
    for asset in (dtf, weth):
        inbound = [e for e in tx_events if e["asset"].lower() == asset and e["to"].lower() == weighted_detf]
        amount = str(sum(int(e["amount_raw"]) for e in inbound))
        emitted = next(i for i in n["directInputs"] if i["asset"] == asset)
        assert all(e["from"].lower() == row["purchase_recipient"].lower() for e in inbound)
        assert emitted["observedRaw"] == emitted["attributedRaw"] == amount
        assert emitted["payers"] == sorted({e["from"].lower() for e in inbound})
        assert emitted["locators"] == sorted(loc for loc, f in rows.items() if any(f is e for e in inbound))
        assert emitted["unit"] == "native18"
        amounts[asset] = amount
    corroboration = [d for d in details if d["tx"] == row["purchase_tx"] and d["category"] == "bond" and d["bond_token_id"] == row["token_id"]]
    assert n["corroboratingLocators"] == sorted(loc for loc, f in rows.items() if any(f is d for d in corroboration))
    if period == "pre_incident" and amounts[dtf] != "0":
        assert sum(int(d["dtf_wei"]) for d in corroboration) == int(amounts[dtf])
        assert all(d["payer"].lower() == d["bond_recipient"].lower() == row["purchase_recipient"].lower() for d in corroboration)
    assert not any("conflict" in flag or "ambiguous" in flag for flag in n["flags"])
    weighted_proofs.append({"key": key, "tx": row["purchase_tx"], "period": period, "direct": amounts})
cp_proofs = []
for index, row in enumerate(tables["evidence/earlier-cp-bonds.csv"], 2):
    n = nfts[f'4663:{earlier_collection}:{row["token_id"]}']
    assert n["purchaseLocator"] == f"evidence/earlier-cp-bonds.csv#row={index}"
    assert n["purchaseTx"] == row["purchase_tx"]
    assert n["recipientObservation"] == row["owner"].lower()
    assert n["currentOwnerObservation"] is None
    assert n["basis"]["value"] == row["original_lp_shares_raw"]
    assert "not-physical-LP" in n["basis"]["unit"]
    assert [i["observedRaw"] for i in n["directInputs"]] == [row["direct_dtf_paid_raw"], row["direct_weth_paid_raw"]]
    assert all(i["attributedRaw"] is None for i in n["directInputs"])
    assert n["routedDtfRaw"] == row["routed_dtf_received_by_detf_raw"]
    assert "original-raw-receipts-missing" in n["flags"]
    cp_proofs.append({"tokenId": row["token_id"], "tx": row["purchase_tx"], "directDtf": row["direct_dtf_paid_raw"],
                      "directWeth": row["direct_weth_paid_raw"], "routedDtf": row["routed_dtf_received_by_detf_raw"]})
assert len(nfts) == len(weighted_proofs) + len(cp_proofs)
for coverage in candidate["coverage"]:
    asset = coverage["asset"]
    assert coverage["positionLocators"] == [loc for loc, r in rows.items() if loc.startswith("positions.csv#") and r["asset"].lower() == asset]
    assert coverage["holdingLocators"] == [loc for loc, r in rows.items() if loc.startswith("custody-inventory.csv#") and r["asset"].lower() == asset]
    assert coverage["provenanceLocators"] == [loc for loc, r in rows.items() if loc.startswith("evidence/transfers.csv#") and r["asset"].lower() == asset]
    assert coverage["purchaseKeys"] == [n["key"] for n in candidate["nfts"] if n["collection"] == asset]
    observed = bool(coverage["positionLocators"] or coverage["holdingLocators"] or coverage["purchaseKeys"])
    assert coverage["status"] == ("observed-unreviewed" if observed else "unobserved-not-proven-absent")
    assert coverage["priorDelivery"] == "unknown"
    if coverage["category"] in {"ETH", "WETH"}:
        assert coverage["use"] == "contribution-recovery-provenance-not-surrender"
for issue in candidate["unresolved"]:
    assert issue["code"] and issue["detail"]
    assert all(locator in rows for locator in issue["records"])
    for locator in issue["records"]:
        assert inventory[locator]["historicalFields"] == rows[locator]
assert len(candidate["independentRecipientObservations"]) == len(tables["account-ledger.csv"])
for observation in candidate["independentRecipientObservations"]:
    account = rows[observation["ledgerLocator"]]
    assert observation["recipient"] == account["account"]
    assert observation["product"] == account["product"]
    assert all(observation[k] is None for k in ("originalEconomicOrigin", "originalQ0", "originalEth", "originalDtf", "priorDeliveredCredit"))
    assert observation["linkedObservations"] == inventory[observation["ledgerLocator"]]["links"]
positions = tables["positions.csv"]
held = {r["position_id"]: r for r in tables["held-exclusions.csv"]}
assert len(held) == len(positions)
for position in positions:
    exclusion = held[position["position_id"]]
    assert exclusion["snapshot_account"] == position["account"]
    assert exclusion["asset"].lower() == position["asset"].lower()
    if position["product"] == "weighted":
        assert int(exclusion["held_exclusion_detf_raw"]) + int(exclusion["unresolved_snapshot_remainder_detf_raw"]) == int(position["detf_equivalent_raw"])
recoveries = tables["observed-recoveries.csv"]
for row in recoveries:
    event = events[f'{row["asset"].lower()}:{row["tx"]}:{row["log_index"]}']
    assert (event["amount_raw"], event["to"]) == (row["observed_amount_raw"], row["recipient"])
totals = {
    "weightedNominalNative9": str(sum(int(p["detf_equivalent_raw"]) for p in positions if p["product"] == "weighted")),
    "heldNative9": str(sum(int(p["held_exclusion_detf_raw"]) for p in held.values() if p["product"] == "weighted")),
    "remainderNative9": str(sum(int(p["unresolved_snapshot_remainder_detf_raw"]) for p in held.values() if p["product"] == "weighted")),
    "observedDtfNative18": str(sum(int(r["observed_amount_raw"]) for r in recoveries)),
}
proof = {
    "method": "Independent Python stdlib CSV/integer oracle; no producer imports or root observation oracle",
    "rawDeclarations": len(declarations), "uniqueDeclaredPaths": len(set(d["path"] for d in declarations)),
    "rawRows": len(rows), "quantityFields": quantity_count,
    "census": {name: len(records) for name, records in tables.items()},
    "weightedTransactions": len(purchase_transactions), "weighted": weighted_proofs, "earlierCp": cp_proofs,
    "coverage": candidate["coverage"], "totals": totals,
    "unresolvedClasses": dict(Counter(issue["code"] for issue in candidate["unresolved"])),
    "allUnresolved": candidate["unresolved"],
    "candidateBytes": len(candidate_path.read_bytes()), "candidateSha256": hashlib.sha256(candidate_path.read_bytes()).hexdigest(),
}
with output_path.open("x") as stream:
    json.dump(proof, stream, indent=2)
    stream.write("\n")
print(json.dumps({k: v for k, v in proof.items() if k not in {"allUnresolved", "weighted", "earlierCp", "coverage"}}))
