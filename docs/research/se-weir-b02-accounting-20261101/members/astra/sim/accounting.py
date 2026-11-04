"""Independent Weir accounting experiments; Python standard library only.

LiquidityAmounts.sol:15-65, infinite-range continuous limit:
    L = min(a0 * sqrtP, a1 / sqrtP); (a0, a1) = (L / sqrtP, L * sqrtP).
WeirVaults.sol:269: shares = added_L * supply / existing_L.
WeirVaults.sol:290-318: remove pro-rata L and idle; swap withdrawn net.
WeirVaults.sol:355-379: compound net fees and idle, without balancing swap.
WeirVaults.sol:391-410: swap half the live-price excess of depositor inputs.

Not a bit-exact EVM model: omit integer floors and two-raw-unit cushions.
Amounts are normalized tokens, not raw wei. Decimal precision is 60 digits.
Swap legs use a labeled constant-product approximation: fixed full-range
liquidity, no ticks/hooks, optional input fee. Price returns are valuation
benchmarks; no arbitrage profit, restoration cost or restoration fees modeled.
"""

from decimal import Decimal, getcontext

getcontext().prec = 60
D = Decimal
ZERO, ONE = D(0), D(1)
TOLERANCE = D("1e-45")


def close(actual, expected):
    assert abs(actual - expected) < TOLERANCE, (actual, expected)


def liquidity(a0, a1, sqrt_p):
    return min(a0 * sqrt_p, a1 / sqrt_p)


def amounts(liq, sqrt_p):
    return liq / sqrt_p, liq * sqrt_p


def placement(a0, a1, sqrt_p):
    liq = liquidity(a0, a1, sqrt_p)
    used0, used1 = amounts(liq, sqrt_p)
    recovered0, recovered1 = amounts(liq, ONE)
    loss = used0 + used1 - recovered0 - recovered1
    audit_il = liq * (sqrt_p - ONE) ** 2 / sqrt_p
    close(loss, audit_il)
    close(used0 + a0 - used0, a0)
    close(used1 + a1 - used1, a1)
    return liq, used0, used1, recovered0, recovered1, loss


def swap(liq, sqrt_p, amount_in, zero_for_one, fee=ZERO):
    """Constant-product approximation using virtual reserves at current P."""
    x, y = amounts(liq, sqrt_p)
    effective = amount_in * (ONE - fee)
    if zero_for_one:
        next_x = x + effective
        next_y = liq * liq / next_x
        output = y - next_y
    else:
        next_y = y + effective
        next_x = liq * liq / next_y
        output = x - next_x
    close(next_x * next_y, liq * liq)
    return output, liq / next_x


def row(label, **values):
    print(label + " " + " ".join(
        f"{key}={ZERO if abs(value) < TOLERANCE else value:.9f}"
        for key, value in values.items()
    ))


def placed_row(label, result):
    liq, u0, u1, r0, r1, loss = result
    row(label, dL=liq, placed0=u0, placed1=u1, recovered0=r0,
        recovered1=r1, loss_P0=loss, audit_IL=loss)


def external():
    print("\nEXTERNAL PUSH: P0=1, L=1000, S=1000; P'=2 and 4")
    print("compound budget=(100,100): idle0=100 plus net harvested fee1=100")
    for p in (D(2), D(4)):
        s = p.sqrt()
        result = placement(D(100), D(100), s)
        placed_row(f"compound P={p}", result)
        liq, u0, u1, _, _, loss = result
        row("compound owners: caller already owns 10%; no new shares",
            existing_90pct_loss=loss * D(".9"),
            caller_10pct_loss=loss * D(".1"),
            idle0=D(100) - u0, idle1=D(100) - u1,
            post_L=D(1000) + liq, supply=D(1000))
        for a0, a1 in ((D(100), ZERO), (ZERO, D(100))):
            single = placement(a0, a1, s)
            placed_row(f"one_sided_idle ({a0},{a1}) P={p}", single)
            close(single[0], ZERO)
        # Separate caller-funded deposit, with no pre-existing idle or fees.
        minted = liq * D(1000) / D(1000)
        old_fraction = D(1000) / (D(1000) + minted)
        old_value = old_fraction * 2 * (D(1000) + liq)
        new_value = (ONE - old_fraction) * 2 * (D(1000) + liq)
        refund = D(200) - u0 - u1
        close(old_value, D(2000))
        close(D(200) - new_value - refund, loss)
        row("caller-funded deposit; old idle=0",
            minted=minted, old_holder_loss=D(2000) - old_value,
            caller_loss=D(200) - new_value - refund, refund0=refund)
        # A different initial book: compound (100,100) owned budget first,
        # then the same caller deposit; leftover idle is not in denominator.
        denominator = D(1000) + liq
        minted_with_idle = liq * D(1000) / denominator
        caller_fraction = minted_with_idle / (D(1000) + minted_with_idle)
        idle_value = D(200) - u0 - u1
        row("residual idle denominator check",
            denominator=denominator, minted=minted_with_idle,
            caller_idle_claim=caller_fraction * idle_value,
            existing_idle_dilution=caller_fraction * idle_value)


