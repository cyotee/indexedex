#!/usr/bin/env python3

from __future__ import annotations

import math
import sys
from fractions import Fraction

Q96 = 1 << 96
MIN_SQRT_PRICE = 4295128739
MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342
MIN_TICK = -887272
MAX_TICK = 887272
PERF_FEE_BPS = 500
BPS = 10_000

P0 = Fraction(1)
DISPLACED = (Fraction(2), Fraction(4))
L0 = 10**18
SHARES0 = 10**18
BUNDLE = 10**17
STATED_IDLE = 10**17
EXIT_F = Fraction(2, 3)
L_OUT = 10**18


def D(x: Fraction, places: int = 12) -> str:
    sign = "-" if x < 0 else ""
    x = abs(x)
    if x == 0:
        return "0"
    scale = 10**places
    q = (x.numerator * scale) // x.denominator
    if q == 0:
        return f"{sign}{x.numerator}/{x.denominator}"
    whole = q // scale
    frac = q % scale
    if frac == 0:
        return f"{sign}{whole}"
    return f"{sign}{whole}.{frac:0{places}d}".rstrip("0")


def fsqrt(x: Fraction) -> Fraction:
    scale = 1 << 256
    n = x.numerator * scale * scale // x.denominator
    return Fraction(math.isqrt(n), scale)


def value_at(amount0: Fraction, amount1: Fraction, price: Fraction) -> Fraction:
    return amount0 * price + amount1


def amounts_for_liquidity(liq: Fraction, price: Fraction) -> tuple[Fraction, Fraction]:
    s = fsqrt(price)
    return liq / s, liq * s


def liquidity_for_amounts(amount0: Fraction, amount1: Fraction, price: Fraction) -> Fraction:
    s = fsqrt(price)
    l0 = amount0 * s
    l1 = amount1 / s
    return l0 if l0 < l1 else l1


def place(amount0: Fraction, amount1: Fraction, price: Fraction) -> dict:
    liq = liquidity_for_amounts(amount0, amount1, price)
    s = fsqrt(price)
    placed0 = liq / s
    placed1 = liq * s
    return {
        "liq": liq,
        "placed0": placed0,
        "placed1": placed1,
        "leftover0": amount0 - placed0,
        "leftover1": amount1 - placed1,
    }


def recover(liq: Fraction, price: Fraction) -> tuple[Fraction, Fraction]:
    return amounts_for_liquidity(liq, price)


def shortfall_token1(placed0, placed1, rec0, rec1, price: Fraction) -> Fraction:
    return value_at(placed0, placed1, price) - value_at(rec0, rec1, price)


def audit_il(d_l: Fraction, price: Fraction, p0: Fraction = P0) -> Fraction:
    # IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'
    return d_l * (fsqrt(price) - fsqrt(p0)) ** 2 / fsqrt(price)


def weir_shares(liq_added: Fraction, total_shares: int, liquidity: int) -> int:
    if liquidity == 0:
        raise ZeroDivisionError("existing liquidity is zero")
    return (int(liq_added) * total_shares) // liquidity


class Pool:
    def __init__(self, liq: Fraction, price: Fraction):
        s = fsqrt(price)
        self.x = liq / s
        self.y = liq * s
        self.l = liq

    @property
    def price(self) -> Fraction:
        return self.y / self.x

    def add_liquidity(self, d_l: Fraction) -> tuple[Fraction, Fraction]:
        s = fsqrt(self.price)
        dx = d_l / s
        dy = d_l * s
        self.x += dx
        self.y += dy
        self.l += d_l
        return dx, dy

    def swap_exact_in(self, zero_for_one: bool, amount_in: Fraction) -> Fraction:
        if amount_in == 0:
            return Fraction(0)
        if zero_for_one:
            new_x = self.x + amount_in
            new_y = self.x * self.y / new_x
            out = self.y - new_y
            self.x, self.y = new_x, new_y
            return out
        new_y = self.y + amount_in
        new_x = self.x * self.y / new_y
        out = self.x - new_x
        self.x, self.y = new_x, new_y
        return out

    def move_to(self, price: Fraction) -> tuple[Fraction, Fraction]:
        s = fsqrt(price)
        x_t = self.l / s
        y_t = self.l * s
        got0 = self.x - x_t
        got1 = self.y - y_t
        self.x, self.y = x_t, y_t
        return got0, got1


