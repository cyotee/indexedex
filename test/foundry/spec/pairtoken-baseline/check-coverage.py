# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# How to run: python3 test/foundry/spec/pairtoken-baseline/check-coverage.py
"""Check pinned requirement IDs against the plan's evidence map."""

from hashlib import sha256
from pathlib import Path
import re
from typing import Final

ROOT: Final = Path(__file__).resolve().parents[4]
HANDOFF: Final = ROOT / "docs/research/pairtoken-unified-prd-r2-20261027/handoff"
PRD_SHA256: Final = "088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d"
ID_PATTERN: Final = r"PT-[A-Z]+-(?:[0-9]{2}|BASE)"


def main() -> int:
    """Fail on a changed authority or a missing normative identifier."""
    prd_bytes = (HANDOFF / "PRD.md").read_bytes()
    if sha256(prd_bytes).hexdigest() != PRD_SHA256:
        print("FAIL: PRD SHA-256 differs from the implementation plan pin.")
        return 1
    prd = prd_bytes.decode("utf-8")
    plan = (HANDOFF / "IMPLEMENTATION_AND_TEST_PLAN.md").read_text()
    evidence_map = plan.split("## 8. Evidence map\n", 1)[1].split("\n## 9.", 1)[0]
    tagged_ids = set(re.findall(ID_PATTERN, prd))
    mapped_ids = set(re.findall(rf"^\| ({ID_PATTERN}) \|", evidence_map, re.MULTILINE))
    missing = sorted(tagged_ids - mapped_ids)
    if missing:
        print("FAIL: IDs absent from section 8: " + ", ".join(missing))
        return 1
    print(f"PASS: pinned PRD; all {len(tagged_ids)} tagged IDs mapped in section 8.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
