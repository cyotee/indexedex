from __future__ import annotations

Q96 = 1 << 96
MAX_SWAP_FEE = 1_000_000
MIN_SQRT_RATIO = 4295128739
MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342


def mul_div(a: int, b: int, denominator: int) -> int:
    if denominator == 0:
        raise ZeroDivisionError("mul_div denominator")
    return (a * b) // denominator


def mul_div_up(a: int, b: int, denominator: int) -> int:
    if denominator == 0:
        raise ZeroDivisionError("mul_div_up denominator")
    product = a * b
    if product == 0:
        return 0
    return (product + denominator - 1) // denominator


def div_up(numerator: int, denominator: int) -> int:
    if denominator == 0:
        raise ZeroDivisionError("div_up")
    if numerator == 0:
        return 0
    return (numerator + denominator - 1) // denominator


def get_amount0_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    if sqrt_a > sqrt_b:
        sqrt_a, sqrt_b = sqrt_b, sqrt_a
    if sqrt_a == 0:
        raise ValueError("InvalidPrice")
    numerator1 = liquidity << 96
    numerator2 = sqrt_b - sqrt_a
    if round_up:
        return div_up(mul_div_up(numerator1, numerator2, sqrt_b), sqrt_a)
    return mul_div(numerator1, numerator2, sqrt_b) // sqrt_a


def get_amount1_delta(sqrt_a: int, sqrt_b: int, liquidity: int, round_up: bool) -> int:
    numerator = abs(sqrt_a - sqrt_b)
    result = mul_div(liquidity, numerator, Q96)
    if round_up and (liquidity * numerator) % Q96:
        result += 1
    return result


def get_next_sqrt_price_from_amount0_rounding_up(sqrt_p: int, liquidity: int, amount: int, add: bool) -> int:
    if amount == 0:
        return sqrt_p
    numerator1 = liquidity << 96
    if add:
        product = amount * sqrt_p
        if product // amount == sqrt_p:
            denominator = numerator1 + product
            if denominator >= numerator1:
                return mul_div_up(numerator1, sqrt_p, denominator)
        return div_up(numerator1, (numerator1 // sqrt_p) + amount)
    product = amount * sqrt_p
    if product // amount != sqrt_p or numerator1 <= product:
        raise ValueError("PriceOverflow")
    return mul_div_up(numerator1, sqrt_p, numerator1 - product)


def get_next_sqrt_price_from_amount1_rounding_down(sqrt_p: int, liquidity: int, amount: int, add: bool) -> int:
    if add:
        if amount <= (1 << 160) - 1:
            quotient = (amount << 96) // liquidity
        else:
            quotient = mul_div(amount, Q96, liquidity)
        return sqrt_p + quotient
    if amount <= (1 << 160) - 1:
        quotient = div_up(amount << 96, liquidity)
    else:
        quotient = mul_div_up(amount, Q96, liquidity)
    if sqrt_p <= quotient:
        raise ValueError("NotEnoughLiquidity")
    return sqrt_p - quotient


def get_next_sqrt_price_from_input(sqrt_p: int, liquidity: int, amount_in: int, zero_for_one: bool) -> int:
    if sqrt_p == 0 or liquidity == 0:
        raise ValueError("InvalidPriceOrLiquidity")
    if zero_for_one:
        return get_next_sqrt_price_from_amount0_rounding_up(sqrt_p, liquidity, amount_in, True)
    return get_next_sqrt_price_from_amount1_rounding_down(sqrt_p, liquidity, amount_in, True)


def get_next_sqrt_price_from_output(sqrt_p: int, liquidity: int, amount_out: int, zero_for_one: bool) -> int:
    if sqrt_p == 0 or liquidity == 0:
        raise ValueError("InvalidPriceOrLiquidity")
    if zero_for_one:
        return get_next_sqrt_price_from_amount1_rounding_down(sqrt_p, liquidity, amount_out, False)
    return get_next_sqrt_price_from_amount0_rounding_up(sqrt_p, liquidity, amount_out, False)


def compute_swap_step(
    sqrt_price_current: int,
    sqrt_price_target: int,
    liquidity: int,
    amount_remaining: int,
    fee_pips: int,
) -> tuple[int, int, int, int]:
    fee_pips = int(fee_pips)
    zero_for_one = sqrt_price_current >= sqrt_price_target
    exact_in = amount_remaining < 0
    if exact_in:
        amount_remaining_less_fee = mul_div(abs(amount_remaining), MAX_SWAP_FEE - fee_pips, MAX_SWAP_FEE)
        amount_in = (
            get_amount0_delta(sqrt_price_target, sqrt_price_current, liquidity, True)
            if zero_for_one
            else get_amount1_delta(sqrt_price_current, sqrt_price_target, liquidity, True)
        )
        if amount_remaining_less_fee >= amount_in:
            sqrt_next = sqrt_price_target
            if fee_pips == MAX_SWAP_FEE:
                fee_amount = amount_in
            else:
                fee_amount = mul_div_up(amount_in, fee_pips, MAX_SWAP_FEE - fee_pips)
        else:
            amount_in = amount_remaining_less_fee
            sqrt_next = get_next_sqrt_price_from_input(sqrt_price_current, liquidity, amount_remaining_less_fee, zero_for_one)
            fee_amount = abs(amount_remaining) - amount_in
        amount_out = (
            get_amount1_delta(sqrt_next, sqrt_price_current, liquidity, False)
            if zero_for_one
            else get_amount0_delta(sqrt_price_current, sqrt_next, liquidity, False)
        )
    else:
        amount_out = (
            get_amount1_delta(sqrt_price_target, sqrt_price_current, liquidity, False)
            if zero_for_one
            else get_amount0_delta(sqrt_price_current, sqrt_price_target, liquidity, False)
        )
        if amount_remaining >= amount_out:
            sqrt_next = sqrt_price_target
        else:
            amount_out = amount_remaining
            sqrt_next = get_next_sqrt_price_from_output(sqrt_price_current, liquidity, amount_out, zero_for_one)
        amount_in = (
            get_amount0_delta(sqrt_next, sqrt_price_current, liquidity, True)
            if zero_for_one
            else get_amount1_delta(sqrt_price_current, sqrt_next, liquidity, True)
        )
        if fee_pips == MAX_SWAP_FEE:
            raise ValueError("exact output fee cannot be 100 percent")
        fee_amount = mul_div_up(amount_in, fee_pips, MAX_SWAP_FEE - fee_pips)
    return sqrt_next, amount_in, amount_out, fee_amount


def single_exit(reserve_out: int, reserve_other: int, shares: int, supply: int) -> int:
    if shares == 0 or supply == 0:
        return 0
    if shares > supply or (shares == supply and reserve_other != 0):
        raise ValueError("InsufficientBacking")
    entitlement_out = (reserve_out * shares) // supply
    entitlement_other = (reserve_other * shares) // supply
    output = entitlement_out
    if entitlement_other != 0:
        output += ((reserve_out - entitlement_out) * entitlement_other) // reserve_other
    return output


def target_free(total: int, p_wad: int) -> int:
    return (total * p_wad) // (10**18 + p_wad)


def price_impact_wad(sqrt_before: int, sqrt_after: int) -> int:
    left = max(sqrt_before, sqrt_after) ** 2
    right = min(sqrt_before, sqrt_after) ** 2
    if right == 0:
        raise ValueError("zero price")
    return ((left - right) * 10**18) // right
