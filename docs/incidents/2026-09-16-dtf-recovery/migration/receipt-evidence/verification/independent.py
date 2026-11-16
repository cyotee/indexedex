# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
# How to run: python3 -B independent.py INPUT VERIFIER_ACTUAL PRODUCER_ACTUAL OWNED
"""Independent full raw-row and RPC oracle; no collector/reconciliation imports."""

import collections
import re
import sys
from pathlib import Path
from typing import Final

from raw import authenticate, canonical, identity, load, publish, uint, wire

root, actual, producer, owned = map(Path, sys.argv[1:])
topics = load(owned / "topics.json")
DTF: Final = "0xee5576fa1bcaa380e591d01245f406f3f384eb01"
WETH: Final = "0x0bd7d308f8e1639fab988df18a8011f41eacad73"
WN: Final = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e"
EN: Final = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391"
WD: Final = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7"
ED: Final = "0xaf0e1967c8f755c747615c5427108bc549ca1122"
SE: Final = "0xb7d4bb379d361ad442cddee53ea71a33957826a7"
LP: Final = "0x923877336b14662cfb5b3a60b14e7d716d54a888"
SY: Final = "0xb55604cf4dcdabb362078e106d20f98512391edf"
CLAIM: Final = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00"
ZERO: Final = "0x" + "0" * 40


def address(topic: str) -> str:
    """Decode only a properly padded indexed address."""
    assert re.fullmatch(r"0x0{24}[0-9a-f]{40}", topic)
    return "0x" + topic[-40:]


def words(data: str) -> list[str]:
    """Decode exact 32-byte event data words without floating point."""
    assert re.fullmatch(r"0x(?:[0-9a-f]{64})*", data)
    return [str(int(data[i:i + 64], 16)) for i in range(2, len(data), 64)]


def transfers(logs):
    """Derive ERC20/721 observations directly from all receipt logs."""
    decoded = []
    for log in logs:
        event = log["topics"]
        if not event or event[0] != topics["Transfer(address,address,uint256)"]:
            continue
        record = {"address": log["address"], "from": address(event[1]), "to": address(event[2]),
                  "logIndex": str(uint(log["logIndex"])), "amount": None, "tokenId": None}
        match len(event):
            case 3:
                values = words(log["data"])
                assert len(values) == 1
                record["amount"] = values[0]
            case 4:
                assert log["data"] == "0x"
                record["tokenId"] = str(int(event[3], 16))
            case _:
                raise AssertionError(("unsupported-transfer-layout", log))
        decoded.append(record)
    return decoded


declarations, input_observations, tables = authenticate(root)
references = []
for table, kind in [("evidence/weighted-bonds.csv", "weighted"), ("evidence/earlier-cp-bonds.csv", "earlier"),
                    ("conversions.csv", "claim")]:
    for row in tables[table]:
        if kind == "claim" and row["fields"]["kind"] != "legacy_weight_to_sy":
            continue
        references.append({**row, "kind": kind, "tx": row["fields"]["tx" if kind == "claim" else "purchase_tx"].lower()})
