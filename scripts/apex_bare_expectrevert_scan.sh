#!/usr/bin/env bash
# APEX R2.4: reject unqualified revert expectations in the hook/FullSpread suites
# and APEX-labelled regression files across every production family.
# Usage: scripts/apex_bare_expectrevert_scan.sh [--check]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 - "$@" <<'PY'
from pathlib import Path
import re
import sys

if sys.argv[1:] not in ([], ["--check"]):
    raise SystemExit("usage: apex_bare_expectrevert_scan.sh [--check]")
roots = (
    Path("test/foundry/spec/hooks/uniswap/v4/standardExchange"),
    Path("test/foundry/spec/vaults/standard/exchange/protocols/uniswap"),
)
paths = {p for root in roots for p in root.rglob("*.sol")}
for p in Path("test/foundry/spec").rglob("*.sol"):
    if re.search(r"(?<![A-Za-z0-9])APEX(?:\b|[_0-9])", p.read_text(), re.IGNORECASE):
        paths.add(p)
# Remove comments and literals without shifting source line numbers.
noncode = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
bare = re.compile(r"\bvm\s*\.\s*expectRevert\s*\(\s*\)")
sites = []
for p in sorted(paths):
    source = p.read_text()
    code = noncode.sub(
        lambda m: re.sub(r"[^\n]", "x" if m.group()[0] in "\"'" else " ", m.group()), source
    )
    for m in bare.finditer(code):
        line = code.count("\n", 0, m.start()) + 1
        sites.append(f"{p}:{line}: {source.splitlines()[line - 1].strip()}")
output = Path("docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("".join(f"{site}\n" for site in sites))
if sites:
    print("\n".join(sites))
print(f"APEX R2.4: {len(sites)} bare expectations in {len(paths)} files")
if "--check" in sys.argv and sites:
    raise SystemExit(1)
PY