def limit_sqrt_for(zero_for_one: bool) -> Fraction:
    raw = MIN_SQRT_PRICE + 1 if zero_for_one else MAX_SQRT_PRICE - 1
    return Fraction(raw, Q96)


def limit_binds(price_after: Fraction, zero_for_one: bool) -> bool:
    limit = limit_sqrt_for(zero_for_one) ** 2
    if zero_for_one:
        return price_after <= limit
    return price_after >= limit


def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def show_place(label: str, amount0: Fraction, amount1: Fraction, price: Fraction) -> dict:
    placed = place(amount0, amount1, price)
    rec0, rec1 = recover(placed["liq"], P0)
    short = shortfall_token1(placed["placed0"], placed["placed1"], rec0, rec1, P0)
    il = audit_il(placed["liq"], price)
    print(label)
    print(f"  price_sized_at {D(price)}")
    print(f"  token0_placed {D(placed['placed0'])}")
    print(f"  token1_placed {D(placed['placed1'])}")
    print(f"  token0_recovered {D(rec0)}")
    print(f"  token1_recovered {D(rec1)}")
    print(f"  leftover0 {D(placed['leftover0'])}")
    print(f"  leftover1 {D(placed['leftover1'])}")
    print(f"  liq {D(placed['liq'])}")
    print(f"  shortfall_token1_at_P0 {D(short)}")
    print(f"  audit_il {D(il)}")
    print(f"  audit_minus_direct {D(il - short)}")
    placed["rec0"] = rec0
    placed["rec1"] = rec1
    placed["shortfall"] = short
    placed["audit_il"] = il
    return placed


def case_direct() -> None:
    section("CASE 1 IDENTITY direct sizing, no swap model")
    print("Balanced-at-P0 tokens sized at P'. Recovered amounts are amounts_for_liquidity at P0.")
    print(f"bundle_each_side {BUNDLE} existing_L {L0} existing_shares {SHARES0}")
    for p in DISPLACED:
        placed = show_place(f"two_sided P'={D(p)}", Fraction(BUNDLE), Fraction(BUNDLE), p)
        new_shares = weir_shares(placed["liq"], SHARES0, L0)
        claim_l = Fraction(SHARES0, SHARES0 + new_shares) * (L0 + placed["liq"])
        print(f"  DEPOSIT shares_minted {new_shares}")
        print(f"  DEPOSIT existing_holder_liq_claim_minus_old {D(claim_l - L0)}")
        print("  COMPOUND shares_minted 0")
        print(f"  COMPOUND existing_holders_bear_shortfall {D(placed['shortfall'])}")
        print("  COMPOUND caller_bears 0")
        one0 = show_place(f"one_sided_token0 P'={D(p)}", Fraction(BUNDLE), Fraction(0), p)
        one1 = show_place(f"one_sided_token1 P'={D(p)}", Fraction(0), Fraction(BUNDLE), p)
        assert one0["liq"] == 0 and one1["liq"] == 0
        assert placed["audit_il"] == placed["shortfall"]