assert len({ref["locator"] for ref in references}) == len(references)
named = {ref["tx"] for ref in references}
assert all(re.fullmatch(r"0x[0-9a-f]{64}", tx) for tx in named)
assert len(references) == len(named) == 77
counts = dict(collections.Counter(ref["kind"] for ref in references))
assert counts == {"weighted": 43, "earlier": 16, "claim": 18}
lanes = []
for directory in [actual, producer]:
    captures, outcomes, rpc = wire(directory)
    archive, saved_refs = load(directory / "archive.json"), load(directory / "references.json")
    raw_refs = {ref["row"]["locator"]: ref for ref in saved_refs["refs"]}
    assert len(raw_refs) == len(references)
    assert {row["tx"] for row in saved_refs["requests"]} == named
    for request in saved_refs["requests"]:
        assert sorted(request["references"]) == sorted(ref["locator"] for ref in references if ref["tx"] == request["tx"])
    results = {result["tx"]: result for result in archive["results"]}
    assert len(results) == len(named) and set(results) == named
    reconciled = {record["locator"]: record for record in load(directory / "reconciliation.json")}
    assert set(reconciled) == {ref["locator"] for ref in references}
    canonical_rows, reviews, saved_matches = [], [], []
    for ref in sorted(references, key=lambda item: item["locator"]):
        observed = canonical(ref["tx"], rpc)
        tx, receipt = observed["transaction"], observed["receipt"]
        result, saved = results[ref["tx"]], reconciled[ref["locator"]]
        assert result["observed"] == observed and result["conflicts"] == []
        assert result["transactionObservation"] == tx and result["receiptObservation"] == receipt
        assert load(directory / (ref["tx"] + ".json")) == result
        expected_ids = [capture["id"] for capture in captures if
                        (capture["method"] in {"eth_getTransactionByHash", "eth_getTransactionReceipt"} and capture["params"] == [ref["tx"]])
                        or (capture["method"] == "eth_getBlockByHash" and capture["params"] == [tx["blockHash"], False])
                        or (capture["method"] == "eth_getBlockByNumber" and capture["params"] == [tx["blockNumber"], False])]
        assert sorted(result["requestIds"]) == sorted(expected_ids)
        assert result["references"] == [ref["locator"]]
        assert raw_refs[ref["locator"]]["row"]["fields"] == ref["fields"] == saved["historicalFields"]
        assert raw_refs[ref["locator"]]["tx"] == ref["tx"] == saved["tx"]
        context = {"from": tx["from"], "to": tx["to"], "value": str(uint(tx["value"])), "calldata": tx["input"],
                   "block": str(uint(tx["blockNumber"])), "transactionIndex": str(uint(tx["transactionIndex"]))}
        assert context == saved["transactionContext"]
        decoded, row, flags = transfers(receipt["logs"]), ref["fields"], []
        expected_transfers = [item for item in tables["evidence/transfers.csv"]
                              if item["fields"]["tx"].lower() == ref["tx"]
                              and (ref["kind"] != "claim" or (item["fields"]["asset"].lower() == SY
                                   and item["fields"]["to"].lower() == row["recipient"].lower()))]
        assert saved["savedTransferLocators"] == [item["locator"] for item in expected_transfers]
        assert raw_refs[ref["locator"]]["expectedTransfers"] == [
            {**item, "path": item["locator"].split("#")[0], "row": int(item["locator"].split("=")[1])}
            for item in expected_transfers]
        for item in expected_transfers:
            fields = item["fields"]
            found = [item for item in decoded if item["address"] == fields["asset"].lower() and item["logIndex"] == fields["log_index"]]
            assert len(found) == 1
            event = found[0]
            assert event["from"] == fields["from"].lower() and event["to"] == fields["to"].lower()
            assert (event["amount"] or "") == fields["amount_raw"] and (event["tokenId"] or "") == fields["token_id"]
            assert context["block"] == fields["block"] and context["transactionIndex"] == fields["transaction_index"]
            saved_matches.append({"locator": item["locator"], "observed": event})
        review = {"locator": ref["locator"], "kind": ref["kind"], "tx": ref["tx"], "rawFields": row, "context": context}
        if ref["kind"] != "claim":
            weighted = ref["kind"] == "weighted"
            collection, target = (WN, WD) if weighted else (EN, ED)
            recipient = row["purchase_recipient" if weighted else "owner"].lower()
            mints = [item for item in decoded if item["address"] == collection and item["from"] == ZERO]
            assert len(mints) == 1 and mints[0]["to"] == recipient and mints[0]["tokenId"] == row["token_id"]
            signature = "BondPurchased(uint256,address,uint256,uint256,uint256)" if weighted else "NewLock(uint256,address,uint256,uint256,uint256)"
            events = [item for item in receipt["logs"] if item["address"] == collection and item["topics"][0] == topics[signature]]
            assert len(events) == 1
            event, basis = events[0], row["original_principal_detf_raw" if weighted else "original_lp_shares_raw"]
            assert len(event["topics"]) == 3 and str(int(event["topics"][1], 16)) == row["token_id"]
            assert address(event["topics"][2]) == recipient and len(words(event["data"])) == 3
            assert words(event["data"])[0] == basis
            if weighted:
                assert context["block"] == row["purchase_block"]
                assert words(event["data"])[1:] == [row["start_timestamp"], row["duration_seconds"]]
            assets = []
            for asset, field in [(DTF, "direct_dtf_paid_raw"), (WETH, "direct_weth_paid_raw")]:
                incoming = [item for item in decoded if item["address"] == asset and item["to"] == target and item["amount"] is not None]
                direct = [item for item in incoming if item["from"] == recipient]
                routed = [item for item in incoming if item["from"] != recipient]
                direct_sum, routed_sum = str(sum(int(item["amount"]) for item in direct)), str(sum(int(item["amount"]) for item in routed))
                original = [item["fields"] for item in expected_transfers if item["fields"]["asset"].lower() == asset and item["fields"]["to"].lower() == target]
                expected_direct = str(sum(int(item["amount_raw"]) for item in original)) if weighted else row[field]
                assert direct_sum == expected_direct
                if not weighted and asset == DTF:
                    se_sum = str(sum(int(item["amount"]) for item in routed if item["from"] == SE))
                    assert se_sum == row["routed_dtf_received_by_detf_raw"]
                    if routed_sum != row["routed_dtf_received_by_detf_raw"]:
                        flags.append("routed-dtf")
                    assert all(item["from"] in {SE, LP} for item in routed)
                assets.append({"asset": asset, "observedDirect": direct_sum, "observedRouted": routed_sum, "direct": direct, "routed": routed})
            if tx["to"] != target or tx["from"] != recipient:
                flags.append("indirect-purchase-or-different-caller")
            for item in assets:
                item["attributableDirect"] = None if flags else item["observedDirect"]
            assert saved["assets"] == assets and saved["mints"] == mints
            review.update({"mint": mints[0], "event": event, "basis": basis, "basisUnit": "fixed-native9-principal" if weighted else "LP-accounting-shares-not-physical-LP",
                           "assets": assets})
        else:
            source_logs = [item for item in receipt["logs"] if item["address"] == CLAIM]
            sy_logs = [item for item in receipt["logs"] if item["address"] == SY]
            events = [item for item in source_logs if item["topics"][0] == topics["ClaimWithdrawn(address,uint256,uint256)"]]
            assert len(events) == 1 and len(events[0]["topics"]) == 2
            assert address(events[0]["topics"][1]) == row["recipient"].lower()
            assert words(events[0]["data"]) == [row["principal_raw"], row["output_raw"]]
            outputs = [item for item in decoded if item["address"] == SY and item["to"] == row["recipient"].lower() and item["amount"] == row["output_raw"]]
            assert len(outputs) == len(expected_transfers) == 1 and context["block"] == row["block"]
            direct = tx["to"] == CLAIM and tx["input"].startswith(topics["withdrawClaim(uint256)"][:10]) and len(tx["input"]) == 74 and uint(tx["value"]) == 0
            weight = str(int(tx["input"][10:], 16)) if direct else None
            if not direct or tx["from"] != row["recipient"].lower():
                flags.append("indirect-or-unexpected-claim-call")
            assert not direct or weight == row["principal_raw"]
            assert saved["sourceLogs"] == source_logs and saved["syLogs"] == sy_logs and saved["outputs"] == outputs
            assert saved["direct"] == direct and saved["decodedDirectWeight"] == weight
            review.update({"sourceLogs": source_logs, "syLogs": sy_logs, "output": outputs[0], "decodedDirectWeight": weight})
        assert set(saved["conflicts"]) == set(flags)
        review["flags"] = flags
        reviews.append(review)
        canonical_rows.append({"tx": ref["tx"], "block": context["block"], "index": context["transactionIndex"],
                               "blockHash": tx["blockHash"], "logCount": len(receipt["logs"]), "rawAgreement": True})
    assert archive["authenticated"] is True and archive["completeAssociations"] == len(named)
    assert archive["references"] == len(references) and archive["distinctTransactions"] == len(named)
    assert archive["referenceConflicts"] == sum(bool(row["flags"]) for row in reviews)
    lanes.append({"directory": str(directory), "archive": identity(directory / "archive.json"), "captures": outcomes,
                  "canonical": canonical_rows, "reviews": reviews, "savedTransfers": saved_matches,
                  "rpcFailures": [item for item in outcomes if item["outcome"] != "success"]})
assert lanes[0]["reviews"] == lanes[1]["reviews"] and lanes[0]["canonical"] == lanes[1]["canonical"]
assert not lanes[0]["rpcFailures"] and not lanes[1]["rpcFailures"]
proof = {"status": "CONFIRMED-BOUNDED-RAW-OBSERVATIONS", "inputDeclarations": input_observations,
         "inputManifest": identity(root / "manifest.json"), "counts": counts, "references": references, "lanes": lanes,
         "scope": "No net contribution, eligibility, current control, complete W0/Q0/history/prior credit or operational acceptance"}
publish(owned / "independent-proof.json", proof)
print({"references": len(references), "counts": counts, "lanes": len(lanes), "canonicalPerLane": len(named),
       "httpPerLane": [len(lane["captures"]) for lane in lanes],
       "logsPerLane": [sum(item["logCount"] for item in lane["canonical"]) for lane in lanes],
       "flaggedPerLane": [sum(bool(item["flags"]) for item in lane["reviews"]) for lane in lanes],
       "savedTransferMatchesPerLane": [len(lane["savedTransfers"]) for lane in lanes]})
