#!/usr/bin/env python3
"""Allowlist and ABI comparison for the WeirVaults source import. Stdlib only."""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def fail(message):
    print(message, file=sys.stderr)
    return 1


def load_json(path):
    with Path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def frozen_text(root, name):
    path = Path(root) / name
    data = path.read_bytes()
    if b"\r" in data:
        raise SystemExit(f"frozen file has CR: {path}")
    return data.decode("utf-8")


def apply_allowlist(text, file_key, manifest):
    rows = [row for row in manifest["rewrites"] if row["file"] == file_key]
    rows.sort(key=lambda row: len(row["frozen"]), reverse=True)
    for row in rows:
        count = text.count(row["frozen"])
        if count != row["count"]:
            raise SystemExit(
                f"{file_key} specifier {row['frozen']!r} count {count} != {row['count']}"
            )
        text = text.replace(row["frozen"], row["selected"])
    added = manifest.get("addedImport")
    if added and added["file"] == file_key:
        anchor = added["after"] + "\n"
        if text.count(anchor) != 1:
            raise SystemExit("added-import anchor missing")
        text = text.replace(anchor, anchor + added["line"] + "\n", 1)
    for row in manifest["qualifications"]:
        if row["file"] != file_key:
            continue
        count = text.count(row["frozen"])
        if count != row["count"]:
            raise SystemExit(
                f"{file_key} qualification {row['frozen']!r} count {count} != {row['count']}"
            )
        text = text.replace(row["frozen"], row["selected"])
    return apply_wi06(text, file_key, manifest)


def apply_wi06(text, file_key, manifest):
    for row in manifest.get("wi06", []):
        if row["file"] != file_key:
            continue
        count = text.count(row["old"])
        if count != 1:
            raise SystemExit(f"WI-06 hunk count {count} in {file_key}")
        text = text.replace(row["old"], row["new"], 1)
    return text


def source_mode(args):
    manifest = load_json(args.manifest)
    pairs = {
        "W": (Path(args.frozen) / "src/WeirVaults.sol.txt", Path(args.weir)),
        "B": (Path(args.frozen) / "src/base/WeirBase.sol.txt", Path(args.base)),
        "L": (Path(args.frozen) / "src/libraries/LiquidityAmounts.sol.txt", Path(args.library)),
    }
    for key, (frozen_path, produced_path) in pairs.items():
        frozen = frozen_text(frozen_path.parent, frozen_path.name) if False else frozen_path.read_text(encoding="utf-8")
        if "\r" in frozen:
            return fail(f"CR in {frozen_path}")
        expected = apply_allowlist(frozen, key, manifest)
        actual = produced_path.read_text(encoding="utf-8")
        if actual != expected:
            return fail(f"unlisted hunk in {produced_path}")
    print("source fidelity: pass")
    return 0


def canonicalize_internal(value, qualifications):
    if isinstance(value, str):
        for old in qualifications:
            value = value.replace(old, old.split(".")[-1])
        return value
    if isinstance(value, list):
        return [canonicalize_internal(item, qualifications) for item in value]
    if isinstance(value, dict):
        return {key: canonicalize_internal(item, qualifications) for key, item in value.items()}
    return value


def sort_keys(value):
    if isinstance(value, list):
        return [sort_keys(item) for item in value]
    if isinstance(value, dict):
        return {key: sort_keys(value[key]) for key in sorted(value)}
    return value


def abi_signature(entry):
    copied = json.loads(json.dumps(entry))

    def strip(value):
        if isinstance(value, list):
            for item in value:
                strip(item)
        elif isinstance(value, dict):
            value.pop("internalType", None)
            for item in value.values():
                strip(item)

    strip(copied)
    return json.dumps(sort_keys(copied), sort_keys=True)


