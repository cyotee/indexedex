#!/usr/bin/env python3
"""Weir full-range accounting fixtures; Python standard library only.

The placement formulas are the infinite-range limit of LiquidityAmounts.sol.
Swap legs are explicitly zero-fee constant-product approximations, not V4 tick simulations.
"""

import math

P0 = 1.0
EXISTING_L = 1_000.0
EXISTING_S = 1_000.0


def liquidity_for_amounts(price, amount0, amount1):
    """Infinite-range in-range limit: min(L from token0, L from token1)."""
    sqrt_p = math.sqrt(price)
    return min(amount0 * sqrt_p, amount1 / sqrt_p)


def amounts_for_liquidity(price, liquidity):
    """Infinite-range in-range limit of getAmountsForLiquidity."""
    sqrt_p = math.sqrt(price)
    return liquidity / sqrt_p, liquidity * sqrt_p


def value_at_p0(amount0, amount1):
    """Token1 units; P0=1, so token0 and token1 have equal unit value."""
    return amount0 + amount1


def audit_il(price, liquidity):
    """APEX-2026-023 full-range approximation, with P0=1."""
    sqrt_p = math.sqrt(price)
    return liquidity * (sqrt_p - 1.0) ** 2 / sqrt_p


def placement(price, amount0, amount1):
    added_liquidity = liquidity_for_amounts(price, amount0, amount1)
    placed0, placed1 = amounts_for_liquidity(price, added_liquidity)
    recovered0, recovered1 = amounts_for_liquidity(P0, added_liquidity)
    left0 = amount0 - placed0
    left1 = amount1 - placed1
    direct_shortfall = value_at_p0(placed0, placed1) - value_at_p0(recovered0, recovered1)
    approximation = audit_il(price, added_liquidity)
    assert math.isclose(direct_shortfall, approximation, rel_tol=1e-12, abs_tol=1e-9)
    total_shortfall = value_at_p0(amount0, amount1) - value_at_p0(
        left0 + recovered0, left1 + recovered1
    )
    assert math.isclose(total_shortfall, direct_shortfall, rel_tol=1e-12, abs_tol=1e-9)
    return {
        "dL": added_liquidity,
        "placed0": placed0,
        "placed1": placed1,
        "left0": left0,
        "left1": left1,
        "recovered0": recovered0,
        "recovered1": recovered1,
        "shortfall": direct_shortfall,
        "audit_il": approximation,
    }


def print_placement(prefix, result):
    print(
        f"{prefix} dL={result['dL']:.6f} "
        f"placed0={result['placed0']:.6f} placed1={result['placed1']:.6f} "
        f"recovered0={result['recovered0']:.6f} recovered1={result['recovered1']:.6f} "
        f"shortfall_token1_at_P0={result['shortfall']:.6f} "
        f"audit_IL={result['audit_il']:.6f}"
    )


def external_push():
    print("CASE 1A: external push; caller deposit of 100 token0 + 100 token1")
    for price in (2.0, 4.0):
        result = placement(price, 100.0, 100.0)
        minted_shares = result["dL"] * EXISTING_S / EXISTING_L
        total_value_after = 2.0 * (EXISTING_L + result["dL"])
        existing_value_after = EXISTING_L / (EXISTING_L + result["dL"]) * total_value_after
        caller_position_after = result["dL"] / (EXISTING_L + result["dL"]) * total_value_after
        caller_value_after = caller_position_after + value_at_p0(result["left0"], result["left1"])
        existing_loss = 2.0 * EXISTING_L - existing_value_after
        caller_loss = 200.0 - caller_value_after
        assert math.isclose(existing_loss, 0.0, abs_tol=1e-9)
        assert math.isclose(caller_loss, result["shortfall"], rel_tol=1e-12, abs_tol=1e-9)
        print(f"P'={price:.0f} existing_L={EXISTING_L:.0f} existing_supply={EXISTING_S:.0f}")
        print_placement("  placement", result)
        print(
            f"  minted_shares={minted_shares:.6f} left0_refund={result['left0']:.6f} "
            f"left1_refund={result['left1']:.6f} existing_loss={existing_loss:.6f} "
            f"caller_loss={caller_loss:.6f} existing_share_of_loss=0% caller_share_of_loss=100%"
        )

    print("CASE 1B: same pushed placement of already-owned idle; compound mints no shares")
    for price in (2.0, 4.0):
        result = placement(price, 100.0, 100.0)
        before = 2.0 * EXISTING_L + 200.0
        after = 2.0 * (EXISTING_L + result["dL"]) + value_at_p0(result["left0"], result["left1"])
        loss = before - after
        assert math.isclose(loss, result["shortfall"], rel_tol=1e-12, abs_tol=1e-9)
        print_placement(f"P'={price:.0f} idle", result)
        print(
            f"  idle_left0={result['left0']:.6f} idle_left1={result['left1']:.6f} "
            f"existing_holders_loss={loss:.6f} compound_caller_loss=0.000000 "
            f"existing_holder_share_of_loss=100%"
        )

    print("CASE 1C: strictly one-sided idle has zero other-side amount")
    for price in (2.0, 4.0):
        for label, amount0, amount1 in (("token0_only", 100.0, 0.0), ("token1_only", 0.0, 100.0)):
            result = placement(price, amount0, amount1)
            assert result["dL"] == 0.0 and result["shortfall"] == 0.0
            print_placement(f"P'={price:.0f} {label}", result)


