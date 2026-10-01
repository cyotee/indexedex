#!/usr/bin/env python3
"""Report refreshed Hookless artifact identities and enforce EIP-170 sizes."""

import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    root = Path(__file__).resolve().parent.parent
    source_root = root / "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless"
    results = []
    failures = []
    source_hashes = {}
    for source in sorted(source_root.rglob("*.sol")):
        declarations = re.findall(r"^\s*(?:contract|library)\s+(\w+)", source.read_text(), flags=re.MULTILINE)
        for name in declarations:
            if not (root / "out" / source.name / (name + ".json")).is_file():
                failures.append(f"Missing current artifact: {source.name}:{name}")
        for artifact in sorted((root / "out" / source.name).glob("*.json")):
            data = json.loads(artifact.read_text())
            runtime = data.get("deployedBytecode", {}).get("object", "")
            if runtime.startswith("0x"):
                runtime = runtime[2:]
            if not runtime:
                continue
            metadata = data.get("metadata")
            if not isinstance(metadata, dict):
                metadata = json.loads(data.get("rawMetadata", "{}"))
            compiled_sources = metadata.get("sources", {})
            if str(source.relative_to(root)) not in compiled_sources:
                failures.append(f"Missing source identity in metadata: {artifact.stem}")
            for path, identity in compiled_sources.items():
                if not path.startswith(str(source_root.relative_to(root)) + "/"):
                    continue
                if path not in source_hashes:
                    source_hashes[path] = subprocess.run(
                        ["cast", "keccak", "0x" + (root / path).read_bytes().hex()],
                        capture_output=True, text=True, check=True,
                    ).stdout.strip()
                if source_hashes[path] != identity.get("keccak256"):
                    failures.append(f"Stale artifact {artifact.stem}: {path}")
            # Solc link placeholders occupy exactly the same 40 hex-character
            # width as the final address; no zero-byte substitution is needed.
            size = len(runtime) // 2
            results.append({
                "source": str(source.relative_to(root)),
                "contract": artifact.stem,
                "runtime_bytes": size,
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "artifact_sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
            })
            if size > 24_576:
                failures.append(f"{artifact.stem}: {size} > 24576")
    if not results:
        failures.append("No Hookless runtime artifacts found; build first")
    test_root = root / "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless"
    authored = sorted([*source_root.rglob("*.sol"), *test_root.rglob("*.sol"),
                       root / "scripts/check-hookless-artifacts.py", root / "scripts/run-hookless-acceptance.py"])
    files = [{"path": str(path.relative_to(root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
             for path in authored]
    manifest = "\n".join(f"{row['path']}:{row['sha256']}" for row in files)
    print(json.dumps({"files": files, "source_manifest_sha256": hashlib.sha256(manifest.encode()).hexdigest(),
                      "artifacts": results, "failures": failures}, indent=2))
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