def abi_mode(args):
    artifact_path = Path(args.abi)
    if not artifact_path.is_file():
        return fail(f"missing artifact {artifact_path}")
    artifact = load_json(artifact_path)
    baseline = load_json(args.abi_baseline)
    transform_path = Path("contracts/protocols/strategy/weir/evidence/import-transform.json")
    qualifications = []
    expected_storage = []
    propagated = []
    if transform_path.is_file():
        transform = load_json(transform_path)
        qualifications = transform.get("internalTypeQualifications", [])
        expected_storage = transform.get("expectedStorage", [])
        expected_vault = transform.get("expectedVaultMembers", [])
        propagated = transform.get("compilerPropagatedErrors", [])
    got = artifact["abi"]
    want = baseline
    got_by_sig = {abi_signature(entry): entry for entry in got}
    missing = [entry for entry in want if abi_signature(entry) not in got_by_sig]
    if missing:
        return fail("baseline ABI entries missing: " + json.dumps(missing))
    extra = []
    for entry in got:
        if abi_signature(entry) not in {abi_signature(item) for item in want}:
            extra.append(entry)
            if entry.get("type") != "error":
                return fail("unexpected extra ABI entry: " + json.dumps(entry))
            name = entry.get("name")
            if name not in propagated:
                return fail("unexpected extra error: " + json.dumps(entry))
    for left in want:
        right = got_by_sig[abi_signature(left)]
        if sort_keys(canonicalize_internal(left, qualifications)) != sort_keys(canonicalize_internal(right, qualifications)):
            return fail("internalType mismatch for " + left.get("name", left.get("type")))
    listed_errors = [entry for entry in want if entry.get("type") == "error"]
    if len(listed_errors) != 18:
        return fail(f"baseline does not list 18 errors: {len(listed_errors)}")
    counts = {}
    for entry in want:
        counts[entry["type"]] = counts.get(entry["type"], 0) + 1
    if counts.get("function") != 27 or counts.get("event") != 11 or counts.get("constructor") != 1 or counts.get("receive") != 1:
        return fail(f"baseline inventory counts {counts}")
    layout = subprocess.run(
        ["forge", "inspect", "WeirVaults", "storageLayout", "--json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if layout.returncode != 0:
        return fail(layout.stderr or "forge inspect storageLayout failed")
    storage = json.loads(layout.stdout)
    compared = []
    for expected in expected_storage:
        match = None
        for item in storage.get("storage", []):
            if item.get("label") == expected["label"].split(".")[-1] or item.get("label") == expected["label"]:
                match = item
                break
        compared.append({"expected": expected, "compiler": match})
        if match is None:
            return fail(f"storage label missing: {expected['label']}")
        if int(match["slot"]) != expected["slot"] or int(match["offset"]) != expected["offset"]:
            return fail(f"storage mismatch for {expected['label']}: {match}")
    vault_type = None
    for info in storage.get("types", {}).values():
        if info.get("label") == "struct WeirVaults.Vault":
            vault_type = info
            break
    if expected_vault:
        if vault_type is None:
            return fail("compiler storage layout has no WeirVaults.Vault")
        members = {item["label"]: item for item in vault_type.get("members", [])}
        for expected in expected_vault:
            match = members.get(expected["label"])
            compared.append({"expected": expected, "compiler": match})
            if match is None or int(match["slot"]) != expected["slot"] or int(match["offset"]) != expected["offset"]:
                return fail(f"vault member mismatch for {expected['label']}: {match}")
    if any(item.get("label") == "poolManager" for item in storage.get("storage", [])):
        return fail("immutable manager was emitted as a storage slot")
    layout_out = {
        "compiler": storage,
        "expected": expected_storage,
        "expectedVaultMembers": expected_vault,
        "compared": compared,
        "immutableManagerIsNotASlot": True,
    }
    Path(args.layout_out).write_text(json.dumps(layout_out, indent=2) + "\n", encoding="utf-8")
    sources = artifact.get("metadata", {}).get("settings", {}).get("compilationTarget", {})
    metadata_sources = list(artifact.get("metadata", {}).get("sources", {}).keys()) if isinstance(artifact.get("metadata"), dict) else []
    raw = artifact.get("rawMetadata")
    if isinstance(raw, str):
        try:
            raw_obj = json.loads(raw)
            metadata_sources = list(raw_obj.get("sources", {}).keys())
        except json.JSONDecodeError:
            pass
    production = [item for item in metadata_sources if not item.startswith("test/") and "/test/" not in item]
    test_sources = [item for item in metadata_sources if item.startswith("test/") or "/test/" in item]
    graph = {
        "production": sorted(production),
        "test": sorted(test_sources),
        "compilationTarget": sources,
        "note": "Test source set is empty until a test artifact is compiled. WP-09 records the test graph from compiled test metadata.",
        "compilerPropagatedErrors": extra,
        "listedErrorCount": 18,
    }
    Path(args.graph_out).write_text(json.dumps(graph, indent=2) + "\n", encoding="utf-8")
    print("abi fidelity: pass")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=("source", "abi"))
    parser.add_argument("--frozen")
    parser.add_argument("--weir")
    parser.add_argument("--base")
    parser.add_argument("--library")
    parser.add_argument("--manifest")
    parser.add_argument("--abi")
    parser.add_argument("--abi-baseline")
    parser.add_argument("--layout-out")
    parser.add_argument("--graph-out")
    args = parser.parse_args()
    if args.mode == "source":
        missing = [name for name in ("frozen", "weir", "base", "library", "manifest") if not getattr(args, name)]
        if missing:
            return fail("source mode missing " + ", ".join(missing))
        return source_mode(args)
    missing = [name for name in ("abi", "abi_baseline", "layout_out", "graph_out") if not getattr(args, name)]
    if missing:
        return fail("abi mode missing " + ", ".join(missing))
    return abi_mode(args)


if __name__ == "__main__":
    sys.exit(main())
