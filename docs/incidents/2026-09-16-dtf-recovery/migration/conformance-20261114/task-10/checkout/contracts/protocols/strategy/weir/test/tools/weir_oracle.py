#!/usr/bin/env python3

import json
from pathlib import Path

Q = 2 ** 96
H = 2 ** 128
K = 2 ** 20
MIN_SQRT = 4295128739
MAX_SQRT = 1461446703485210103287273052203988822378723970342


def md(x, y, d):
    if d == 0 or x * y // d >= 2 ** 256:
        raise ZeroDivisionError("empty revert")
    return (x * y) // d


def u128(x):
    if x > 2 ** 128 - 1:
        raise OverflowError("liquidity overflow")
    return x


def sort(a, b):
    return (b, a) if a > b else (a, b)


def l0(a, b, amount):
    a, b = sort(a, b)
    return u128(md(amount, md(a, b, Q), b - a))


def l1(a, b, amount):
    a, b = sort(a, b)
    return u128(md(amount, Q, b - a))


def liquidity(p, a, b, amount0, amount1):
    a, b = sort(a, b)
    if p <= a:
        return l0(a, b, amount0)
    if p < b:
        return min(l0(p, b, amount0), l1(a, p, amount1))
    return l1(a, b, amount1)


def main():
    vectors = {
        "F0": {
            "deposit": K + 2,
            "liquidity": K,
            "userShares": K - 1000,
            "totalShares": K,
            "managerCostPerSide": K,
            "withdrawOutPerSide": K - 1001,
        },
        "library": {
            "l0_3": l0(Q, Q * 2, 3),
            "l1_3": l1(Q, Q * 2, 3),
            "interior": liquidity(Q, Q // 2, Q * 2, 3, 4),
            "f0Liquidity": liquidity(Q, MIN_SQRT, MAX_SQRT, K, K),
        },
    }
    out = Path(__file__).resolve().parents[1] / "fixtures" / "arithmetic-vectors.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(vectors, indent=2) + "\n", encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
