#!/usr/bin/env python3
"""Check current P and its permitted pure H dependency identities and runtime sizes."""
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    source_root = root / "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook"
    test_root = root / "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook"
    shared = {"UniswapV4FullSpreadHooklessStandardExchangeVault" + suffix + ".sol"
              for suffix in ("InventoryMath", "ProtectionMath", "RouteTypes")}
    failures, artifacts, hashes = [], [], {}
    for source in sorted(source_root.rglob("*.sol")):
        text = source.read_text()
        for name in re.findall(r"^\s*(?:contract|library)\s+(\w+)", text, re.M):
            if not (root / "out" / source.name / (name + ".json")).exists():
                failures.append(f"Missing artifact {source.name}:{name}")
        if "/test/" in str(source.relative_to(source_root)):
            continue
        for artifact in sorted((root / "out" / source.name).glob("*.json")):
            data = json.loads(artifact.read_text())
            runtime = data.get("deployedBytecode", {}).get("object", "").removeprefix("0x")
            if not runtime:
                continue
            metadata = data.get("metadata")
            if not isinstance(metadata, dict):
                metadata = json.loads(data.get("rawMetadata", "{}"))
            sources = metadata.get("sources", {})
            if str(source.relative_to(root)) not in sources:
                failures.append(f"Missing identity {artifact.stem}")
            for path, identity in sources.items():
                if "fullSpread/ponsFamilyV2Hook/" not in path and Path(path).name not in shared:
                    continue
                if path not in hashes:
                    hashes[path] = subprocess.run(["cast", "keccak", "0x" + (root / path).read_bytes().hex()],
                        check=True, capture_output=True, text=True).stdout.strip()
                if hashes[path] != identity.get("keccak256"):
                    failures.append(f"Stale artifact {artifact.stem}: {path}")
            size = len(runtime) // 2
            if size > 24_576 and "/test/" not in str(source.relative_to(root)):
                failures.append(f"Oversize runtime {artifact.stem}: {size}")
            artifacts.append({"contract": artifact.stem, "runtime_bytes": size,
                "artifact_sha256": hashlib.sha256(artifact.read_bytes()).hexdigest()})
    # The acceptance references live outside either economic family. Include their
    # identities so a family manifest cannot hide a changed independent oracle.
    reference_names = ("CrossModeCampaign", "BlockedYield", "NativeImport")
    authored = sorted([*source_root.rglob("*.sol"), *test_root.rglob("*.sol"),
        *(root / "contracts/test/bases" / f"TestBase_UniswapV4FullSpread{name}.sol" for name in reference_names),
        root / "scripts/run-fullspread-family-acceptance.py", Path(__file__).resolve()])
    files = [{"path": str(path.relative_to(root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
             for path in authored]
    manifest = "\n".join(f"{row['path']}:{row['sha256']}" for row in files)
    print(json.dumps({"files": files, "source_manifest_sha256": hashlib.sha256(manifest.encode()).hexdigest(),
        "artifacts": artifacts, "failures": failures}, indent=2))
    return bool(failures) or not artifacts


if __name__ == "__main__":
    raise SystemExit(main())
