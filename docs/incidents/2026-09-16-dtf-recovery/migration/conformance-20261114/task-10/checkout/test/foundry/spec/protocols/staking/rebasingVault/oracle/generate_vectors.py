#!/usr/bin/env python3
"""Independent ACC-03 conversion vectors. Arbitrary-precision; not the Solidity Common library."""

from __future__ import annotations

import json
from pathlib import Path

WAD = 10**18


def floor_muldiv(x: int, y: int, d: int) -> int:
    return (x * y) // d


def ceil_muldiv(x: int, y: int, d: int) -> int:
    q, r = divmod(x * y, d)
    return q if r == 0 else q + 1


def row(A: int, S: int, V: int, x: int) -> dict:
    return {
        "A": str(A),
        "S": str(S),
        "V": str(V),
        "x": str(x),
        "depositShares": str(floor_muldiv(x, S + V, A + 1)),
        "mintAssets": str(ceil_muldiv(x, A + 1, S + V)),
        "redeemAssets": str(floor_muldiv(x, A + 1, S + V)),
        "withdrawShares": str(ceil_muldiv(x, S + V, A + 1)),
        "wadRate": str(floor_muldiv(WAD, A + 1, S + V)),
    }


def main() -> None:
    V = 10**10
    vectors = [
        row(0, 0, V, 1),
        row(0, 0, V, 10**18),
        row(10**18, 10**28, V, 1),
        row(10**18, 10**28, V, 10**18),
        row(1, 1, V, 1),
        # 512-bit intermediate: x and (S+V) each near 2^200
        row(2**180, 2**200, V, 2**200),
        row(2**200 - 1, 2**180, V, 2**10),
        row(10**18, 10**28, V, 10**28 - 1),
    ]
    out = Path(__file__).with_name("vectors.json")
    out.write_text(json.dumps(vectors, indent=2) + "\n")
    print(f"wrote {out} ({len(vectors)} vectors)")


if __name__ == "__main__":
    main()
