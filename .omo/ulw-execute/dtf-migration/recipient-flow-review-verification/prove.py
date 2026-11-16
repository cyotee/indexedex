"""Offline derivation verifier. Read pinned inputs; emit deterministic JSON only."""
from collections import Counter, defaultdict
from hashlib import sha256
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve().parent
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
ASSETS = (
    ("0xee5576fa1bcaa380e591d01245f406f3f384eb01", "DTF"),
    ("0x0bd7d308f8e1639fab988df18a8011f41eacad73", "WETH"),
)
identities = json.loads((HERE / "inputs.json").read_bytes())
documents = {}
identity_checks = []
for name, identity in identities.items():
    body = Path(identity["path"]).read_bytes()
    actual = {"bytes": len(body), "sha256": sha256(body).hexdigest()}
    if actual != {key: identity[key] for key in actual}:
        sys.exit(f"Input identity failure: {name}: {actual}")
    identity_checks.append({"name": name, **identity, "verified": True})
    documents[name] = body.decode() if name.startswith("report") or name == "plan" else json.loads(body)

worksheet = documents["worksheet"]
checks = []
failures = []


def equal(location: str, actual, expected) -> None:
    """Retain every assertion and exact mismatched value, without early success."""
    passed = actual == expected
    checks.append({"location": location, "pass": passed})
    if not passed:
        failures.append({"location": location, "actual": actual, "expected": expected})


section21 = documents["plan"].split("### 2.1 ", 1)[1].split("\n## 3.", 1)[0]
section5 = documents["plan"].split("## 5. ", 1)[1].split("\n## 6.", 1)[0]
for asset, label in ASSETS:
    plan_row = next(line for line in section21.splitlines() if f"| {label} |" in line or
                    (label == "DTF" and "| Contribution/recovery DTF |" in line))
    equal(f"plan/2.1/{label}/identity", asset in plan_row.lower(), True)
    equal(f"plan/2.1/{label}/units", "18-decimal asset" in plan_row, True)
equal("worksheet/status", worksheet["status"], "NON-ISSUABLE-REVIEW")
equal("worksheet/version", worksheet["version"], "migration-observed-recipient-flow-review-v1")
for name in ("archive28", "recon28", "archive30", "recon30"):
    equal(f"worksheet/sourceIdentities/{name}", worksheet["sourceIdentities"][name], identities[name]["sha256"])
equal("worksheet/sourceIdentities/keys", sorted(worksheet["sourceIdentities"]), ["archive28", "archive30", "recon28", "recon30"])

transactions = {}
overlaps = []
archive_locations = defaultdict(list)
for lane in ("28", "30"):
    archive = documents["archive" + lane]
    reconciliation = documents["recon" + lane]
    equal(f"archive{lane}/chainId", archive["chainId"], "4663")
    equal(f"archive{lane}/authenticated", archive["authenticated"], True)
    equal(f"archive{lane}/reconciliation/sha256", archive["reconciliation"]["sha256"], identities["recon" + lane]["sha256"])
    equal(f"archive{lane}/reconciliation/bytes", archive["reconciliation"]["bytes"], identities["recon" + lane]["bytes"])
    equal(f"archive{lane}/uniqueTransactions", len({r["tx"] for r in archive["results"]}), len(archive["results"]))
    for index, result in enumerate(archive["results"]):
        tx = result["tx"]
        archive_locations[tx].append({"archive": "archive" + lane, "resultIndex": index})
        equal(f"archive{lane}/results/{index}/references",
              sorted(result["references"]), sorted(r["locator"] for r in reconciliation if r["tx"] == tx))
        if tx in transactions:
            old = transactions[tx]
            comparisons = {key: old[key] == result[key] for key in
                           ("observed", "receiptObservation", "transactionObservation")}
            overlaps.append({"tx": tx, "equal": comparisons})
            for key, passed in comparisons.items():
                equal(f"overlap/{tx}/{key}", passed, True)
        else:
            transactions[tx] = result
    equal(f"archive{lane}/reconciliationTransactions",
          sorted({r["tx"] for r in reconciliation}), sorted(r["tx"] for r in archive["results"]))

