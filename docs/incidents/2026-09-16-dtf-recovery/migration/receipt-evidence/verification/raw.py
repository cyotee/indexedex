# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
# How to run: imported by independent.py; no network and no producer imports.
"""Independent raw entity, canonical association, and input authentication."""

import csv
import hashlib
import json
import re
from pathlib import Path
from typing import Final

ANCHOR: Final = 108944663
ANCHOR_HASH: Final = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733"
METHODS: Final = {
    "eth_chainId", "eth_getBlockByNumber", "eth_getBlockByHash",
    "eth_getTransactionByHash", "eth_getTransactionReceipt",
}


def load(path: Path):
    """Read a complete UTF-8 JSON body, not a tool-rendered excerpt."""
    return json.loads(path.read_bytes())


def identity(path: Path):
    """Bind exact raw bytes."""
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def publish(path: Path, value) -> None:
    """Preserve new independent machine output exclusively."""
    with path.open("x", encoding="utf8") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def uint(value: str) -> int:
    """Accept canonical uint256 JSON-RPC quantities only."""
    assert re.fullmatch(r"0x(?:0|[1-9a-f][0-9a-f]*)", value), value
    parsed = int(value, 16)
    assert parsed < 2**256
    return parsed


def authenticate(root: Path):
    """Authenticate sources first and every declaration before decoding CSV."""
    manifest = load(root / "manifest.json")
    source_identity = identity(root / "sources.json")
    assert source_identity == manifest["files"]["sources.json"]
    sources = load(root / "sources.json")
    declarations = [
        {"declaration": "manifest", "path": path, **binding}
        for path, binding in manifest["files"].items()
    ] + [{"declaration": entry["id"], **entry} for entry in sources["sources"]]
    assert len({entry["id"] for entry in sources["sources"]}) == len(sources["sources"])
    observations = []
    for entry in declarations:
        path = root / entry["path"]
        assert path.is_file() and not path.is_symlink()
        observed = identity(path)
        assert all(observed[key] == entry[key] for key in observed), entry["path"]
        observations.append({**entry, "observed": observed})
    cutoff = sources["evidenceCutoff"]
    assert sources["chainId"] == 4663 and cutoff["block"] == ANCHOR and cutoff["hash"] == ANCHOR_HASH
    paths = {entry["path"] for entry in declarations}
    tables = {}
    for path in sorted(paths):
        if path.endswith(".csv"):
            with (root / path).open(newline="", encoding="utf8") as handle:
                reader = csv.DictReader(handle, strict=True)
                assert reader.fieldnames and len(set(reader.fieldnames)) == len(reader.fieldnames)
                records = []
                for row_number, row in enumerate(reader, 2):
                    assert None not in row and None not in row.values()
                    records.append({"locator": f"{path}#row={row_number}", "fields": row})
                tables[path] = records
    return declarations, observations, tables


def wire(directory: Path):
    """Reparse every raw request and response, with manifest binding."""
    captures = load(directory / "http-manifest.json")
    outcomes, rpc = [], {}
    expected_files = set()
    for expected_id, capture in enumerate(captures, 1):
        assert capture["id"] == expected_id
        for key in ("request", "response"):
            item = capture[key]
            if item is not None:
                expected_files.add(item["path"])
                assert identity(directory / "http" / item["path"]) == {
                    name: item[name] for name in ("bytes", "sha256")
                }
        request = load(directory / "http" / capture["request"]["path"])
        assert request == {"jsonrpc": "2.0", "id": expected_id,
                           "method": capture["method"], "params": capture["params"]}
        assert capture["method"] in METHODS
        response_identity = capture["response"]
        outcome = {"id": expected_id, "method": capture["method"], "params": capture["params"],
                   "outcome": capture["outcome"], "request": capture["request"],
                   "response": response_identity, "http": capture["http"]}
        if response_identity is not None:
            response = load(directory / "http" / response_identity["path"])
            outcome["envelope"] = response
        outcomes.append(outcome)
        if capture["outcome"] != "success":
            continue
        assert response_identity["raw"] is True
        assert response_identity["bytes"] == response_identity["receivedBytes"]
        assert capture["http"]["status"] == 200
        assert response["jsonrpc"] == "2.0" and type(response["id"]) is int
        assert response["id"] == expected_id and "error" not in response
        assert response["result"] is not None
        key = (request["method"], tuple(request["params"]))
        assert key not in rpc, key
        rpc[key] = response["result"]
    assert {path.name for path in (directory / "http").iterdir()} == expected_files
    assert uint(rpc[("eth_chainId", ())]) == 4663
    anchor = rpc[("eth_getBlockByNumber", (hex(ANCHOR), False))]
    assert uint(anchor["number"]) == ANCHOR and anchor["hash"] == ANCHOR_HASH
    return captures, outcomes, rpc


def canonical(tx_hash: str, rpc):
    """Independently compare full headers/membership and every receipt log."""
    tx = rpc[("eth_getTransactionByHash", (tx_hash,))]
    receipt = rpc[("eth_getTransactionReceipt", (tx_hash,))]
    assert tx["hash"] == receipt["transactionHash"] == tx_hash
    for key in ("blockHash", "blockNumber", "transactionIndex", "from", "to"):
        assert tx[key] == receipt[key], (tx_hash, key)
    height, index = uint(tx["blockNumber"]), uint(tx["transactionIndex"])
    assert height <= ANCHOR and receipt["status"] == "0x1"
    for key in ("value", "nonce"):
        uint(tx[key])
    assert re.fullmatch(r"0x(?:[0-9a-f]{2})*", tx["input"])
    assert re.fullmatch(r"0x[0-9a-f]{40}", tx["from"])
    assert tx["to"] is None or re.fullmatch(r"0x[0-9a-f]{40}", tx["to"])
    by_hash = rpc[("eth_getBlockByHash", (tx["blockHash"], False))]
    by_number = rpc[("eth_getBlockByNumber", (tx["blockNumber"], False))]
    assert by_hash == by_number, ("full-header-disagreement", tx_hash)
    assert by_hash["hash"] == tx["blockHash"] and uint(by_hash["number"]) == height
    assert re.fullmatch(r"0x[0-9a-f]{64}", by_hash["parentHash"])
    uint(by_hash["timestamp"])
    members = by_hash["transactions"]
    assert len(set(members)) == len(members) and members[index] == tx_hash
    assert all(re.fullmatch(r"0x[0-9a-f]{64}", member) for member in members)
    previous = -1
    for log in receipt["logs"]:
        assert log["transactionHash"] == tx_hash and log["removed"] is False
        for key in ("blockHash", "blockNumber", "transactionIndex"):
            assert log[key] == tx[key], (tx_hash, log["logIndex"], key)
        position = uint(log["logIndex"])
        assert position > previous
        previous = position
        assert re.fullmatch(r"0x[0-9a-f]{40}", log["address"])
        assert re.fullmatch(r"0x(?:[0-9a-f]{2})*", log["data"])
        assert all(re.fullmatch(r"0x[0-9a-f]{64}", topic) for topic in log["topics"])
    return {"transaction": tx, "receipt": receipt, "byHash": by_hash, "byNumber": by_number}
