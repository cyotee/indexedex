#!/usr/bin/env python3
"""Read-only EIP-170 checks for FullSpread consumers and their linked libraries."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "contracts/hooks/uniswap/v4/standardExchange"
FAMILIES = ("single", "constantProduct/single", "dual", "weighted", "orbital",
            "stable/quad/curve", "stable/quad/balancer")


def bytecode_dependencies(bytecode):
    """Validate link slots without rejecting hex addresses or library self-addresses."""
    code = bytecode["object"].removeprefix("0x")
    if not code or len(code) % 2:
        raise ValueError("empty or odd-length bytecode")
    dependencies, slots = set(), []
    for source, libraries in bytecode.get("linkReferences", {}).items():
        for name, references in libraries.items():
            if not references:
                raise ValueError(f"empty link references for {source}:{name}")
            dependencies.add((source, name))
            for reference in references:
                start, length = reference["start"], reference["length"]
                if (type(start) is not int or type(length) is not int
                        or start < 0 or length != 20 or (start + length) * 2 > len(code)):
                    raise ValueError(f"invalid link range for {source}:{name}")
                slots.append((start * 2, (start + length) * 2))
    end = 0
    for start, stop in sorted(slots):
        if start < end:
            raise ValueError("overlapping link references")
        if not re.fullmatch(r"[0-9a-fA-F]*", code[end:start]):
            raise ValueError("non-hex bytecode outside declared links")
        slot = code[start:stop]
        if not re.fullmatch(r"(?:[0-9a-fA-F]{40}|__\$[0-9a-fA-F]{34}\$__)", slot):
            raise ValueError("invalid link placeholder or address")
        end = stop
    if not re.fullmatch(r"[0-9a-fA-F]*", code[end:]):
        raise ValueError("non-hex bytecode outside declared links")
    return dependencies


def inspect_artifact(root, source, name):
    artifact = root / "out" / Path(source).name / f"{name}.json"
    if not artifact.is_file():
        raise ValueError(f"missing: {artifact.relative_to(root)}")
    data = json.loads(artifact.read_text())
    metadata = data.get("metadata")
    if not isinstance(metadata, dict):
        metadata = json.loads(data.get("rawMetadata", "{}"))
    if metadata.get("settings", {}).get("compilationTarget") != {source: name}:
        raise ValueError(f"source identity mismatch: {artifact.relative_to(root)}; expected {source}:{name}")
    dependencies = set()
    for field in ("bytecode", "deployedBytecode"):
        dependencies.update(bytecode_dependencies(data[field]))
    runtime = data["deployedBytecode"]["object"].removeprefix("0x")
    size = len(runtime) // 2
    if size > 24_576:
        raise ValueError(f"{name}: invalid runtime size {size}")
    return size, dependencies


def check_artifacts(root, consumers):
    """Visit the actual creation/runtime link closure once, including cycles."""
    checked = {"Consumer": 0, "Linked library": 0}
    failed = {"Consumer": [], "Linked library": []}
    pending = [(source, name, "Consumer") for source, name in consumers]
    seen = set()
    for source, name, kind in pending:
        if (source, name) in seen:
            continue
        seen.add((source, name))
        try:
            size, dependencies = inspect_artifact(root, source, name)
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
            failed[kind].append(f"{source}:{name}: {error}")
            continue
        checked[kind] += 1
        if kind == "Consumer":
            print(f"{name}: {size} bytes")
        else:
            print(f"Linked library {name}: {size} bytes; source: {source}; "
                  f"artifact: out/{Path(source).name}/{name}.json")
        pending.extend((path, library, "Linked library") for path, library in sorted(dependencies))
    for failures in failed.values():
        for failure in failures:
            print(f"FAIL {failure}")
    print(f"Consumer runtimes: {checked['Consumer']} checked, {len(failed['Consumer'])} failures")
    print(f"Linked library runtimes: {checked['Linked library']} checked, "
          f"{len(failed['Linked library'])} failures")
    return 1 if any(failed.values()) else 0


def main():
    consumers = []
    for family in FAMILIES:
        directory = BASE / family
        sources = sorted((directory / "facets").glob("*Facet.sol"))
        sources += sorted(directory.glob("*DFPkg.sol"))
        for source in sources:
            name = source.stem
            if re.search(r"\babstract\s+contract\s+" + re.escape(name) + r"\b", source.read_text()):
                continue
            consumers.append((str(source.relative_to(ROOT)), name))
    return check_artifacts(ROOT, consumers)


if __name__ == "__main__":
    raise SystemExit(main())