references = {}
source_rows = []
for lane in ("28", "30"):
    for index, row in enumerate(documents["recon" + lane]):
        fields = row["historicalFields"]
        # Original recorded recipient, not caller, current owner, or every transfer participant.
        recipient = fields.get("purchase_recipient", fields.get("owner", fields.get("recipient"))).lower()
        tx, locator = row["tx"], row["locator"]
        equal(f"recon{lane}/{index}/historicalTransaction", fields.get("purchase_tx", fields.get("tx")), tx)
        if lane == "28" and row["kind"] == "nft":
            equal(f"recon{lane}/{index}/mintRecipient", sorted({m["to"] for m in row["mints"]}), [recipient])
        if lane == "28" and row["kind"] == "claim":
            equal(f"recon{lane}/{index}/claimRecipient", sorted({c["user"] for c in row["claims"]}), [recipient])
        if lane == "30":
            equal(f"recon{lane}/{index}/expectedRecipient", row["expectedOutput"]["recipient"], recipient)
        origin = {"archive": "recon" + lane, "index": index}
        source_rows.append({**origin, "locator": locator, "tx": tx, "observedRecipient": recipient,
                            "flags": row["conflicts"], "qualifications": row["qualifications"]})
        if locator not in references:
            references[locator] = {"locator": locator, "tx": tx, "observedRecipient": recipient,
                                   "flags": [], "qualifications": [], "sources": []}
        joined = references[locator]
        equal(f"join/{locator}/tx", joined["tx"], tx)
        equal(f"join/{locator}/observedRecipient", joined["observedRecipient"], recipient)
        joined["flags"] = sorted(set(joined["flags"]) | set(row["conflicts"]))
        joined["qualifications"] = sorted(set(joined["qualifications"]) | set(row["qualifications"]))
        joined["sources"].append(origin)

expected_references = sorted(references.values(), key=lambda r: r["locator"])
actual_references = {r["locator"]: (index, r) for index, r in enumerate(worksheet["references"])}
equal("references/uniqueLocators", len(actual_references), len(worksheet["references"]))
equal("references/population", sorted(actual_references), sorted(references))
for ref in expected_references:
    if ref["locator"] in actual_references:
        index, actual = actual_references[ref["locator"]]
        equal(f"references/{index}/keys", sorted(actual), sorted(ref))
        for key, expected in ref.items():
            equal(f"references/{index}/{key}", actual.get(key), expected)

groups = defaultdict(list)
transaction_refs = defaultdict(list)
for ref in expected_references:
    groups[(ref["tx"], ref["observedRecipient"])].append(ref["locator"])
    transaction_refs[ref["tx"]].append(ref["locator"])

# Decode every fixed-asset Transfer once, directly from receipt bytes.
events_by_tx = defaultdict(list)
event_census = []
for tx, result in sorted(transactions.items()):
    recipients = {recipient for transaction, recipient in groups if transaction == tx}
    counts = Counter()
    for log_offset, log in enumerate(result["receiptObservation"]["logs"]):
        counts["allReceiptLogs"] += 1
        if log["address"].lower() not in {a for a, _ in ASSETS} or log["topics"][0] != TRANSFER:
            counts["outsideFixedAssetTransferScope"] += 1
            continue
        equal(f"event/{tx}/{log_offset}/topicsLength", len(log["topics"]), 3)
        equal(f"event/{tx}/{log_offset}/dataLength", len(log["data"]), 66)
        for topic in log["topics"][1:]:
            equal(f"event/{tx}/{log_offset}/{topic}/addressPadding", topic[:26], "0x" + "0" * 24)
        event = {"logIndex": str(int(log["logIndex"], 16)),
                 "from": "0x" + log["topics"][1][-40:].lower(),
                 "to": "0x" + log["topics"][2][-40:].lower(),
                 "amountRaw": str(int(log["data"], 16))}
        affected = sorted(recipients & {event["from"], event["to"]})
        events_by_tx[tx].append({"asset": log["address"].lower(), "event": event,
                                "affectedRecipients": affected, "receiptLogOffset": log_offset})
        counts["fixedAssetTransferEvents"] += 1
        counts["relevantFixedAssetTransferEvents" if affected else "excludedOtherEndpoints"] += 1
    event_census.append({"tx": tx, "archives": archive_locations[tx], "counts": dict(counts),
                         "events": events_by_tx[tx]})

expected_flows = []
for (tx, recipient), locators in sorted(groups.items()):
    outer = transactions[tx]["transactionObservation"]
    flows = []
    for asset, label in ASSETS:
        events = [item["event"] for item in events_by_tx[tx]
                  if item["asset"] == asset and recipient in item["affectedRecipients"]]
        incoming = sum(int(event["amountRaw"]) for event in events if event["to"] == recipient)
        outgoing = sum(int(event["amountRaw"]) for event in events if event["from"] == recipient)
        flows.append({"asset": asset, "label": label, "decimals": 18, "matchingTransferEvents": events,
                      "sumEmittedIncomingRaw": str(incoming), "sumEmittedOutgoingRaw": str(outgoing),
                      "emittedIncomingMinusOutgoingRaw": str(incoming - outgoing),
                      "interpretation": "event sums only; zero is not zero economic contribution"})
    expected_flows.append({"tx": tx, "observedRecipient": recipient, "references": sorted(locators),
                           "allTransactionReferences": sorted(transaction_refs[tx]),
                           "outerFrom": outer["from"], "outerTo": outer["to"],
                           "outerValueWei": str(int(outer["value"], 16)),
                           "outerValueMeaning": "transaction-level value; not allocated, netted against refunds, or attributed to each recipient",
                           "flows": flows, "originalContribution": "unknown", "compensationDeduction": "unknown"})