def case_extraction() -> None:
    section("CASE 1 CP extraction of compound placement")
    print("SWAP_MODEL infinite-range zero-fee x*y=L^2. Exact inside that limit.")
    print("IDENTITY compound swaps nothing. Live price sizes liquidity. Caller shares 0.")
    for p in DISPLACED:
        for outside in (Fraction(0), Fraction(L0)):
            pool = Pool(Fraction(L0) + outside, P0)
            got0_push, got1_push = pool.move_to(p)
            idle0, idle1 = Fraction(BUNDLE), Fraction(BUNDLE)
            placed = place(idle0, idle1, pool.price)
            dx, dy = pool.add_liquidity(placed["liq"])
            assert dx == placed["placed0"] and dy == placed["placed1"]
            got0_ret, got1_ret = pool.move_to(P0)
            attacker_pnl = value_at(got0_push + got0_ret, got1_push + got1_ret, P0)
            holder_before = value_at(*amounts_for_liquidity(Fraction(L0), P0), P0) + value_at(idle0, idle1, P0)
            holder_after = (
                value_at(*amounts_for_liquidity(Fraction(L0) + placed["liq"], P0), P0)
                + value_at(placed["leftover0"], placed["leftover1"], P0)
            )
            holder_loss = holder_before - holder_after
            direct = shortfall_token1(placed["placed0"], placed["placed1"], *recover(placed["liq"], P0), P0)
            print(f"P'={D(p)} outside_L={D(outside)}")
            print(f"  attacker_pnl_token1 {D(attacker_pnl)}")
            print(f"  holder_loss_token1 {D(holder_loss)}")
            print(f"  direct_shortfall {D(direct)}")
            print(f"  attacker_minus_holder_loss {D(attacker_pnl - holder_loss)}")
            assert attacker_pnl == holder_loss
            assert holder_loss == direct


def case_deposit_roundtrip() -> None:
    section("CASE 1 CP deposit after an external push, no _balance swap")
    print("SWAP_MODEL infinite-range zero-fee. Excess refunded, not booked as idle.")
    for p in DISPLACED:
        pool = Pool(Fraction(L0), P0)
        atk0, atk1 = pool.move_to(p)
        bundle0, bundle1 = Fraction(BUNDLE), Fraction(BUNDLE)
        placed = place(bundle0, bundle1, pool.price)
        pool.add_liquidity(placed["liq"])
        ret0, ret1 = pool.move_to(P0)
        attacker_pnl = value_at(atk0 + ret0, atk1 + ret1, P0)
        new_shares = Fraction(placed["liq"]) * SHARES0 / L0
        total_after = Fraction(SHARES0) + new_shares
        pos = value_at(*amounts_for_liquidity(Fraction(L0) + placed["liq"], P0), P0)
        depositor_position = (new_shares / total_after) * pos
        holder_position = (Fraction(SHARES0) / total_after) * pos
        holder_before = value_at(*amounts_for_liquidity(Fraction(L0), P0), P0)
        depositor_pnl = depositor_position + value_at(placed["leftover0"], placed["leftover1"], P0) - value_at(bundle0, bundle1, P0)
        holder_pnl = holder_position - holder_before
        floor_shares = weir_shares(placed["liq"], SHARES0, L0)
        print(f"P'={D(p)}")
        print(f"  attacker_pnl {D(attacker_pnl)}")
        print(f"  depositor_pnl {D(depositor_pnl)}")
        print(f"  existing_holder_pnl {D(holder_pnl)}")
        print(f"  sum {D(attacker_pnl + depositor_pnl + holder_pnl)}")
        print(f"  floor_shares {floor_shares}")
        print(f"  floor_share_dust_vs_rational {D(Fraction(floor_shares) - new_shares)}")
        assert holder_pnl == 0
        assert attacker_pnl + depositor_pnl == 0