def withdrawn_swap_for_price(price, fraction=2.0 / 3.0, vault_balance=1_000.0):
    """Token1-in CP swap; choose depth so the withdrawn slice lands at price."""
    sqrt_p = math.sqrt(price)
    amount_in = fraction * vault_balance
    reserve0 = amount_in / (sqrt_p - 1.0)
    reserve1 = reserve0
    amount_out = reserve0 * amount_in / (reserve1 + amount_in)
    new0 = reserve0 - amount_out
    new1 = reserve1 + amount_in
    assert math.isclose(new1 / new0, price, rel_tol=1e-12)
    return amount_in, amount_out, reserve0


def self_moved_trailing():
    print("CASE 2: withdraw zap moves P0 to P'; following compound places 100+100 at P'")
    print("  CP approximation: zero fees; pool depth chosen so the withdrawn-net swap reaches P'")
    for price in (2.0, 4.0):
        amount_in, amount_out, reserve = withdrawn_swap_for_price(price)
        result = placement(price, 100.0, 100.0)
        print(
            f"P'={price:.0f} pool_reserve_each_at_P0={reserve:.6f} "
            f"withdrawn_token1_swapped={amount_in:.6f} token0_out={amount_out:.6f} "
            f"whole_vault_token1=1000.000000"
        )
        print_placement("  trailing_idle", result)
        print(
            f"  swap_is_withdrawn_slice_only=yes; remaining_holder_trailing_loss={result['shortfall']:.6f}; "
            f"redeemer_already_exited=yes"
        )


def whole_balance_dump():
    print("CASE 3: Weir withdrawn-net swap versus stylized 024 whole-opposing-balance dump")
    print("  Same exit fraction 2/3 and same non-binding MIN/MAX limit; CP approximation, zero fees")
    print("  Whole-dump shape pays the exiter 2/3 of actual post-dump assets; stayer owns the rest")
    fraction = 2.0 / 3.0
    balance = 1_000.0
    for price in (2.0, 4.0):
        weir_in, weir_out, reserve = withdrawn_swap_for_price(price, fraction, balance)
        whole_in = balance
        whole_out = reserve * whole_in / (reserve + whole_in)
        whole_post_price = (reserve + whole_in) / (reserve - whole_out)
        weir_stayer = (1.0 - fraction) * (2.0 * balance)
        whole_stayer = (1.0 - fraction) * (balance + whole_out)
        stayer_loss = weir_stayer - whole_stayer
        identity_loss = (1.0 - fraction) * (balance - whole_out)
        assert math.isclose(stayer_loss, identity_loss, rel_tol=1e-12, abs_tol=1e-9)
        print(
            f"P'_Weir={price:.0f} Weir_swap_in={weir_in:.6f} Weir_swap_out={weir_out:.6f} "
            f"whole_swap_in={whole_in:.6f} whole_swap_out={whole_out:.6f} "
            f"whole_post_price={whole_post_price:.6f}"
        )
        print(
            f"  stayer_value_after_return_P0_Weir={weir_stayer:.6f} "
            f"stayer_value_after_return_P0_whole={whole_stayer:.6f} "
            f"whole_dump_stayer_loss={stayer_loss:.6f}"
        )


def half_excess_balance():
    print("CASE 4: _balance half-excess on caller input 100+100 at displaced live price")
    print("  CP approximation: zero fees, k=100000000; placement uses post-swap live price")
    invariant = 100_000_000.0
    for price in (2.0, 4.0):
        amount0 = 100.0
        amount1 = 100.0
        reserve0 = math.sqrt(invariant / price)
        reserve1 = math.sqrt(invariant * price)
        amount0_in_1 = amount0 * price
        assert amount0_in_1 > amount1
        amount_in = (amount0 - amount1 / price) / 2.0
        amount_out = reserve1 * amount_in / (reserve0 + amount_in)
        new0 = amount0 - amount_in
        new1 = amount1 + amount_out
        post_reserve0 = reserve0 + amount_in
        post_reserve1 = reserve1 - amount_out
        post_price = post_reserve1 / post_reserve0
        result = placement(post_price, new0, new1)
        minted_shares = result["dL"] * EXISTING_S / EXISTING_L
        print(
            f"P'_before_balance={price:.0f} caller_token0_swapped={amount_in:.6f} "
            f"caller_token1_out={amount_out:.6f} post_swap_price={post_price:.6f} "
            f"n0={new0:.6f} n1={new1:.6f}"
        )
        print_placement("  post_balance_placement", result)
        print(
            f"  minted_shares={minted_shares:.6f} vault_idle_used_by_balance=0 "
            f"price_reference_check=none existing_holder_loss_from_issuance=0.000000"
        )


def main():
    print("FIXTURE: P0=1; infinite-range LiquidityAmounts limit; L=S=1000; no fees or rounding")
    external_push()
    self_moved_trailing()
    whole_balance_dump()
    half_excess_balance()
    print("IDENTITY: placement shortfall = placed0 + placed1 - recovered0 - recovered1 at P0=1")
    print("IDENTITY: audit IL equals direct placed-amount shortfall in this infinite-range limit")
    print("IDENTITY: Weir withdraw swaps only net1 (zapTo=1) or net0 (zapTo=2) from the withdrawn slice")


if __name__ == "__main__":
    main()
