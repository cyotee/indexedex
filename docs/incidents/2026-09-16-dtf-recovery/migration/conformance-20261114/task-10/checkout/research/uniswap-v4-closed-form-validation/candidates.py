from __future__ import annotations

import math
from fractions import Fraction

from integer_core import (
    Q96,
    compute_swap_step,
    get_amount0_delta,
    get_amount1_delta,
    single_exit,
)


def quadratic_roots(q2: Fraction, q1: Fraction, q0: Fraction) -> list[Fraction]:
    if q2 == 0:
        if q1 == 0:
            return []
        return [-q0 / q1]
    discriminant = q1 * q1 - 4 * q2 * q0
    if discriminant < 0:
        return []
    scale = 1 << 256
    scaled = (discriminant.numerator * scale * scale) // discriminant.denominator
    root = Fraction(math.isqrt(scaled), scale)
    return [(-q1 + root) / (2 * q2), (-q1 - root) / (2 * q2)]


def cf_r_coefficients(f0: int, f1: int, active: int, owned: int, sqrt_start: int, lower: int, upper: int, fee_pips: int) -> tuple[Fraction, Fraction, Fraction]:
    fee = Fraction(fee_pips, 1_000_000)
    g = 1 - fee
    if g == 0 or active == 0:
        raise ValueError("unsupported fee or liquidity")
    r = Fraction(owned, active) * fee
    s = Fraction(sqrt_start, Q96)
    a = Fraction(lower, Q96)
    b = Fraction(upper, Q96)
    l = Fraction(owned)
    capital_l = Fraction(active)
    a0 = Fraction(f0) - l / b + (1 - r) * capital_l / (g * s)
    h0 = l - (1 - r) * capital_l / g
    a1 = Fraction(f1) + capital_l * s - l * a
    h1 = l - capital_l
    q2 = a0 + h1 / b
    q1 = h0 - a0 * a - h1 + a1 / b
    q0 = -h0 * a - a1
    return q2, q1, q0


def select_repair_root(roots: list[Fraction], sqrt_start: int, lower: int, upper: int) -> Fraction | None:
    s = Fraction(sqrt_start, Q96)
    a = Fraction(lower, Q96)
    b = Fraction(upper, Q96)
    physical = [root for root in roots if a < root < s < b]
    if not physical:
        return None
    return max(physical)


def integer_ratio_error_bps(left_num: int, left_den: int, right_num: int, right_den: int) -> int:
    if min(left_num, left_den, right_num, right_den) <= 0:
        return 10_000
    difference = abs(left_num * right_den - right_num * left_den)
    base = left_num * right_den
    return (difference * 10_000) // base


def forward_repair_error_bps(
    f0: int,
    f1: int,
    active: int,
    owned: int,
    sqrt_start: int,
    sqrt_target: int,
    lower: int,
    upper: int,
    fee_pips: int,
) -> dict:
    if not (lower < sqrt_target < sqrt_start < upper):
        return {"status": "outside-domain"}
    sqrt_next, amount_in, amount_out, fee_amount = compute_swap_step(
        sqrt_start, sqrt_target, active, -(10**36), fee_pips
    )
    deployed0 = get_amount0_delta(sqrt_next, upper, owned, False)
    deployed1 = get_amount1_delta(lower, sqrt_next, owned, False)
    free0 = f0 - amount_in - fee_amount
    free1 = f1 + amount_out
    if free0 < 0:
        return {"status": "insufficient-free", "amount_in": amount_in + fee_amount}
    total0 = deployed0 + free0
    total1 = deployed1 + free1
    position0 = deployed0
    position1 = deployed1
    error = integer_ratio_error_bps(total0, total1, position0, position1)
    return {
        "status": "executed",
        "sqrt_next": sqrt_next,
        "amount_in": amount_in,
        "fee_amount": fee_amount,
        "amount_out": amount_out,
        "error_bps": error,
        "total0": total0,
        "total1": total1,
    }


def cf_b_candidate(reserve_out: int, amount_out: int, supply: int) -> int:
    if amount_out > reserve_out or supply == 0 or reserve_out == 0:
        raise ValueError("domain")
    radicand = (supply * supply * (reserve_out - amount_out)) // reserve_out
    return supply - math.isqrt(radicand)


def cf_g_candidate(reserve_out: int, amount_out: int, supply: int) -> int:
    scale = 10**18
    radicand = ((reserve_out - amount_out) * scale * scale) // reserve_out
    root = math.isqrt(radicand)
    if root * root < radicand:
        root += 1
    f_wad = scale - root
    return (supply * f_wad + scale - 1) // scale


def pre_swap_shortcut_error_bps(reserve0: int, reserve1: int, amount_in: int, amount_out: int, supply: int, shares: int) -> int:
    c0 = (shares * reserve0 + supply - 1) // supply
    c1 = (shares * reserve1 + supply - 1) // supply
    post0 = reserve0 - amount_in
    post1 = reserve1 + amount_out
    required0 = (shares * post0 + supply - 1) // supply
    if required0 == 0:
        return 10_000
    return abs(c0 - required0) * 10_000 // required0
