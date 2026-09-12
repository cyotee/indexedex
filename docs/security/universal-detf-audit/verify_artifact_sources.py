"""Check compiled artifact metadata against local source bytes, from the repo root.

Usage: python3 docs/security/universal-detf-audit/verify_artifact_sources.py \
    out/Contract.sol/Contract.json [more artifacts ...]

Requires the locally available PyCryptodome keccak implementation. This verifies
source freshness, not library linking, runtime behavior, or deployed bytecode.
"""

import json
import sys
from pathlib import Path

from Crypto.Hash import keccak


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Pass one or more compiled artifact paths.")
    hashes = {}
    findings = []
    checked = 0
    for artifact_name in sys.argv[1:]:
        artifact = Path(artifact_name)
        if not artifact.is_file():
            findings.append({"artifact": artifact_name, "error": "missing artifact"})
            continue
        data = json.loads(artifact.read_text())
        metadata = data.get("metadata")
        if not isinstance(metadata, dict) or not metadata.get("sources"):
            findings.append({"artifact": artifact_name, "error": "missing source metadata"})
            continue
        for source_name, entry in metadata["sources"].items():
            source = Path(source_name)
            if not source.is_file():
                findings.append({"artifact": artifact_name, "source": source_name, "error": "source unavailable"})
                continue
            if source_name not in hashes:
                digest = keccak.new(digest_bits=256)
                digest.update(source.read_bytes())
                hashes[source_name] = "0x" + digest.hexdigest()
            if hashes[source_name] != entry.get("keccak256"):
                findings.append({"artifact": artifact_name, "source": source_name, "error": "source hash mismatch"})
        checked += 1
    print(json.dumps({"artifactsChecked": checked, "uniqueSourcesHashed": len(hashes), "findings": findings}, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
