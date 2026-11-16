# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# How to run:
# python3 math_oracle.py            # verify checked-in vectors, no writes
# python3 math_oracle.py fixtures   # print deterministic replacement JSON
"""Independent PRD arithmetic with Python integers and Fraction, not SUT code.

Rows are flat integer arrays for Foundry's JSON parser. No Forge, FFI, imports
from the baseline, or writes are needed. Seed 20261028 fixes the compact corpus.
The integer recurrence and Fraction formulation cross-check currency rounding.
"""

from __future__ import annotations

import json
import random
import sys
from fractions import Fraction
from math import isqrt
from pathlib import Path
from typing import Final, TypedDict

Q96: Final = 1 << 96
MAX: Final = (1 << 256) - 1
MAX128: Final = (1 << 128) - 1
SEED: Final = 20261028


class Vectors(TypedDict):
    """Flat rows, with widths documented in README and the Solidity consumer."""

    seed: int
    amounts: list[int]
    liquidity: list[int]
    paired: list[int]
    credit: list[int]
    zap: list[int]
    allocation: list[int]
    compound: list[int]
    rates: list[int]


def amounts(p: int, lo: int, hi: int, liquidity: int) -> tuple[int, int, int, int]:
    """Direct rational amounts, independent of canonical nested divisions."""
    clamped = min(max(p, lo), hi)
    a0 = Fraction(liquidity * Q96 * (hi - clamped), hi * clamped)
    a1 = Fraction(liquidity * (clamped - lo), Q96)
    return (
        a0.numerator // a0.denominator,
        a1.numerator // a1.denominator,
        -(-a0.numerator // a0.denominator),
        -(-a1.numerator // a1.denominator),
    )


def liquidity(p: int, lo: int, hi: int, a0: int, a1: int) -> int:
    """Canonical conservative token0 floor-product sizing; narrow only the min."""
    if p <= lo:
        return a0 * (lo * hi // Q96) // (hi - lo)
    if p >= hi:
        return a1 * Q96 // (hi - lo)
    return min(a0 * (p * hi // Q96) // (hi - p), a1 * Q96 // (p - lo))


def credit(s: int, r0: int, r1: int, c0: int, c1: int) -> int:
    """The mathematical minimum includes arbitrarily wide per-leg quotients."""
    return min(s * contribution // reserve for reserve, contribution in ((r0, c0), (r1, c1)) if reserve)


def paired(s: int, r0: int, r1: int, a0: int, a1: int) -> tuple[int, int, int]:
    """Candidate shares and accepted inputs, including full one-sided maxima."""
    if s == 0:
        return isqrt(a0 * a1), a0, a1
    q = credit(s, r0, r1, a0, a1)
    if r0 == 0:
        return q, 0, a1
    if r1 == 0:
        return q, a0, 0
    return q, min(a0, (q * r0 + s - 1) // s), min(a1, (q * r1 + s - 1) // s)


def compound(p: int, lo: int, hi: int, b0: int, b1: int, active: int, bps: int) -> tuple[int, int]:
    """Baseline sequential-floor comparison, strict raw dust and quarter cap."""
    if b0 <= 1000 and b1 <= 1000:
        return 0, 0
    fit = liquidity(p, lo, hi, b0, b1)
    _, _, cost0, cost1 = amounts(p, lo, hi, fit)
    left0, left1 = b0 - cost0, b1 - cost1
    direction = int((left0 * p // Q96) * p // Q96 >= left1)
    left = left0 if direction else left1
    if left <= 1000 or active == 0:
        return direction, 0
    r0, r1, _, _ = amounts(p, lo, hi, active)
    cap = (r0 if direction else r1) * bps // 10000 // 4
    return direction, min(left // 2, cap)


def rate(p: int, a0: int, a1: int, supply: int, token0: int) -> int:
    """Single currency-conversion floor followed by single share-scaling floor."""
    if supply == 0:
        return 0
    converted = Fraction(a1 * Q96 * Q96, p * p) if token0 else Fraction(a0 * p * p, Q96 * Q96)
    raw = (a0 if token0 else a1) + converted.numerator // converted.denominator
    return raw * 10**18 // supply


def vectors() -> Vectors:
    """Build deterministic controls spanning endpoints, rounding and wide values."""
    rng = random.Random(SEED)
    result: Vectors = {
        "seed": SEED, "amounts": [], "liquidity": [], "paired": [], "credit": [],
        "zap": [], "allocation": [], "compound": [], "rates": [],
    }
    for p in (Q96 // 2 - 1, Q96 // 2, Q96 - 1, Q96, 2 * Q96, 2 * Q96 + 1):
        for size in (0, 1, 17, MAX128):
            result["amounts"].extend((p, Q96 // 2, 2 * Q96, size, *amounts(p, Q96 // 2, 2 * Q96, size)))
    for _ in range(8):
        lo = rng.randrange(1 << 32, Q96)
        hi = rng.randrange(Q96 + 1, 1 << 160)
        p = rng.randrange(lo, hi)
        size = rng.randrange(1, 1 << 128)
        result["amounts"].extend((p, lo, hi, size, *amounts(p, lo, hi, size)))
    for p, a0, a1 in (
        (Q96 // 2 - 1, 120, MAX), (Q96 // 2, 120, 0), (2 * Q96, MAX, 120),
        (2 * Q96 + 1, 0, 120), (Q96, 17, 19), (Q96, MAX, 1),
        (Q96, 1, MAX), (Q96, MAX, MAX), (Q96, 0, MAX), (Q96, MAX128 // 2, MAX128 // 2),
    ):
        value = liquidity(p, Q96 // 2, 2 * Q96, a0, a1)
        result["liquidity"].extend((p, Q96 // 2, 2 * Q96, a0, a1, int(value <= MAX128), value if value <= MAX128 else 0))
    for row in (
        (0, 0, 0, 7, 17), (0, 0, 0, MAX, 1), (11, 7, 13, 17, 19),
        (11, 0, 13, MAX, 19), (11, 7, 0, 17, MAX),
        (2, 1, MAX, MAX, MAX), (2, MAX, 1, MAX, MAX),
    ):
        result["paired"].extend((*row, *paired(*row)))
    for row in (
        (2, 1, MAX, MAX, MAX), (2, MAX, 1, MAX, MAX),
        (MAX, 1, 1, MAX, MAX), (11, 7, 13, 17, 19),
        (11, 0, 13, MAX, 19), (11, 7, 0, 17, MAX),
        (MAX, MAX, MAX, MAX, MAX), (1, MAX, 1, 1, MAX),
    ):
        value = credit(*row)
        status = 2 if value == 0 else int(value <= MAX)
        result["zap"].extend((*row, status, value if status == 1 else 0))
        for cap in (1, 13, MAX):
            if min(cap, value) > 0:
                result["credit"].extend((*row, cap, min(cap, value)))
    for row in ((11, 3, 17, 23, 31), (11, 11, 17, 23, 31), (MAX, MAX - 1, MAX128, MAX, MAX)):
        s, shares, size, b0, b1 = row
        result["allocation"].extend((*row, size * shares // s, b0 * shares // s, b1 * shares // s))
    for p, b0, b1, active, bps in (
        (Q96, 1000, 1000, 10**8, 10000), (Q96, 1001, 0, 10**8, 10000),
        (Q96, 10000, 10000, 10**8, 10000), (Q96, 10000, 0, 0, 10000),
        (Q96, 100000, 0, 10000, 10000), (Q96, 0, 100000, 10000, 10000),
        (Q96 + Q96 // 3, 100001, 731, 10007, 3333),
        (Q96 // 2, 0, 100001, 10007, 3333), (2 * Q96, 100001, 0, 10007, 3333),
        (Q96, 100000, 0, 1, 1),
    ):
        row = (p, Q96 // 2, 2 * Q96, b0, b1, active, bps)
        result["compound"].extend((*row, *compound(*row)))
    # General math-domain direction witness (not a full-range product fixture).
    p = 4295128740
    x = (1001 * Q96 * Q96 + p * p - 1) // (p * p)
    row = (p, p, 2 * p, x, 1001, 10000, 10000)
    result["compound"].extend((*row, *compound(*row)))
    rate_inputs = [
        (Q96, 0, 10**6, 10**18, 0), (Q96, 10**8, 0, 10**18, 1),
        (Q96, 10**18, 10**18, 10**18, 0), (0, MAX, MAX, 0, 0),
        (2 * Q96, MAX, 0, MAX, 0), (Q96 // 2, 0, MAX, MAX, 1),
        (2 * Q96, MAX, 0, 1, 0), (Q96 // 2, 0, MAX, 1, 1),
        ((1 << 160) - 1, MAX, MAX, MAX, 0), (1, MAX, MAX, MAX, 1),
        (Q96 + Q96 // 2, 1, 0, 10**18, 0),
        (Q96 + Q96 // 2, 0, 5, 10**18, 1),
        (Q96, MAX, MAX, MAX, 1),
        (Q96, MAX, 0, 10**18, 1), (Q96, MAX, 1, 10**18, 1),
    ]
    for _ in range(16):
        rate_inputs.append((rng.randrange(1, 1 << 160), rng.randrange(MAX), rng.randrange(MAX), rng.randrange(1, MAX), rng.randrange(2)))
    for row in rate_inputs:
        value = rate(*row)
        result["rates"].extend((*row, int(value <= MAX), value if value <= MAX else 0))
    return result


def main() -> None:
    """Print replacement vectors or compare every committed value exactly."""
    expected = vectors()
    if sys.argv[1:] == ["fixtures"]:
        print(json.dumps(expected, separators=(",", ":")))
        return
    assert not sys.argv[1:], "Only the optional fixtures argument is supported"
    committed = json.loads(Path(__file__).with_name("vectors.json").read_text())
    assert committed == expected, "Checked-in vectors differ from the independent oracle"
    # Distinguish single-floor SY from the baseline sequential-floor comparison.
    p = Q96 + Q96 // 2
    assert rate(p, 1, 0, 10**18, 0) == 2
    assert ((1 * p // Q96) * p // Q96) == 1
    assert rate(2 * Q96, MAX, 0, MAX, 0) == 4 * 10**18
    assert rate(Q96 // 2, 0, MAX, MAX, 1) == 4 * 10**18
    widths = {"amounts": 8, "liquidity": 7, "paired": 8, "credit": 7, "zap": 7, "allocation": 8, "compound": 9, "rates": 7}
    counts = {key: len(committed[key]) // width for key, width in widths.items()}
    print(f"PASS independent oracle seed={SEED} vectors={counts}")


if __name__ == "__main__":
    main()