def self_moved():
    print("\nSELF-MOVED: L=800, S=1000, idle=(400,0), exit fraction=0.6")
    old_l, idle0, fraction = D(800), D(400), D(".6")
    remaining_l = old_l * (ONE - fraction)
    remaining_idle0 = idle0 * (ONE - fraction)
    q = old_l * fraction  # Withdrawn token1; withdrawing to token0.
    close(liquidity(idle0, ZERO, ONE), ZERO)  # pre-withdraw compound
    row("precompound and withdrawal",
        precompound_dL=ZERO, withdrawn_L=old_l * fraction,
        withdrawn0=old_l * fraction + idle0 * fraction,
        withdrawn1=q, remaining_L=remaining_l,
        remaining_idle0=remaining_idle0, remaining_idle1=ZERO)
    for p in (D(2), D(4)):
        desired_s = p.sqrt()
        for fee in (ZERO, D(".003")):
            # Solve Q so swapping just withdrawn token1 reaches chosen P'.
            pool_l = q * (ONE - fee) / (desired_s - ONE)
            assert pool_l >= remaining_l
            output0, s = swap(pool_l, ONE, q, False, fee)
            close(s, desired_s)
            gross_fee1 = q * fee * remaining_l / pool_l
            cut1 = gross_fee1 * D(".05")  # Weir default: 500 / 10_000.
            net_fee1 = gross_fee1 - cut1
            result = placement(remaining_idle0, net_fee1, s)
            row(f"withdraw zap P={p} fee={fee}",
                post_burn_pool_L=pool_l, swap_input1=q,
                staying_token1_sold=ZERO, swap_output0=output0,
                actual_P=s * s, gross_vault_fee1=gross_fee1,
                perf_cut1=cut1, net_fee1=net_fee1)
            placed_row("next separate compound", result)
            row("placement allocation", stayer_loss=result[-1],
                exited_caller_loss=ZERO)
            if not fee:
                close(result[0], ZERO)


def dump():
    print("\nDUMP: P0=1, own L=100, S=1000, exit fraction=2/3")
    f, own_l, external_l = D(2) / D(3), D(100), D(2900) / D(3)
    remaining_l = own_l * (ONE - f)
    weir_pool_l = external_l + remaining_l
    weir_input = f * own_l
    weir_out, weir_s = swap(weir_pool_l, ONE, weir_input, False)
    weir_staying = 2 * remaining_l
    whole_out, whole_s = swap(external_l, ONE, own_l, False)
    full_realized = own_l + whole_out
    # Explicit comparison assumption: distribute realized bag pro rata.
    # Not a reconstruction of Wings' liquidation quote or core selection.
    dump_staying = (ONE - f) * full_realized
    stayed_tokens_sold = (ONE - f) * own_l
    baseline = 2 * remaining_l
    close(baseline - dump_staying, (ONE - f) * (own_l - whole_out))
    row("Weir withdrawn-net; absolute MAX limit nonbinding",
        input1=weir_input, output0=weir_out, post_P=weir_s * weir_s,
        payout0=f * own_l + weir_out,
        staying_value_P0=weir_staying, staying_loss=baseline - weir_staying)
    row("024-shaped whole dump; same absolute MAX limit nonbinding",
        input1=own_l, output0=whole_out, post_P=whole_s * whole_s,
        staying_token1_sold=stayed_tokens_sold,
        payout0=f * full_realized, staying_value_P0=dump_staying,
        staying_loss=baseline - dump_staying)


def half_excess():
    print("\nHALF-EXCESS: caller input=(100,100), pool L=1000")
    for p in (D(2), D(4)):
        s, a0, a1 = p.sqrt(), D(100), D(100)
        value0_in1 = a0 * s * s
        if value0_in1 > a1:
            amount_in, zfo = (a0 - a1 / p) / 2, True
        else:
            amount_in, zfo = (a1 - value0_in1) / 2, False
        output, next_s = swap(D(1000), s, amount_in, zfo)
        n0 = a0 - amount_in if zfo else a0 + output
        n1 = a1 + output if zfo else a1 - amount_in
        result = placement(n0, n1, next_s)
        row(f"balance P={p}", input0=amount_in, output1=output,
            post_P=next_s * next_s, n0=n0, n1=n1,
            ratio_error1=n1 - n0 * next_s * next_s)
        placed_row("post-balance placement", result)
        liq, u0, u1, r0, r1, loss = result
        refund0, refund1 = n0 - u0, n1 - u1
        caller_total = r0 + r1 + refund0 + refund1
        swap_mark_gain = n0 + n1 - a0 - a1
        close(caller_total - a0 - a1, swap_mark_gain - loss)
        minted = liq * D(1000) / D(1000)
        old_value = D(1000) / (D(1000) + minted) * 2 * (D(1000) + liq)
        close(old_value, D(2000))
        row("separate swap and placement accounting",
            refund0=refund0, refund1=refund1,
            swap_mark_gain_P0=swap_mark_gain,
            caller_net_change_P0=caller_total - D(200),
            old_liquidity_loss_P0=D(2000) - old_value)


if __name__ == "__main__":
    print("MODEL: infinite-range Decimal accounting; CP swap approximation")
    external()
    self_moved()
    dump()
    half_excess()
    print("\nPASS: all accounting identities and fixture assertions")