actual_flows = {(r["tx"], r["observedRecipient"]): (i, r) for i, r in enumerate(worksheet["recipientFlows"])}
equal("recipientFlows/uniqueKeys", len(actual_flows), len(worksheet["recipientFlows"]))
equal("recipientFlows/population", sorted(actual_flows), sorted(groups))
for expected in expected_flows:
    key = (expected["tx"], expected["observedRecipient"])
    if key in actual_flows:
        index, actual = actual_flows[key]
        equal(f"recipientFlows/{index}/keys", sorted(actual), sorted(expected))
        for field, value in expected.items():
            if field != "flows":
                # This is a membership list; phase encounter order has no meaning.
                observed = sorted(actual[field]) if field == "allTransactionReferences" else actual.get(field)
                equal(f"recipientFlows/{index}/{field}", observed, value)
        equal(f"recipientFlows/{index}/flows/count", len(actual["flows"]), len(expected["flows"]))
        for asset_index, flow in enumerate(expected["flows"]):
            if asset_index < len(actual["flows"]):
                found = actual["flows"][asset_index]
                equal(f"recipientFlows/{index}/flows/{asset_index}/keys", sorted(found), sorted(flow))
                for field, value in flow.items():
                    equal(f"recipientFlows/{index}/flows/{asset_index}/{field}", found.get(field), value)

counts = {"transactions": len(transactions), "overlappingTransactions": len(overlaps),
          "references": len(references), "flaggedReferences": sum(bool(r["flags"]) for r in expected_references),
          "recipientTransactionRows": len(groups)}
equal("derived/userRequiredCounts", counts, {"transactions": 376, "overlappingTransactions": 20,
      "references": 378, "flaggedReferences": 20, "recipientTransactionRows": 378})
equal("worksheet/counts", worksheet["counts"], counts)
shared = [{"tx": tx, "references": refs,
           "contexts": [r for r in expected_flows if r["tx"] == tx]}
          for tx, refs in sorted(transaction_refs.items()) if len(refs) > 1]
equal("sharedTransactions/count", len(shared), 2)
for item in shared:
    equal(f"shared/{item['tx']}/distinctRecipients", len(item["contexts"]), 2)
    equal(f"shared/{item['tx']}/sourceKinds",
          sorted("nft" if r.startswith("evidence/") else "conversion" for r in item["references"]),
          ["conversion", "nft"])
flagged = [r for r in expected_references if r["flags"]]
equal("indirectClaim/preserved", references["conversions.csv#row=21"]["flags"], ["indirect-or-unexpected-claim-call"])
equal("worksheet/topLevelKeys", sorted(worksheet), sorted(["version", "status", "sourceIdentities", "counts", "meaning", "references", "recipientFlows"]))

statistics = {}
for asset, label in ASSETS:
    asset_flows = [f for r in expected_flows for f in r["flows"] if f["asset"] == asset]
    statistics[label] = {
        "asset": asset, "decimals": 18,
        "eventAppearances": sum(len(f["matchingTransferEvents"]) for f in asset_flows),
        "selfTransferAppearances": sum(e["from"] == e["to"] for f in asset_flows for e in f["matchingTransferEvents"]),
        "zeroEventRows": sum(not f["matchingTransferEvents"] for f in asset_flows),
        "negativeNetRows": sum(int(f["emittedIncomingMinusOutgoingRaw"]) < 0 for f in asset_flows),
        "zeroNetRows": sum(int(f["emittedIncomingMinusOutgoingRaw"]) == 0 for f in asset_flows),
    }
proof = {"verdict": "needs-fix" if failures else "confirmed",
         "scope": "offline join/observed-recipient event derivation only; prior canonical validation reused, not replayed",
         "inputIdentities": identity_checks,
         "planSections": {"2.1": section21, "5": section5},
         "counts": counts, "statistics": statistics, "checks": checks, "failures": failures,
         "sourceRows": source_rows, "references": expected_references, "overlaps": overlaps,
         "eventCensus": event_census, "recipientFlows": expected_flows,
         "flaggedReferences": flagged, "sharedTransactions": shared,
         "unestablished": ["current custody", "original E0/D0", "deduction/C0", "eligibility",
                           "original-wallet authority", "internal refunds, wrapping, fees and multi-action allocation"]}
print(json.dumps(proof, indent=2, sort_keys=True))
sys.exit(1 if failures else 0)