def case_self_moved() -> None:
    section("CASE 2 self-moved trailing placement")
    print(f"exit_fraction {D(EXIT_F)} stated_idle_each {STATED_IDLE}")
    print("IDENTITY zapTo=2 swaps withdrawn token0 plus pro-rata idle0.")
    print("IDENTITY _compound is before _withdraw, so the trailing mint is a later call.")
    print("SWAP_MODEL price after that exact-in is the zero-fee infinite-range price.")
    liquidity = Fraction(L0)
    f = EXIT_F
    idle0 = Fraction(STATED_IDLE)
    idle1 = Fraction(STATED_IDLE)
    pool = Pool(liquidity, P0)
    liq_out = f * liquidity
    i0_out = f * idle0
    i1_out = f * idle1
    removed0, removed1 = amounts_for_liquidity(liq_out, P0)
    net0 = removed0 + i0_out
    pool.l -= liq_out
    pool.x -= removed0
    pool.y -= removed1
    remaining_idle0 = idle0 - i0_out
    remaining_idle1 = idle1 - i1_out
    whole_opposing = net0 + pool.x + remaining_idle0
    print(f"IDENTITY swap_amount_token0 {D(net0)}")
    print(f"IDENTITY withdrawn_position_token0 {D(removed0)}")
    print(f"IDENTITY pro_rata_idle0 {D(i0_out)}")
    print(f"IDENTITY whole_opposing_token0 {D(whole_opposing)}")
    print(f"IDENTITY swap_minus_whole {D(net0 - whole_opposing)}")
    print(f"IDENTITY remaining_position_token0_not_swapped {D(pool.x)}")
    print(f"IDENTITY remaining_idle0_not_swapped {D(remaining_idle0)}")
    pool.swap_exact_in(True, net0)
    p_after = pool.price
    print(f"CP price_after_withdraw_swap {D(p_after)}")
    print(f"CP limit_binds {limit_binds(p_after, True)}")
    print(f"CP sqrt_limit {D(limit_sqrt_for(True))}")
    stayer_l = liquidity * (1 - f)
    fair_idle = value_at(remaining_idle0, remaining_idle1, P0)
    fair_stayer = value_at(*amounts_for_liquidity(stayer_l, P0), P0) + fair_idle
    print(f"CONTROL no_compound stayer_value_at_P0 {D(fair_stayer)}")
    print("CONTROL stayer_loss 0")
    placed = place(remaining_idle0, remaining_idle1, p_after)
    pool.add_liquidity(placed["liq"])
    pool.move_to(P0)
    stayer_after = value_at(*amounts_for_liquidity(pool.l, P0), P0) + value_at(placed["leftover0"], placed["leftover1"], P0)
    rec0, rec1 = recover(placed["liq"], P0)
    short = shortfall_token1(placed["placed0"], placed["placed1"], rec0, rec1, P0)
    print(f"trailing_liq {D(placed['liq'])}")
    print(f"trailing_token0_placed {D(placed['placed0'])}")
    print(f"trailing_token1_placed {D(placed['placed1'])}")
    print(f"trailing_token0_recovered {D(rec0)}")
    print(f"trailing_token1_recovered {D(rec1)}")
    print(f"trailing_shortfall_token1 {D(short)}")
    print(f"stayer_value_at_P0 {D(stayer_after)}")
    print(f"stayer_loss_vs_no_compound {D(fair_stayer - stayer_after)}")
    print("shares_minted_by_compound 0")
    print(f"DUST both_sides_2 liq {D(place(Fraction(2), Fraction(2), p_after)['liq'])}")
    print("DUST source_skips_when_both_sides_le_2")
    assert fair_stayer - stayer_after == short
    assert net0 < whole_opposing
    assert pool.l == stayer_l + placed["liq"]


def case_whole_balance() -> None:
    section("CASE 3 whole-balance dump versus Weir withdraw")
    print(f"exit_fraction {D(EXIT_F)} idle 0")
    print("Same absolute limit: MIN_SQRT_PRICE+1 for zeroForOne.")
    f = EXIT_F
    liquidity = Fraction(L0)
    removed0, _removed1 = amounts_for_liquidity(f * liquidity, P0)
    weir_stayer = value_at(*amounts_for_liquidity(liquidity * (1 - f), P0), P0)
    print(f"IDENTITY weir_swap_amount_token0 {D(removed0)}")
    print(f"IDENTITY shape_024_swap_amount_token0 {D(liquidity)}")
    print(f"IDENTITY stayer_token0_in_024_not_in_weir {D(liquidity - removed0)}")
    print(f"IDENTITY weir_stayer_value_at_P0 {D(weir_stayer)}")
    print("IDENTITY weir_stayer_loss 0")
    for outside in (Fraction(0), Fraction(L_OUT)):
        print(f"-- outside_L {D(outside)}")
        if outside == 0:
            print("  024_executable 0")
            print("  reason closing the only liquidity leaves no counterparty")
            print(f"  weir_stayer_value_after_return {D(weir_stayer)}")
            print("  weir_stayer_loss 0")
            continue
        outside_pool = Pool(outside, P0)
        vault0, vault1 = amounts_for_liquidity(liquidity, P0)
        out1 = outside_pool.swap_exact_in(True, vault0)
        p_after = outside_pool.price
        post_value = value_at(Fraction(0), vault1 + out1, P0)
        fair = value_at(vault0, vault1, P0)
        total_loss = fair - post_value
        stayer_loss = (1 - f) * total_loss
        back0, back1 = outside_pool.move_to(P0)
        back_pnl = value_at(back0, back1, P0)
        print(f"  CP 024_price_after {D(p_after)}")
        print(f"  CP limit_binds {limit_binds(p_after, True)}")
        print(f"  CP 024_token1_out {D(out1)}")
        print(f"  CP 024_total_loss_at_P0 {D(total_loss)}")
        print(f"  CP 024_stayer_value_pro_rata {D((1 - f) * post_value)}")
        print(f"  CP 024_stayer_loss_pro_rata {D(stayer_loss)}")
        print(f"  CP weir_stayer_value {D(weir_stayer)}")
        print("  CP weir_stayer_loss 0")
        print(f"  CP stayer_gap_024_minus_weir {D(stayer_loss)}")
        print(f"  CP backrunner_pnl {D(back_pnl)}")
        print(f"  CP backrunner_minus_total_loss {D(back_pnl - total_loss)}")
        assert back_pnl == total_loss
        assert stayer_loss > 0


