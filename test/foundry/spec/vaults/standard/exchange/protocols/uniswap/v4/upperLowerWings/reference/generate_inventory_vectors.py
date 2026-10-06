#!/usr/bin/env python3
"""Independent arbitrary-precision rational controls for full protocol-range principal.

Only the published protocol endpoint sqrt constants are shared with TickMath.
No production implementation is imported or executed to derive expectations.
"""
import json
from pathlib import Path

Q96 = 1 << 96
LOWER = 4295128739
UPPER = 1461446703485210103287273052203988822378723970342

def ceil_div(numerator, denominator):
    return (numerator + denominator - 1) // denominator

def vectors():
    values = []
    for price in (LOWER, LOWER + 1, Q96 - 1, Q96, Q96 + 1, UPPER - 1):
        for liquidity in (0, 1, 10**18, (1 << 128) - 1):
            n0 = liquidity * (UPPER - price) * Q96
            d0 = price * UPPER
            n1 = liquidity * (price - LOWER)
            values.extend((price, liquidity, n0 // d0, n1 // Q96,
                           ceil_div(n0, d0), ceil_div(n1, Q96)))
    return {"values": values}

if __name__ == "__main__":
    target = Path(__file__).with_name("UniswapV4UpperLowerWingsStandardExchangeVaultInventoryVectors.json")
    target.write_text(json.dumps(vectors(), indent=2) + "\n")
