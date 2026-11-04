#!/usr/bin/env python3
"""
model.py -- independent witness for the MiniMax member of the v4-swaps independent redo.

QUESTION
    Under the premise that the target/opposing pair has exactly one liquidity venue and
    this pool's TWAP is the only available reference, do ACTUAL entry swaps and
    PROPORTIONAL-SLICE exit swaps eliminate APEX-012 (manipulation-induced ownership
    dilution / reserve extraction) for

        contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/

SCOPE
    * Standalone integer arithmetic. No EVM, no project build/test, no network, no
      deployment, no git. This file is a model, not a Foundry test.
    * The pool is a SINGLE WIDE RANGE Uniswap-V4 pool: every position is full range and
      the price stays inside the range. Inside one range v4-core is exactly a
      constant-product AMM over virtual reserves, so the swap math below is the real
      v4-core math (TickMath.getSqrtPriceAtTick, SwapMath.computeSwapStep,
      SqrtPriceMath.getAmount{0,1}Delta), not a simplification of it.
    * The vault keeps the Wings book shape: local custody plus one core full-range
      position. The Wings liquidation quote is reproduced in its essential steps:
      collect own principal, then simulate selling ALL opposing inventory through the
      remaining external liquidity starting from the live price, with pool swap fees.
    * NOT reproduced: the upper/lower wings, fee growth, harvest/rebalance scheduling,
      the 512-step quote cap, and the exact post-rebalance state of the audit PoC.
      Numbers here witness MECHANISM and closed-form identities; the audit's measured
      figures are quoted separately as production evidence.
    * Fixture scale follows the production test base: token0 6 decimals, token1 18
      decimals, fee 3000, tick spacing 60, hookless, pool initialized at sqrtP = 2**96
      (raw 1:1). Amounts are raw token units.

RUN
    python3 model.py
"""

from __future__ import annotations

Q96 = 1 << 96
MIN_SQRT_PRICE = 4295128739
MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342
MIN_TICK = -887272
MAX_TICK = 887272
FEE_PIPS = 3000
UNIT = 1_000_000
TARGET0 = True


def mul_div(a: int, b: int, c: int) -> int:
    return (a * b) // c


def mul_div_rounding_up(a: int, b: int, c: int) -> int:
    return (a * b + c - 1) // c


def div_rounding_up(a: int, b: int) -> int:
    return (a + b - 1) // b


_TICK_CONSTANTS = [
    (0x1, 0xfffcb933bd6fad37aa2d162d1a594001),
    (0x2, 0xfff97272373d413259a46990580e213a),
    (0x4, 0xfff2e50f5f656932ef12357cf3c7fdcc),
    (0x8, 0xffe5caca7e10e4e61c3624eaa0941cd0),
    (0x10, 0xffcb9843d60f6159c9db58835c926644),
    (0x20, 0xff973b41fa98c081472e6896dfb254c0),
    (0x40, 0xff2ea16466c96a3843ec78b326b52861),
    (0x80, 0xfe5dee046a99a2a811c461f1969c3053),
    (0x100, 0xfcbe86c7900a88aedcffc83b479aa3a4),
    (0x200, 0xf987a7253ac413176f2b074cf7815e54),
    (0x400, 0xf3392b0822b70005940c7a398e4b70f3),
    (0x800, 0xe7159475a2c29b7443b29c7fa6e889d9),
    (0x1000, 0xd097f3bdfd2022b8845ad8f792aa5825),
    (0x2000, 0xa9f746462d870fdf8a65dc1f90e061e5),
    (0x4000, 0x70d869a156d2a1b890bb3df62baf32f7),
    (0x8000, 0x31be135f97d08fd981231505542fcfa6),
    (0x10000, 0x9aa508b5b7a84e1c677de54f3e99bc9),
    (0x20000, 0x5d6af8dedb81196699c329225ee604),
    (0x40000, 0x2216e584f5fa1ea926041bedfe98),
    (0x80000, 0x48a170391f7dc42444e8fa2),
]


def get_sqrt_price_at_tick(tick: int) -> int:
    abs_tick = -tick if tick < 0 else tick
    if abs_tick > MAX_TICK:
        raise ValueError("tick out of range")
    ratio = 0x100000000000000000000000000000000
    for bit, const in _TICK_CONSTANTS:
        if abs_tick & bit:
            ratio = (ratio * const) >> 128
    if tick > 0:
        ratio = (1 << 256) // ratio
    sqrt_price = (ratio >> 32) + (1 if (ratio % (1 << 32)) else 0)
    return min(sqrt_price, MAX_SQRT_PRICE)


def get_tick_at_sqrt_price(sqrt_price: int) -> int:
    lo, hi = MIN_TICK, MAX_TICK
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if get_sqrt_price_at_tick(mid) <= sqrt_price:
            lo = mid
        else:
            hi = mid - 1
    return lo


def get_amount0_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    numerator1 = liquidity << 96
    numerator2 = sqrt_b - sqrt_a
    if round_up:
        return div_rounding_up(mul_div_rounding_up(numerator1, numerator2, sqrt_b), sqrt_a)
    return mul_div(numerator1, numerator2, sqrt_b) // sqrt_a