def half_excess(a0: Fraction, a1: Fraction, price: Fraction) -> tuple[str, Fraction]:
    a0_in_1 = a0 * price
    if a0_in_1 > a1:
        return "zeroForOne", (a0 - a1 / price) / 2
    if a1 > a0_in_1:
        return "oneForZero", (a1 - a0_in_1) / 2
    return "none", Fraction(0)


def case_balance() -> None:
    section("CASE 4 half-excess _balance")
    print("IDENTITY x is half the caller's excess at the live spot. Holder balances are not inputs.")
    print("SWAP_MODEL the swap's price impact, then the mint, then a return to P0.")
    for p in DISPLACED:
        direction, amount = half_excess(Fraction(BUNDLE), Fraction(BUNDLE), p)
        print(f"P'={D(p)} direction {direction} half_excess {D(amount)}")
        print(f"  half_excess_over_caller_input0 {D(amount / BUNDLE)}")
        print("  uses_existing_holder_balance 0")
        print("  compared_with_P0 0")
        pool = Pool(Fraction(L0), P0)
        atk0, atk1 = pool.move_to(p)
        if direction == "zeroForOne":
            out = pool.swap_exact_in(True, amount)
            n0 = Fraction(BUNDLE) - amount
            n1 = Fraction(BUNDLE) + out
        else:
            out = pool.swap_exact_in(False, amount)
            n0 = Fraction(BUNDLE) + out
            n1 = Fraction(BUNDLE) - amount
        p_post = pool.price
        placed = place(n0, n1, p_post)
        pool.add_liquidity(placed["liq"])
        ret0, ret1 = pool.move_to(P0)
        attacker_pnl = value_at(atk0 + ret0, atk1 + ret1, P0)
        new_shares = Fraction(placed["liq"]) * SHARES0 / L0
        total = Fraction(SHARES0) + new_shares
        pos_value = value_at(*amounts_for_liquidity(Fraction(L0) + placed["liq"], P0), P0)
        holder_after = (Fraction(SHARES0) / total) * pos_value
        holder_before = value_at(*amounts_for_liquidity(Fraction(L0), P0), P0)
        caller_pnl = (new_shares / total) * pos_value + value_at(placed["leftover0"], placed["leftover1"], P0) - value_at(Fraction(BUNDLE), Fraction(BUNDLE), P0)
        rec0, rec1 = recover(placed["liq"], P0)
        print(f"  post_swap_price {D(p_post)}")
        print("  sized_at_post_swap_price 1")
        print(f"  token0_placed {D(placed['placed0'])}")
        print(f"  token1_placed {D(placed['placed1'])}")
        print(f"  token0_recovered {D(rec0)}")
        print(f"  token1_recovered {D(rec1)}")
        print(f"  shortfall_of_placed_at_P0 {D(shortfall_token1(placed['placed0'], placed['placed1'], rec0, rec1, P0))}")
        print(f"  attacker_pnl {D(attacker_pnl)}")
        print(f"  caller_pnl {D(caller_pnl)}")
        print(f"  existing_holder_pnl {D(holder_after - holder_before)}")
        print(f"  sum {D(attacker_pnl + caller_pnl + holder_after - holder_before)}")
        assert holder_after == holder_before
        assert attacker_pnl + caller_pnl == 0


