"""Independent wide-integer oracle; tick coefficients are parsed only from the pinned PRD.

Run with no arguments to check the committed fixtures, ``fixtures`` to print them,
or ``md a b c`` to emit an ABI tuple (MD succeeds, MD value, MU succeeds, MU value).
Fixture installation is deliberately external: this script never writes files.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import re
import sys
from pathlib import Path
from typing import Final, TypedDict

ROOT: Final = Path(__file__).resolve().parents[4]
PRD: Final = ROOT / "docs/research/pairtoken-unified-prd-r2-20261027/handoff/PRD.md"
PIN: Final = "088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d"
FIXTURE: Final = Path(__file__).with_name("fixtures") / "math.json"
Q96: Final = 1 << 96
Q128: Final = 1 << 128
MAX: Final = (1 << 256) - 1


class Fixtures(TypedDict):
    """Flattened numeric rows consumed with Foundry's JSON integer parser."""

    ticks: list[int]
    prices: list[int]
    md: list[int]
    amounts: list[int]
    fit: list[int]
    roots: list[int]


def coefficients() -> tuple[int, ...]:
    """Verify the raw-file pin before interpreting its unique coefficient table."""
    raw = PRD.read_bytes()
    actual = hashlib.sha256(raw).hexdigest()
    if actual != PIN:
        raise RuntimeError(f"PRD hash mismatch: {actual}")
    section = raw.decode().split("**PT-MATH-04", 1)[1].split("**PT-MATH-05", 1)[0]
    rows = re.findall(r"^\| (\d+) \| `([0-9a-f]+)` \|$", section, re.MULTILINE)
    if [int(index) for index, _ in rows] != list(range(20)):
        raise RuntimeError("PRD coefficient indices are not exactly 0 through 19")
    return tuple(int(value, 16) for _, value in rows)


def tick_price(tick: int, table: tuple[int, ...]) -> int:
    """Evaluate the PRD recurrence using unbounded integer products and floors."""
    ratio = Q128
    magnitude = abs(tick)
    for bit, coefficient in enumerate(table):
        if magnitude & (1 << bit):
            ratio = ratio * coefficient // Q128
    if tick > 0:
        ratio = MAX // ratio
    return (ratio + (1 << 32) - 1) // (1 << 32)


def md_result(a: int, b: int, c: int) -> tuple[int, int, int, int]:
    """Return ABI-compatible success flags and independently computed wide quotients."""
    if c == 0:
        return (0, 0, 0, 0)
    down, remainder = divmod(a * b, c)
    up = down + bool(remainder)
    return (int(down <= MAX), down if down <= MAX else 0, int(up <= MAX), up if up <= MAX else 0)