def get_amount1_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    if round_up:
        return mul_div_rounding_up(liquidity, sqrt_b - sqrt_a, Q96)
    return mul_div(liquidity, sqrt_b - sqrt_a, Q96)


def get_next_sqrt_price_from_input(sqrt_p: int, liquidity: int, amount_in: int, zero_for_one: bool) -> int:
    if zero_for_one:
        numerator1 = liquidity << 96
        if amount_in == 0:
            return sqrt_p
        product = amount_in * sqrt_p
        if product // amount_in == sqrt_p:
            denominator = numerator1 + product
            if denominator >= numerator1:
                return mul_div_rounding_up(numerator1, sqrt_p, denominator)
        return div_rounding_up(numerator1, numerator1 // sqrt_p + amount_in)
    if amount_in <= MAX_SQRT_PRICE:
        quotient = (amount_in << 96) // liquidity
    else:
        quotient = mul_div(amount_in, Q96, liquidity)
    return sqrt_p + quotient


def swap_step(sqrt_p: int, liquidity: int, fee_pips: int, zero_for_one: bool,
              amount_in: int, price_limit: int):
    """One exact-input step inside a single range.

    Returns (sqrt_p_next, gross_input_consumed, amount_out, fee_paid). When the price
    limit binds, only the input needed to reach the limit is consumed, as in v4-core.
    """
    if amount_in == 0 or liquidity == 0:
        return sqrt_p, 0, 0, 0
    amount_less_fee = mul_div(amount_in, UNIT - fee_pips, UNIT)
    sqrt_next = get_next_sqrt_price_from_input(sqrt_p, liquidity, amount_less_fee, zero_for_one)
    limited = False
    if zero_for_one:
        if sqrt_next < price_limit:
            net = get_amount0_delta(price_limit, sqrt_p, liquidity, True)
            out = get_amount1_delta(price_limit, sqrt_p, liquidity, False)
            sqrt_next = price_limit
            limited = True
        else:
            net = amount_less_fee
            out = get_amount1_delta(sqrt_next, sqrt_p, liquidity, False)
    else:
        if sqrt_next > price_limit:
            net = get_amount1_delta(sqrt_p, price_limit, liquidity, True)
            out = get_amount0_delta(sqrt_p, price_limit, liquidity, False)
            sqrt_next = price_limit
            limited = True
        else:
            net = amount_less_fee
            out = get_amount0_delta(sqrt_p, sqrt_next, liquidity, False)
    if limited:
        gross = net + mul_div_rounding_up(net, fee_pips, UNIT - fee_pips)
    else:
        gross = amount_in
    return sqrt_next, gross, out, gross - net


class Pool:
    """Single wide range V4 pool; all positions are full range."""

    def __init__(self, fee_pips: int = FEE_PIPS) -> None:
        self.fee = fee_pips
        self.sqrt_p = Q96
        self.positions: dict[str, int] = {}

    def add(self, name: str, liquidity: int) -> None:
        self.positions[name] = self.positions.get(name, 0) + liquidity

    def remove(self, name: str, liquidity: int) -> None:
        self.positions[name] = self.positions.get(name, 0) - liquidity

    def liquidity(self) -> int:
        return sum(self.positions.values())

    def tick(self) -> int:
        return get_tick_at_sqrt_price(self.sqrt_p)

    def reserves(self) -> tuple[int, int]:
        x = y = 0
        for liq in self.positions.values():
            a0, a1 = full_range_amounts(liq, self.sqrt_p)
            x += a0
            y += a1
        return x, y

    def swap_exact_in(self, zero_for_one: bool, amount_in: int, price_limit: int | None = None):
        if price_limit is None:
            price_limit = MIN_SQRT_PRICE + 1 if zero_for_one else MAX_SQRT_PRICE - 1
        sqrt_next, gross, out, fee = swap_step(self.sqrt_p, self.liquidity(), self.fee,
                                               zero_for_one, amount_in, price_limit)
        self.sqrt_p = sqrt_next
        return gross, out, fee

    def simulate_exact_in(self, zero_for_one: bool, amount_in: int, price_limit: int | None = None):
        if price_limit is None:
            price_limit = MIN_SQRT_PRICE + 1 if zero_for_one else MAX_SQRT_PRICE - 1
        sqrt_next, gross, out, fee = swap_step(self.sqrt_p, self.liquidity(), self.fee,
                                               zero_for_one, amount_in, price_limit)
        return gross, out, fee, sqrt_next

    def push_to_tick(self, zero_for_one: bool, target_tick: int):
        """Move the price to `target_tick` with a price limit; returns (consumed, out, fee)."""
        limit = get_sqrt_price_at_tick(target_tick)
        x, y = self.reserves()
        max_in = (x if zero_for_one else y) * 20 + 10 ** 18
        return self.swap_exact_in(zero_for_one, max_in, limit)


def full_range_amounts(liquidity: int, sqrt_p: int) -> tuple[int, int]:
    amount0 = mul_div(liquidity << 96, MAX_SQRT_PRICE - sqrt_p, MAX_SQRT_PRICE) // sqrt_p
    amount1 = mul_div(liquidity, sqrt_p - MIN_SQRT_PRICE, Q96)
    return amount0, amount1


class Vault:
    """Wings book: local custody plus one core full-range position; target is currency0."""

    def __init__(self, core_liquidity: int, local0: int = 0, local1: int = 0, supply: int = 0) -> None:
        self.core_liquidity = core_liquidity
        self.local0 = local0
        self.local1 = local1
        self.supply = supply

    @staticmethod
    def issue(supply: int, value: int, credit: int) -> int:
        if credit == 0:
            raise ValueError("ZeroIssue")
        if supply != 0 and value == 0:
            raise ValueError("InvalidAccountingState")
        shares = credit if supply == 0 else mul_div(supply, credit, value)
        if shares == 0:
            raise ValueError("ZeroIssue")
        return shares

    @staticmethod
    def entitlement(supply: int, value: int, shares: int) -> int:
        if supply == 0 or shares > supply:
            raise ValueError("InvalidAccountingState")
        return mul_div(shares, value, supply)

    def quote(self, pool: Pool) -> dict:
        """Whole-book hypothetical liquidation into the target token."""
        own = self.core_liquidity
        ext_liquidity = pool.liquidity() - own
        d0, d1 = full_range_amounts(own, pool.sqrt_p)
        local0 = self.local0 + d0
        local1 = self.local1 + d1
        target_total = local0 if TARGET0 else local1
        opposing_total = local1 if TARGET0 else local0
        zero_for_one = not TARGET0
        proceeds = 0
        sold = 0
        unsold = opposing_total
        sqrt_q = pool.sqrt_p
        limit = MIN_SQRT_PRICE + 1 if zero_for_one else MAX_SQRT_PRICE - 1
        while unsold > 0 and sqrt_q != limit:
            consumed, out, _fee, sqrt_next = pool.simulate_exact_in(zero_for_one, unsold, limit)
            if consumed == 0:
                break
            sold += consumed
            proceeds += out
            unsold -= consumed
            sqrt_q = sqrt_next
        return {
            "value": target_total + proceeds,
            "proceeds": proceeds,
            "sold": sold,
            "unsold": unsold,
            "target_total": target_total,
            "opposing_total": opposing_total,
            "ext_liquidity": ext_liquidity,
        }

    def book_totals(self, pool: Pool) -> tuple[int, int]:
        d0, d1 = full_range_amounts(self.core_liquidity, pool.sqrt_p)
        return self.local0 + d0, self.local1 + d1


def restore_to_tick(pool: Pool, target_tick: int):
    """Move the price back to `target_tick` in whichever direction is required."""
    if pool.tick() > target_tick:
        return pool.push_to_tick(True, target_tick)
    return pool.push_to_tick(False, target_tick)


def executed_entry_swap(vault: Vault, pool: Pool, target_in: int):
    """Rebalance the vault's target/opposing mix by swapping target for opposing.

    The swap size keeps the book's ratio, so the depositor's net contribution ends up
    proportional to the book's vector. Returns (target_sold, opposing_received, fee,
    executed_price) with executed_price = opposing received per target sold.
    """
    t0, t1 = vault.book_totals(pool)
    if t0 == 0 or t1 == 0:
        return 0, 0, 0, 0.0
    sqrt_sq = pool.sqrt_p * pool.sqrt_p
    target_to_swap = (target_in * t1 * sqrt_sq) // (t1 * sqrt_sq + t0 * Q96 * Q96)
    if target_to_swap > t0:
        target_to_swap = t0
    if target_to_swap == 0:
        return 0, 0, 0, 0.0
    consumed, out, fee, _ = pool.simulate_exact_in(True, target_to_swap, MIN_SQRT_PRICE + 1)
    return consumed, out, fee, (out / consumed if consumed else 0.0)


def executed_exit_slice(vault: Vault, pool: Pool, target_needed: int,
                        whole_balance_dump: bool = False, limit_ticks: int | None = None):
    """Slice settlement of a redemption, executed against the pool.

    Inventory cutoff: pay from local target first, then remove a proportional slice of
    the core and convert only what the slice provides. With whole_balance_dump=True the
    conversion is replaced by the vault's whole opposing balance, which is the shape of
    the current Wings `_swapDeficit`. With limit_ticks set the conversion carries a price
    limit, and an unfunded deficit is reported instead of being filled.
    """
    led = {"local_paid": 0, "core_removed": 0, "target_sold": 0, "proceeds": 0,
           "fee": 0, "sqrt_before": pool.sqrt_p, "sqrt_after": pool.sqrt_p,
           "retained": 0, "shortfall": 0}
    remaining = target_needed
    local_target = vault.local0 if TARGET0 else vault.local1
    pay = min(local_target, remaining)
    led["local_paid"] = pay
    if TARGET0:
        vault.local0 -= pay
    else:
        vault.local1 -= pay
    remaining -= pay
    if remaining == 0:
        return led
    d0, d1 = full_range_amounts(vault.core_liquidity, pool.sqrt_p)
    target_principal = d0 if TARGET0 else d1
    if target_principal == 0:
        led["shortfall"] = remaining
        return led
    frac = div_rounding_up(remaining * Q96, target_principal)
    if frac > Q96:
        frac = Q96
    liq_removed = (vault.core_liquidity * frac) // Q96
    if liq_removed == 0:
        led["shortfall"] = remaining
        return led
    vault.core_liquidity -= liq_removed
    pool.remove("vault_core", liq_removed)
    r0, r1 = full_range_amounts(liq_removed, pool.sqrt_p)
    vault.local0 += r0
    vault.local1 += r1
    slice_target = r0 if TARGET0 else r1
    slice_opposing = r1 if TARGET0 else r0
    led["core_removed"] = liq_removed
    remaining -= slice_target
    if remaining <= 0:
        led["retained"] = slice_target
        return led
    zero_for_one = not TARGET0
    if whole_balance_dump:
        amount_in = vault.local1 if TARGET0 else vault.local0
    else:
        amount_in = slice_opposing
    if amount_in == 0:
        led["shortfall"] = remaining
        return led
    if limit_ticks is None:
        limit = MIN_SQRT_PRICE + 1 if zero_for_one else MAX_SQRT_PRICE - 1
    else:
        limit = get_sqrt_price_at_tick(pool.tick() + (limit_ticks if not zero_for_one else -limit_ticks))
    consumed, out, fee = pool.swap_exact_in(zero_for_one, amount_in, limit)
    led["target_sold"] = consumed
    led["proceeds"] = out
    led["fee"] = fee
    led["sqrt_after"] = pool.sqrt_p
    if TARGET0:
        vault.local1 -= consumed
        vault.local0 += out
    else:
        vault.local0 -= consumed
        vault.local1 += out
    led["shortfall"] = max(0, remaining - out)
    return led


class Ledger:
    def __init__(self, label: str) -> None:
        self.label = label
        self.rows: list[tuple[str, str, str]] = []

    def row(self, k: str, v: str, note: str = "") -> None:
        self.rows.append((k, v, note))

    def show(self) -> None:
        print(f"\n  === {self.label} ===")
        for k, v, note in self.rows:
            print(f"    {k:<46} {v:>30}  {note}")


def hr(title: str) -> None:
    print("\n" + "=" * 104)
    print(title)
    print("=" * 104)


def build_state(sleeve: int = 1_100_000_000_000):
    pool = Pool()
    pool.add("external", 1_000_000_000_000)
    vault = Vault(core_liquidity=500_000_000_000, local0=sleeve, local1=0,
                  supply=1_000_000_000_000)
    pool.add("vault_core", vault.core_liquidity)
    return pool, vault


def s0_selfcheck() -> None:
    hr("S0  self-checks: TickMath anchors and round trip, pool reserves, swap direction")
    assert get_sqrt_price_at_tick(0) == Q96
    assert get_sqrt_price_at_tick(MAX_TICK) == MAX_SQRT_PRICE
    assert get_sqrt_price_at_tick(MIN_TICK) == MIN_SQRT_PRICE
    for t in (-887220, -60000, -1, 0, 1, 60, 60000, 887220):
        assert get_tick_at_sqrt_price(get_sqrt_price_at_tick(t)) == t
    print("  TickMath anchors ok; tick round trip ok")
    p1 = get_sqrt_price_at_tick(200)
    print(f"  +200 ticks (the audit front-run size) is a price factor of {(p1 / Q96) ** 2:.6f}")
    pool = Pool()
    pool.add("ext", 1_000_000_000_000)
    x, y = pool.reserves()
    print(f"  pool reserves at raw 1:1 -> token0 {x}, token1 {y}")
    gross, out, fee = pool.swap_exact_in(False, 10 ** 10)
    x2, y2 = pool.reserves()
    print(f"  swap token1->token0: consumed {gross} (fee {fee}) out {out}; "
          f"reserves {x2}/{y2}; tick {pool.tick()}")
    assert out > 0 and fee > 0 and x2 < x and y2 > y


def s1_jit_quote_priced() -> None:
    hr("S1  APEX-012 as implemented: quote-priced mint, quote-priced payout, JIT depth")
    pool, vault = build_state()
    D = 1_000_000_000_000
    FLASH = 1_000_000_000_000
    JIT_L = 10 ** 22

    q0 = vault.quote(pool)
    print(f"  honest quote at the deposit : V={q0['value']} "
          f"(target {q0['target_total']}, proceeds {q0['proceeds']}, sold {q0['sold']}, "
          f"unsold {q0['unsold']}, extL {q0['ext_liquidity']})")

    shares = Vault.issue(vault.supply, q0["value"], D)
    vault.local0 += D
    vault.supply += shares
    print(f"  deposit D={D} -> minted {shares} shares (m = S*D/V)")

    pool.add("jit", JIT_L)
    q1 = vault.quote(pool)
    print(f"  quote with JIT depth         : V={q1['value']} (proceeds {q1['proceeds']})")

    payout = Vault.entitlement(vault.supply, q1["value"], shares)
    vault.supply -= shares
    vault.local0 -= payout
    print(f"  redeem {shares} shares -> payout {payout}; "
          f"local target left {vault.local0} (blocked-mode sleeve test: {'OK' if vault.local0 >= 0 else 'SHORT'})")

    pool.remove("jit", JIT_L)
    profit = payout - FLASH

    led = Ledger("S1 attacker ledger (quote-priced design, JIT depth)")
    led.row("PoolManager flash credit taken (token0)", str(FLASH), "repaid from the payout")
    led.row("redemption payout received (token0)", str(payout), "vault local target")
    led.row("JIT liquidity added and removed", str(JIT_L), "net settlement is dust")
    led.row("shares held at end", "0", "fully exited")
    led.row("LP positions at end", "0", "none")
    led.row("debt at end", "0", "flash repaid")
    led.row("fees paid by the attacker", "0", "no swap executed by the attacker")
    led.row("NET PROFIT (token0 raw)", str(profit), f"{profit * 100 / D:.3f} % of the deposit")
    led.show()

    ident = D * (q1["value"] - q0["value"] - D) // (q0["value"] + D)
    print(f"  identity D*(V_r - V_d - D)/(V_d + D) = {ident}  (ledger {profit}, 1 wei of flooring)")
    assert abs(ident - profit) <= 2
    print(f"  uplift U = V_r - V_d - D = {q1['value'] - q0['value'] - D}")
    print("  audit PoC for comparison: 70,634,405,953 raw token0 = 7.1 % of a 1e12 vault")


def s2_spot_quote_priced() -> None:
    hr("S2  APEX-012 as implemented: quote-priced design, in-session price move")
    pool, vault = build_state()
    D = 1_000_000_000_000
    FLASH = 1_000_000_000_000

    q0 = vault.quote(pool)
    print(f"  honest quote at rest : V={q0['value']}")

    consumed, out, fee = pool.push_to_tick(False, 200)
    print(f"  attacker push: sold token1 {consumed} for token0 {out} (fee {fee}); tick {pool.tick()}")
    q1 = vault.quote(pool)
    print(f"  quote at the pushed price : V={q1['value']} (depression {q0['value'] - q1['value']})")

    shares = Vault.issue(vault.supply, q1["value"], D)
    vault.local0 += D
    vault.supply += shares
    print(f"  deposit D={D} -> minted {shares} shares (m = S*D/V at the depressed quote)")

    back_consumed, back_out, back_fee = pool.push_to_tick(True, 0)
    q2 = vault.quote(pool)
    print(f"  price restored to tick {pool.tick()}: token0 {back_consumed} -> token1 {back_out} "
          f"(fee {back_fee}); quote V={q2['value']}")

    payout = Vault.entitlement(vault.supply, q2["value"], shares)
    vault.supply -= shares
    vault.local0 -= payout

    ident = D * (q2["value"] - q1["value"] - D) // (q1["value"] + D)
    print(f"  redemption payout {payout}; identity D*(V_r - V_d - D)/(V_d + D) = {ident}; "
          f"ledger profit (share side) = {payout - FLASH}")
    assert abs(ident - (payout - FLASH)) <= 2
    print("  the attacker's own round-trip swap P&L is negative (fees plus impact); the")
    print("  share-side gain above is what the manipulation transfers from the incumbents")


def identity_sweep() -> None:
    hr("S2b  unified APEX-012 identity: profit = D*(V_r - V_d - D)/(V_d + D)")
    print("  V_d = the reference at the deposit, V_r = the reference at the redemption,")
    print("  D = the deposit, S = the incumbent supply. It holds for ANY pair of")
    print("  references, so JIT depth, in-session price moves, donations and step-cap")
    print("  freezes are all the same hole with different sign choices.")
    for (S, D, Vd, Vr) in [(1_000_000, 250_000, 1_000_000, 1_400_000),
                           (10 ** 12, 10 ** 11, 10 ** 12, 10 ** 12),
                           (10 ** 12, 10 ** 11, 10 ** 12, 900_000_000_000),
                           (7, 3, 11, 13)]:
        m = Vault.issue(S, Vd, D)
        payout = Vault.entitlement(S + m, Vr, m)
        profit = payout - D
        ident = D * (Vr - Vd - D) // (Vd + D)
        print(f"    S={S} D={D} V_d={Vd} V_r={Vr} -> m={m} payout={payout} "
              f"profit={profit} identity={ident} ok={abs(ident - profit) <= 1}")
        assert abs(ident - profit) <= 1
    print("  corollary: if the deposit reference and the redemption reference are the")
    print("  SAME function on the SAME state, the profit is exactly zero.")


def s3_executed_price_mint() -> None:
    hr("S3  executed-price mint: V_ref = A_T + p_exec*A_O, and a sandwiched vault entry swap")
    print("  The vault's entry swap sells target for opposing, so p_exec (opposing per")
    print("  target) falls when the price falls. A depositor who pushes the price down")
    print("  before the vault trades therefore lowers V_ref and mints more shares.\n")
    results = {}
    for label, front_run in (("unmanipulated", None), ("front-run -200 ticks (price down)", -200)):
        pool, vault = build_state()
        D = 500_000_000_000
        if front_run is not None:
            consumed, out, fee = pool.push_to_tick(True, front_run)
        A_T, A_O = vault.book_totals(pool)
        sold_t, got_o, fee_e, p_exec = executed_entry_swap(vault, pool, D)
        pool.swap_exact_in(True, sold_t, MIN_SQRT_PRICE + 1)
        vault.local0 -= sold_t
        vault.local1 += got_o
        A_T2, A_O2 = vault.book_totals(pool)
        v_ref = A_T2 + (got_o / sold_t) * A_O2
        m = Vault.issue(vault.supply, int(v_ref), D)
        results[label] = (m, p_exec, int(v_ref))
        print(f"  {label}:")
        print(f"    executed price {p_exec:.9f} opposing per target, V_ref={int(v_ref)}, mint m={m}")
    base = results["unmanipulated"][0]
    manip = results["front-run -200 ticks (price down)"][0]
    print(f"\n  over-mint from the price move alone: {manip - base} shares "
          f"({(manip - base) * 100 / base:.4f} % of the honest mint)")
    print("  The depositor paid the front-run impact and the swap fees to create that")
    print("  move, so the mint comparison alone does not settle the question; S4 closes")
    print("  the full round trip and S5 prices the part that survives.")


def s4_quantity_design_closed_ledger() -> None:
    hr("S4  price-free (quantity) mint + slice exit: the same attack, closed end to end")
    print("  Attack sequence (the APEX-012 shape, ported to real swaps):")
    print("   1. the attacker pushes the price in the direction that would have depressed")
    print("      the quote-priced design")
    print("   2. the victim deposits target; the vault executes a proportional conversion")
    print("   3. the attacker restores the price")
    print("   4. the attacker redeems the shares it minted; the vault settles a slice")
    print("   5. the attacker repays the flash credit\n")

    mints = {}
    for label, front_run in (("without the price move", None), ("with the price move", 200)):
        pool, vault = build_state()
        D = 500_000_000_000
        if front_run is not None:
            consumed, out, fee = pool.push_to_tick(False, front_run)
            attack_token0 = out
            attack_token1 = -consumed
        A_T, A_O = vault.book_totals(pool)
        sold_t, got_o, fee_e, _ = executed_entry_swap(vault, pool, D)
        pool.swap_exact_in(True, sold_t, MIN_SQRT_PRICE + 1)
        vault.local0 -= sold_t
        vault.local1 += got_o
        net_t = D - sold_t
        net_o = got_o
        base_t, base_o = vault.book_totals(pool)
        base_t -= net_t
        base_o -= net_o
        k_t = (net_t / base_t) if base_t else 0.0
        k_o = (net_o / base_o) if base_o else 0.0
        m = int(vault.supply * k_t)
        mints[label] = m
        print(f"  {label}:")
        print(f"    vault conversion: sold {sold_t} target for {got_o} opposing (fee {fee_e})")
        print(f"    net contribution ({net_t}, {net_o}); base vector ({base_t}, {base_o})")
        print(f"    proportionality k: target side {k_t:.12f}, opposing side {k_o:.12f}, "
              f"mismatch {abs(k_t - k_o) / k_t * 100:.4f} %")
        print(f"    mint m = S*k = {m} shares (no price enters the mint)")
    a, b = mints["without the price move"], mints["with the price move"]
    print(f"\n  mint difference caused by the price move: {b - a} shares "
          f"({(b - a) * 100 / a:.4f} % of the mint)")
    print("  the residual is the conversion's own execution difference (impact and fee),")
    print("  which the depositor bears; it is not a quote manipulation")

    pool, vault = build_state()
    D = 500_000_000_000
    FLASH = 500_000_000_000
    consumed, out, fee = pool.push_to_tick(False, 200)
    atk_token0 = out
    atk_token1 = -consumed
    print(f"\n  1. front run: token1 {consumed} -> token0 {out} (fee {fee}); tick {pool.tick()}")
    A_T, A_O = vault.book_totals(pool)
    sold_t, got_o, fee_e, _ = executed_entry_swap(vault, pool, D)
    pool.swap_exact_in(True, sold_t, MIN_SQRT_PRICE + 1)
    vault.local0 -= sold_t
    vault.local1 += got_o
    net_t = D - sold_t
    net_o = got_o
    base_t, base_o = vault.book_totals(pool)
    base_t -= net_t
    base_o -= net_o
    k = (net_t / base_t) if base_t else 0.0
    m = int(vault.supply * k)
    vault.supply += m
    print(f"  2. victim's deposit {D}: the vault converted {sold_t} target into {got_o} opposing; "
          f"m={m} shares")
    back_consumed, back_out, back_fee = restore_to_tick(pool, 0)
    atk_token0 -= back_consumed
    atk_token1 += back_out
    print(f"  3. price restored to tick {pool.tick()}: token0 {back_consumed} -> token1 {back_out}")
    q = vault.quote(pool)
    payout = Vault.entitlement(vault.supply, q["value"], m)
    vault.supply -= m
    exit_led = executed_exit_slice(vault, pool, payout, whole_balance_dump=False)
    print(f"  4. redemption of {m} shares -> payout {payout}; slice exit: local paid "
          f"{exit_led['local_paid']}, core liquidity removed {exit_led['core_removed']}, "
          f"opposing sold {exit_led['target_sold']}, proceeds {exit_led['proceeds']}, "
          f"fee {exit_led['fee']}, shortfall {exit_led['shortfall']}")
    atk_token0 += payout
    profit_token0 = atk_token0 - FLASH
    price_t1_in_t0 = (Q96 / pool.sqrt_p) ** 2
    profit_marked = profit_token0 + atk_token1 * price_t1_in_t0

    led = Ledger("S4 attacker ledger (quantity mint + slice exit, full round trip)")
    led.row("flash credit taken (token0)", str(FLASH), "repaid from the payout")
    led.row("front run: token1 sold", str(consumed), "received token0")
    led.row("front run: token0 received", str(out), "")
    led.row("restore leg: token0 spent", str(back_consumed), "bought token1 back")
    led.row("restore leg: token1 received", str(back_out), "")
    led.row("swap fees paid (front run + restore + exit)",
            str(fee + back_fee + exit_led["fee"]), "0.30 % per swap leg")
    led.row("shares minted to the victim", str(m), "quantity proportional")
    led.row("redemption payout (token0)", str(payout), "sleeve plus slice proceeds")
    led.row("shares held at end", "0", "fully exited")
    led.row("LP positions at end", "0", "none")
    led.row("debt at end", "0", "flash repaid")
    led.row("remaining token vector", f"token0 {atk_token0} / token1 {atk_token1}",
            "token1 is the round-trip residual")
    led.row("NET (token0 raw, flash repaid)", str(profit_token0), "target-denominated")
    led.row("NET marked at the restored price", str(int(profit_marked)), "token1 leg at spot")
    led.show()
    print("  Reading: with a quantity mint the price move cannot change the share count,")
    print("  so the APEX-012 dilution channel is closed. What is left is the attacker's")
    print("  own round trip plus the exit swap, which is priced in S5.")


def s5_exit_sandwich_residual() -> None:
    hr("S5  RESIDUAL: the sandwich of the vault's own trade, and the inventory cutoff")
    print("  The vault sells its own inventory. A searcher who moves the price in the")
    print("  dump direction first and restores it afterwards captures the vault's price")
    print("  impact. No share pricing manipulation is involved, so this survives every")
    print("  redesign. Sleeve 0 (the production-scripted configuration), 66.7 % exit.\n")
    for label, dump, limit_ticks in (
            ("A whole-balance dump, MIN/MAX limit (current _swapDeficit shape)", True, None),
            ("B deficit-only conversion, MIN/MAX limit", False, None),
            ("C deficit-only conversion, price limit +200 ticks", False, 200)):
        pool, vault = build_state(sleeve=0)
        redeem = vault.supply * 2 // 3
        q = vault.quote(pool)
        payout = Vault.entitlement(vault.supply, q["value"], redeem)
        consumed, out, fee = pool.push_to_tick(False, 200)
        led = executed_exit_slice(vault, pool, payout, whole_balance_dump=dump,
                                  limit_ticks=limit_ticks)
        back_consumed, back_out, back_fee = restore_to_tick(pool, 0)
        searcher_token0 = out - back_consumed
        searcher_token1 = -consumed + back_out
        price_t1_in_t0 = (Q96 / pool.sqrt_p) ** 2
        profit = searcher_token0 + searcher_token1 * price_t1_in_t0
        print(f"  {label}")
        print(f"    redemption entitlement               : {payout}")
        print(f"    vault local target paid              : {led['local_paid']}")
        print(f"    vault core liquidity removed         : {led['core_removed']}")
        print(f"    vault opposing sold                  : {led['target_sold']}")
        print(f"    vault proceeds received (target)     : {led['proceeds']} (fee {led['fee']})")
        print(f"    unfunded shortfall                   : {led['shortfall']}")
        print(f"    searcher token0 delta                : {searcher_token0}")
        print(f"    searcher token1 delta                : {searcher_token1}")
        print(f"    searcher profit (token0, at spot)    : {int(profit)}")
        print(f"    searcher fees paid                   : {fee + back_fee}")
        print()

    print("  Redemption-size sweep (sleeve 0), searcher profit in token0 raw:")
    print("      exit share   A whole dump   B deficit-only   C deficit-only +200 ticks")
    for frac in (0.10, 0.20, 0.50, 0.6666666666666666, 1.00):
        row = []
        for dump, limit_ticks in ((True, None), (False, None), (False, 200)):
            pool, vault = build_state(sleeve=0)
            redeem = int(vault.supply * frac)
            q = vault.quote(pool)
            payout = Vault.entitlement(vault.supply, q["value"], redeem)
            consumed, out, fee = pool.push_to_tick(False, 200)
            led = executed_exit_slice(vault, pool, payout, whole_balance_dump=dump,
                                      limit_ticks=limit_ticks)
            back_consumed, back_out, back_fee = restore_to_tick(pool, 0)
            st0 = out - back_consumed
            st1 = -consumed + back_out
            rate = (Q96 / pool.sqrt_p) ** 2
            row.append((int(st0 + st1 * rate), led["target_sold"], led["shortfall"]))
        print(f"      {frac:>9.3f} {row[0][0]:>14} {row[1][0]:>15} {row[2][0]:>26}")
        print(f"                 sold {row[0][1]} / {row[1][1]} / {row[2][1]}"
              f"   shortfall {row[0][2]} / {row[1][2]} / {row[2][2]}")


def s6_size_and_depth_sensitivity() -> None:
    hr("S6  size and depth sensitivity: JIT depth ladder, front-run ticks, 49/50/51 % swaps")
    pool0, _ = build_state()
    depth0, depth1 = pool0.reserves()
    print(f"  pool reserves: token0 {depth0}, token1 {depth1}")
    print("\n  (a) quote-priced design, JIT depth ladder (deposit 1e12, supply 1e12)")
    print("      JIT liquidity        V at redemption   profit (token0)   % of deposit")
    for jit in (0, 10 ** 10, 10 ** 12, 10 ** 14, 10 ** 18, 10 ** 22):
        pool, vault = build_state()
        D = 1_000_000_000_000
        q0 = vault.quote(pool)
        shares = Vault.issue(vault.supply, q0["value"], D)
        vault.local0 += D
        vault.supply += shares
        if jit:
            pool.add("jit", jit)
        q1 = vault.quote(pool)
        payout = Vault.entitlement(vault.supply, q1["value"], shares)
        profit = payout - D
        print(f"      {jit:>22} {q1['value']:>16} {profit:>18} {profit * 100 / D:>12.3f} %")
        if jit:
            pool.remove("jit", jit)

    print("\n  (b) front-run tick sweep in the quote-depressing direction (price up)")
    print("      ticks   V at deposit   V at redemption   profit (token0)")
    for ticks in (50, 100, 200, 500, 1000, 5000):
        pool, vault = build_state()
        D = 1_000_000_000_000
        pool.push_to_tick(False, ticks)
        q1 = vault.quote(pool)
        shares = Vault.issue(vault.supply, q1["value"], D)
        vault.local0 += D
        vault.supply += shares
        restore_to_tick(pool, 0)
        q2 = vault.quote(pool)
        payout = Vault.entitlement(vault.supply, q2["value"], shares)
        print(f"      {ticks:>5} {q1['value']:>13} {q2['value']:>16} {payout - D:>16}")

    print("\n  (c) swaps sized at 49/50/51 % of the pool's token1 reserve, both directions")
    print("      fraction  direction  tick   V at deposit   V at redemption   profit")
    for frac in (0.49, 0.50, 0.51):
        for zero_for_one in (False, True):
            pool, vault = build_state()
            D = 1_000_000_000_000
            x, y = pool.reserves()
            pool.swap_exact_in(zero_for_one, int(y * frac))
            q1 = vault.quote(pool)
            shares = Vault.issue(vault.supply, q1["value"], D)
            vault.local0 += D
            vault.supply += shares
            restore_to_tick(pool, 0)
            q2 = vault.quote(pool)
            payout = Vault.entitlement(vault.supply, q2["value"], shares)
            direction = "price up" if not zero_for_one else "price down"
            print(f"      {frac:>8.2f} {direction:>11} {pool.tick():>5} {q1['value']:>13} "
                  f"{q2['value']:>16} {payout - D:>10}")


def s7_twap_reference() -> None:
    hr("S7  the only available reference: the actual UniswapV4 truncated TWAP implementation")
    MAX_ABS = 9116
    print(f"  UniswapV4TruncatedTwapOracleLib.MAX_ABS_TICK_MOVE = {MAX_ABS}")
    print(f"  price factor of {MAX_ABS} ticks = 1.0001^{MAX_ABS} = {1.0001 ** MAX_ABS:.4f}")
    print("  write() records truncate(liveTick, prevTick) and credits the WHOLE elapsed")
    print("  gap with that recorded tick; update() is permissionless with no isUnlocked")
    print("  check; every write resets writeAge.")
    print(f"  => one push-poke-restore inside a single unlock moves a whole window by")
    print(f"     {MAX_ABS} ticks ({1.0001 ** MAX_ABS:.3f}x price). Audit APEX-2026-050.")
    print("  => the recorded tick can also ratchet by 9116 per update while the spot price")
    print("     stays put, so a longer window is not a defence on its own.")
    print("  => the same-pool TWAP is therefore not a manipulation-resistant mint reference")


def design_matrix() -> None:
    hr("S8  design matrix: what each candidate pricing rule depends on")
    rows = [
        ("1 quote-priced (today)", "hypothetical liquidation quote", "manipulable",
         "manipulable", "JIT depth + price move", "as today"),
        ("2 swaps + quote entitlements", "hypothetical liquidation quote", "manipulable",
         "manipulable", "JIT depth + price move", "unchanged"),
        ("3 executed-price mint", "the vault's own executed price", "manipulable",
         "sandwichable", "sandwich of the vault trade", "relocated"),
        ("4 price-free vector mint", "token quantities only", "not manipulable",
         "sandwichable", "sandwich of the vault trade", "relocated"),
        ("5 same-pool TWAP reference", "truncated TWAP of the same pool", "manipulable",
         "manipulable", "TWAP skew + sandwich", "not a fix"),
    ]
    print(f"  {'design':<32} {'mint reference':<34} {'mint input':<16} {'exit input':<16} {'attack that survives':<28} verdict")
    for r in rows:
        print(f"  {r[0]:<32} {r[1]:<34} {r[2]:<16} {r[3]:<16} {r[4]:<28} {r[5]}")


def main() -> None:
    print(__doc__)
    s0_selfcheck()
    s1_jit_quote_priced()
    s2_spot_quote_priced()
    identity_sweep()
    s3_executed_price_mint()
    s4_quantity_design_closed_ledger()
    s5_exit_sandwich_residual()
    s6_size_and_depth_sensitivity()
    s7_twap_reference()
    design_matrix()
    print("\nDONE\n")


if __name__ == "__main__":
    main()