def solidity_muldiv(a: int, b: int, den: int) -> int:
    return a * b // den


def solidity_balance(a0: int, a1: int, sqrt_p: int) -> tuple[str, int]:
    a0in1 = solidity_muldiv(solidity_muldiv(a0, sqrt_p, Q96), sqrt_p, Q96)
    if a0in1 > a1:
        a1_as_0 = solidity_muldiv(solidity_muldiv(a1, Q96, sqrt_p), Q96, sqrt_p)
        return "zeroForOne", (a0 - a1_as_0) // 2
    if a1 > a0in1:
        return "oneForZero", (a1 - a0in1) // 2
    return "none", 0


def amount0_finite(sqrt_a: int, sqrt_b: int, liq: int) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    return solidity_muldiv(liq << 96, sqrt_b - sqrt_a, sqrt_b) // sqrt_a


def amount1_finite(sqrt_a: int, sqrt_b: int, liq: int) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    return solidity_muldiv(liq, sqrt_b - sqrt_a, Q96)


def liq_for_amount0(sqrt_a: int, sqrt_b: int, amount: int) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    intermediate = solidity_muldiv(sqrt_a, sqrt_b, Q96)
    return solidity_muldiv(amount, intermediate, sqrt_b - sqrt_a)


def liq_for_amount1(sqrt_a: int, sqrt_b: int, amount: int) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    return solidity_muldiv(amount, Q96, sqrt_b - sqrt_a)


def finite_liquidity(amount0: int, amount1: int, sqrt_p: int, sqrt_a: int, sqrt_b: int) -> int:
    if sqrt_p <= sqrt_a:
        return liq_for_amount0(sqrt_a, sqrt_b, amount0)
    if sqrt_p >= sqrt_b:
        return liq_for_amount1(sqrt_a, sqrt_b, amount1)
    l0 = liq_for_amount0(sqrt_p, sqrt_b, amount0)
    l1 = liq_for_amount1(sqrt_a, sqrt_p, amount1)
    return l0 if l0 < l1 else l1


