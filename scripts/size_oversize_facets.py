#!/usr/bin/env python3
"""Parse forge `compile --sizes` / yarn sizes output for product Facets over EIP-170.

Usage:
  python3 scripts/size_oversize_facets.py [SIZES.log]
  python3 scripts/size_oversize_facets.py --all [SIZES.log]   # include Targets
  python3 scripts/size_oversize_facets.py --g1 [SIZES.log]    # print G1 baseline names only

Exit code 0 always (report tool). Empty product Facet oversize list = ship gate G4.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

EIP170 = 24_576

# G1 ship set from docs/CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md §2 (baseline freeze).
G1_FACETS = [
    "UniswapV4StandardExchangeOrbitalBufferHookHooksFacet",
    "UniswapV4StandardExchangeOrbitalBufferHookDepositFacet",
    "UniswapV4StandardExchangeOrbitalBufferHookSeFacet",
    "UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet",
    "UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet",
    "UniswapV4WeightedSwapHookHooksFacet",
    "UniswapV4WeightedSwapHookLiquidityFacet",
    "UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet",
    "UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet",
    "UniswapV4StandardExchangeWeightedDETFFacet",
    "UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet",
    "UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet",
    "UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet",
    "MultiVaultWeightedDetfExchangeInFacet",
    "AerodromeStandardExchangeOutFacet",
    "UniswapV4StandardExchangeOutFacet",
    "MixedBufferMultiVaultStableDetfExchangeInFacet",
    "UniswapV4StandardExchangeOrbitalDETFFacet",
]

# Names that are never product Facet ship blockers (vendored / test-only / diagnostic Targets).
EXCLUDE_SUBSTR = (
    "Mock",
    "TestDeployLib",
    "TestBase",
    "Behavior_",
    "Handler_",
)

# forge table: | Name | Runtime Size (B) | Initcode Size (B) | Runtime Margin (B) | Initcode Margin (B) |
# Numbers may include commas: 46,457
ROW_RE = re.compile(
    r"^\|\s*([A-Za-z0-9_]+)\s*\|\s*([\d,]+)\s*\|\s*([\d,]+)\s*\|\s*([-\d,]+)\s*\|\s*([-\d,]+)"
)


def parse_int(s: str) -> int:
    return int(s.replace(",", "").strip())


def is_product_facet(name: str) -> bool:
    if not name.endswith("Facet"):
        return False
    if any(x in name for x in EXCLUDE_SUBSTR):
        return False
    # Exclude obvious non-product test stubs if named *Facet
    if name.startswith("Mock") or name.endswith("MockFacet"):
        return False
    return True


def parse_sizes(text: str) -> list[dict]:
    rows: list[dict] = []
    for line in text.splitlines():
        m = ROW_RE.match(line.strip())
        if not m:
            continue
        name, rt, init, rt_m, init_m = m.groups()
        rows.append(
            {
                "name": name,
                "runtime": parse_int(rt),
                "initcode": parse_int(init),
                "runtime_margin": parse_int(rt_m),
                "initcode_margin": parse_int(init_m),
            }
        )
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sizes_log", nargs="?", default="SIZES.log")
    ap.add_argument("--all", action="store_true", help="Include non-Facet oversize rows")
    ap.add_argument("--g1", action="store_true", help="Print G1 baseline rows (any margin)")
    ap.add_argument(
        "--negative-only",
        action="store_true",
        default=True,
        help="Only rows with runtime margin < 0 (default)",
    )
    ap.add_argument(
        "--include-positive",
        action="store_true",
        help="Include margin >= 0 rows (with --g1)",
    )
    args = ap.parse_args()

    path = Path(args.sizes_log)
    if not path.is_file():
        print(f"error: missing {path}", file=sys.stderr)
        return 2

    rows = parse_sizes(path.read_text(errors="replace"))
    if not rows:
        print(f"error: no size rows parsed from {path}", file=sys.stderr)
        return 2

    if args.g1:
        by_name = {r["name"]: r for r in rows}
        print(f"# G1 Facet inventory from {path} (EIP-170={EIP170})")
        print(f"{'name':<80} {'rt':>8} {'margin':>8}")
        missing = []
        for name in G1_FACETS:
            r = by_name.get(name)
            if not r:
                missing.append(name)
                print(f"{name:<80} {'MISSING':>8}")
                continue
            print(f"{name:<80} {r['runtime']:>8} {r['runtime_margin']:>8}")
        over = [n for n in G1_FACETS if by_name.get(n) and by_name[n]["runtime_margin"] < 0]
        print(f"# g1_count={len(G1_FACETS)} missing={len(missing)} oversize={len(over)}")
        return 0

    out: list[dict] = []
    for r in rows:
        if r["runtime_margin"] >= 0 and not args.include_positive:
            continue
        name = r["name"]
        if args.all:
            if any(x in name for x in EXCLUDE_SUBSTR):
                continue
            out.append(r)
        else:
            if is_product_facet(name):
                out.append(r)

    # Sort worst margin first
    out.sort(key=lambda r: r["runtime_margin"])

    print(f"# product Facet oversize from {path} (runtime_margin < 0, EIP-170={EIP170})")
    print(f"{'name':<80} {'rt':>8} {'margin':>8}")
    for r in out:
        print(f"{r['name']:<80} {r['runtime']:>8} {r['runtime_margin']:>8}")
    print(f"# count={len(out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