def amount_row(a: int, b: int, liquidity: int) -> list[int]:
    """Keep both nested amount0 roundings, without calling production arithmetic."""
    low, high = sorted((a, b))
    numerator = liquidity * Q96 * (high - low)
    first_up = (numerator + high - 1) // high
    amount1_numerator = liquidity * (high - low)
    return [
        a,
        b,
        liquidity,
        (numerator // high) // low,
        (first_up + low - 1) // low,
        amount1_numerator // Q96,
        (amount1_numerator + Q96 - 1) // Q96,
    ]


def fit_row(p: int, a: int, b: int, x: int, y: int) -> list[int]:
    """Compute the branch's individually narrowed liquidity candidates."""
    low, high = sorted((a, b))

    def l0(left: int, right: int) -> int:
        return x * (left * right // Q96) // (right - left)

    def l1(left: int, right: int) -> int:
        return y * Q96 // (right - left)

    if p <= low:
        candidates = [l0(low, high)]
    elif p >= high:
        candidates = [l1(low, high)]
    else:
        candidates = [l0(p, high), l1(low, p)]
    if any(value >= Q128 for value in candidates):
        raise RuntimeError("success fixture contains a uint128 overflow")
    return [p, a, b, x, y, min(candidates)]


def fixtures() -> Fixtures:
    """Build deterministic input classes independently of Solidity helper results."""
    table = coefficients()
    rng = random.Random(20261027)
    ticks = {0, -887272, -887271, 887271, 887272, -60, 60}
    for bit in range(20):
        for sign in (-1, 1):
            for offset in (-1, 0, 1):
                tick = sign * ((1 << bit) + offset)
                if abs(tick) <= 887272:
                    ticks.add(tick)
    ticks.update(rng.randint(-887272, 887272) for _ in range(128))
    ordered = sorted(ticks)
    prices = [tick_price(tick, table) for tick in ordered]
    anchors = dict(zip(ordered, prices, strict=True))
    if (anchors[-887272], anchors[0], anchors[887272]) != (
        4295128739, Q96, 1461446703485210103287273052203988822378723970342
    ):
        raise RuntimeError("PRD recurrence failed its independently stated constant anchors")

    # (MAX-1)^2/(MAX-2) has MD == MAX with a remainder: only MU must fail.
    inputs = [
        (0, 0, 0), (0, MAX, 1), (1, 1, 0), (7, 9, 4), (8, 9, 3),
        (MAX, MAX, MAX), (MAX, MAX, MAX - 1), (1 << 200, 1 << 100, 1 << 100),
        (MAX - 1, MAX - 1, MAX - 2),
        (1 << 128, 1 << 128, 2), (MAX, 1, 1),
    ]
    inputs.extend((rng.getrandbits(256), rng.getrandbits(256), rng.getrandbits(256)) for _ in range(64))
    md = [value for a, b, c in inputs for value in (a, b, c, *md_result(a, b, c))]
    amounts: list[int] = []
    for a, b, liquidity in [
        (Q96, Q96 * 2, 1000), (Q96 * 2, Q96, 1000),
        (Q96, Q96 + 1, 1), (Q96 + 1, Q96, Q128 - 1),
        (1, (1 << 160) - 1, Q128 - 1),
        (Q96, Q96, Q128 - 1), (1, Q96, 0),
        (4295128739, 1461446703485210103287273052203988822378723970342, Q128 - 1),
    ]:
        amounts.extend(amount_row(a, b, liquidity))
    for _ in range(64):
        amounts.extend(amount_row(rng.randint(1, (1 << 160) - 1), rng.randint(1, (1 << 160) - 1), rng.getrandbits(128)))
    fit: list[int] = []
    for p in (Q96 // 2, Q96, Q96 + Q96 // 2, Q96 * 2, Q96 * 3):
        fit.extend(fit_row(p, Q96, Q96 * 2, 1000, 300))
        fit.extend(fit_row(p, Q96 * 2, Q96, 1000, 300))
    # Unequal balances and each inside-range limiting leg.
    fit.extend(fit_row(Q96 + Q96 // 2, Q96, Q96 * 2, 0, 300))
    fit.extend(fit_row(Q96 + Q96 // 2, Q96, Q96 * 2, 1000, 0))
    # Tight nonintegral price products expose the inner L0 floor.
    lower = Q96 // 100 + 1
    for p in (lower, lower + 1, lower + 3):
        fit.extend(fit_row(p, lower, lower + 3, 1000, 1))
    for _ in range(32):
        lower = rng.randint(1, Q96 * 2)
        upper = lower + rng.randint(1000, 1_000_000)
        p = rng.choice((lower - 1, lower, (lower + upper) // 2, upper, upper + 1))
        fit.extend(fit_row(p, lower, upper, rng.getrandbits(32), rng.getrandbits(32)))
    values = [0, 1, 2, 3, 4, 8, 9, 1000**2, 1001**2, MAX, (Q128 - 1)**2]
    values.extend(rng.getrandbits(256) for _ in range(64))
    roots = [number for value in values for number in (value, math.isqrt(value))]
    return Fixtures(ticks=ordered, prices=prices, md=md, amounts=amounts, fit=fit, roots=roots)


def main() -> None:
    """Print ABI or fixtures; default mode verifies byte-for-byte fixture reproducibility."""
    match sys.argv[1:]:
        case ["md", a, b, c]:
            result = md_result(int(a), int(b), int(c))
            print("0x" + "".join(value.to_bytes(32, "big").hex() for value in result))
        case ["fixtures"]:
            print(json.dumps(fixtures(), indent=2))
        case []:
            expected = json.dumps(fixtures(), indent=2) + "\n"
            actual = FIXTURE.read_text()
            if actual != expected:
                raise RuntimeError("committed math fixture differs from the pinned PRD oracle")
            print("PASS: pinned PRD hash, coefficient parsing, constant anchors, and all fixture rows")
        case _:
            raise SystemExit("usage: math-oracle.py [fixtures | md a b c]")


if __name__ == "__main__":
    main()