def case_integer_and_finite() -> None:
    section("INTEGER source formula and finite-tick sensitivity")
    print("Not mixed into the fixture totals above.")
    sqrt_p4 = 2 * Q96
    direction, amount = solidity_balance(BUNDLE, BUNDLE, sqrt_p4)
    _rational_dir, rational_x = half_excess(Fraction(BUNDLE), Fraction(BUNDLE), Fraction(4))
    print(f"solidity_balance P=4 direction {direction} x {amount}")
    print(f"rational_balance P=4 x {D(rational_x)}")
    print(f"wei_difference {amount - int(rational_x)}")
    shares = weir_shares(Fraction(10**17), SHARES0, L0)
    print(f"solidity_shares liq=1e17 {shares}")
    print("idle_in_denominator 0")
    print("deposit_subtracts_2_wei_before_liquidity_for_amounts")
    print("compound_skips_when_both_sides_le_2")
    print(f"tickSpacing_1 minUsableTick {(MIN_TICK // 1) * 1} maxUsableTick {(MAX_TICK // 1) * 1}")
    print(f"MIN_SQRT_PRICE {MIN_SQRT_PRICE}")
    print(f"MAX_SQRT_PRICE {MAX_SQRT_PRICE}")
    liq = 10**24
    finite0 = amount0_finite(Q96, MAX_SQRT_PRICE, liq)
    finite1 = amount1_finite(MIN_SQRT_PRICE, Q96, liq)
    print(f"finite_amount0_at_P1 {finite0}")
    print(f"finite_amount1_at_P1 {finite1}")
    print(f"missing0_vs_infinite {liq - finite0}")
    print(f"missing1_vs_infinite {liq - finite1}")
    print(f"relative_missing0 {D(Fraction(liq - finite0, liq), 24)}")
    sqrt_p2 = math.isqrt(2 * Q96 * Q96)
    for name, sqrt_p in (("P2_floor", sqrt_p2), ("P4_exact", sqrt_p4)):
        liq_from_0 = finite_liquidity(10**24, 0, sqrt_p, MIN_SQRT_PRICE, MAX_SQRT_PRICE)
        liq_from_1 = finite_liquidity(0, 10**24, sqrt_p, MIN_SQRT_PRICE, MAX_SQRT_PRICE)
        print(f"finite_one_sided {name} liq_from_token0 {liq_from_0} liq_from_token1 {liq_from_1}")
        assert liq_from_0 == 0 and liq_from_1 == 0
    a0 = 10**24
    a1 = 10**24
    liq_f = finite_liquidity(a0, a1, sqrt_p4, MIN_SQRT_PRICE, MAX_SQRT_PRICE)
    used0 = amount0_finite(sqrt_p4, MAX_SQRT_PRICE, liq_f)
    used1 = amount1_finite(MIN_SQRT_PRICE, sqrt_p4, liq_f)
    rec0 = amount0_finite(Q96, MAX_SQRT_PRICE, liq_f)
    rec1 = amount1_finite(MIN_SQRT_PRICE, Q96, liq_f)
    short_f = (used0 + used1) - (rec0 + rec1)
    inf = place(Fraction(a0), Fraction(a1), Fraction(4))
    inf_rec0, inf_rec1 = recover(inf["liq"], P0)
    inf_short = shortfall_token1(inf["placed0"], inf["placed1"], inf_rec0, inf_rec1, P0)
    print(f"finite_P4 liq {liq_f}")
    print(f"finite_P4 placed0 {used0}")
    print(f"finite_P4 placed1 {used1}")
    print(f"finite_P4 recovered0 {rec0}")
    print(f"finite_P4 recovered1 {rec1}")
    print(f"finite_P4 shortfall {short_f}")
    print(f"infinite_P4 shortfall {D(inf_short)}")
    gap = Fraction(short_f) - inf_short
    print(f"finite_minus_infinite_shortfall {D(gap)}")
    print(f"relative_shortfall_gap {D(abs(gap) / inf_short, 18)}")


def case_fee() -> None:
    section("FEE CUT labeled, not a principal case")
    print(f"perfFeeBps default {PERF_FEE_BPS} of harvested fees only")
    fees0, fees1 = Fraction(BUNDLE), Fraction(BUNDLE)
    cut0 = fees0 * PERF_FEE_BPS / BPS
    cut1 = fees1 * PERF_FEE_BPS / BPS
    rest0, rest1 = fees0 - cut0, fees1 - cut1
    print(f"treasury_cut0 {D(cut0)} treasury_cut1 {D(cut1)}")
    for p in DISPLACED:
        placed = place(rest0, rest1, p)
        rec0, rec1 = recover(placed["liq"], P0)
        short = shortfall_token1(placed["placed0"], placed["placed1"], rec0, rec1, P0)
        print(f"P'={D(p)} holder_shortfall_on_fee_remainder {D(short)}")
        print("  shares_minted 0")


def main() -> int:
    print("model infinite-range limit of LiquidityAmounts")
    print("createVault ticks not used in fixture totals")
    print(f"P0 {D(P0)} displaced 2 4")
    print(f"existing_liquidity {L0} existing_shares {SHARES0}")
    print("idle_in_share_denominator 0")
    print("twap_read 0 fee_cap 0 tick_bound 0 exit_fee 0")
    print("pool_fee_in_model 0")
    case_direct()
    case_extraction()
    case_deposit_roundtrip()
    case_self_moved()
    case_whole_balance()
    case_balance()
    case_integer_and_finite()
    case_fee()
    section("CHECKS")
    print("all_asserts_passed 1")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError:
        print("ASSERT_FAIL")
        raise
