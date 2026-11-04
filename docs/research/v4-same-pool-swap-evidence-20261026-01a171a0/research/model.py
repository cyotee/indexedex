"""Standalone integer research model, not a production-vault or EVM test.

Token0 is opposing, token1 is target; both have 18 decimals. All initial
liquidity is full-range at sqrt price 1. The vault initially owns one core.
Its entry swap is executed, incumbents' earned fees are collected, entrant
inventory funds the core and an inactive upper wing, then shares are minted.
The entrant immediately removes its slice and actually sells that opposing.

Single-active-interval arithmetic follows the repository's V4 TickMath,
SqrtPriceMath, SwapMath and V3 LiquidityAmounts. There are no hooks, protocol
fees, other initialized ticks, forced fee compounding or converted-wing
maintenance. The upper wing is funded after entry above the current price;
the subsequent token0 sales move down, so that wing never becomes active.
All unmatched dust remains credited idle, or is explicitly refunded in the
strictly proportional control. Pool custody is tracked separately from LP
claims, including fee-growth and funding/removal rounding residual.

Run with: python3 <this file>. Uses only the Python standard library and
prints JSON; it never writes a file, imports project code or runs Forge.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from decimal import Decimal, localcontext
from enum import StrEnum
from fractions import Fraction
from math import isqrt

Q96 = 1 << 96
Q128 = 1 << 128
UNIT = 10**18
FEE_DENOMINATOR = 1_000_000
SPACING = 60
MIN_TICK = -887_220
MAX_TICK = 887_220
TICK_MULTIPLIERS = (
    0xFFFCB933BD6FAD37AA2D162D1A594001,
    0xFFF97272373D413259A46990580E213A,
    0xFFF2E50F5F656932EF12357CF3C7FDCC,
    0xFFE5CACA7E10E4E61C3624EAA0941CD0,
    0xFFCB9843D60F6159C9DB58835C926644,
    0xFF973B41FA98C081472E6896DFB254C0,
    0xFF2EA16466C96A3843EC78B326B52861,
    0xFE5DEE046A99A2A811C461F1969C3053,
    0xFCBE86C7900A88AEDCFFDC83B479AA3A4,
    0xF987A7253AC413176F2B074CF7815E54,
    0xF3392B0822B70005940C7A398E4B70F3,
    0xE7159475A2C29B7443B29C7FA6E889D9,
    0xD097F3BDFD2022B8845AD8F792AA5825,
    0xA9F746462D870FDF8A65DC1F90E061E5,
    0x70D869A156D2A1B890BB3DF62BAF32F7,
    0x31BE135F97D08FD981231505542FCFA6,
    0x9AA508B5B7A84E1C677DE54F3E99BC9,
    0x5D6AF8DEDB81196699C329225EE604,
    0x2216E584F5FA1EA926041BEDFE98,
    0x48A170391F7DC42444E8FA2,
)


class ModelDomainError(ValueError):
    """The specified case leaves the model's disclosed execution domain."""


class ConservationError(ArithmeticError):
    """A native-token ledger or claim bound failed."""


class MintRule(StrEnum):
    EXECUTED_BALANCES = "executed_average_actual_composition"
    SPOT_BALANCES = "post_swap_spot_actual_composition"
    EXECUTED_RANGES = "executed_average_reference_ranges"
    ANCHOR_RANGES = "ideal_historical_one_reference_ranges"
    PROPORTIONAL = "proportional_vector_refund_control"


def ceil_div(numerator: int, denominator: int) -> int:
    """Divide nonnegative integer funding upward."""
    if numerator < 0 or denominator <= 0:
        raise ModelDomainError("Invalid positive funding division.")
    return (numerator + denominator - 1) // denominator


def tick_sqrt(tick: int) -> int:
    """Port the source TickMath bit products and final Q96 rounding."""
    if abs(tick) > 887_272:
        raise ModelDomainError("Tick outside V4 TickMath bounds.")
    ratio = 1 << 128
    for bit, multiplier in enumerate(TICK_MULTIPLIERS):
        if abs(tick) & (1 << bit):
            ratio = ratio * multiplier >> 128
    if tick > 0:
        ratio = ((1 << 256) - 1) // ratio
    return ceil_div(ratio, 1 << 32)


LOWER = tick_sqrt(MIN_TICK)
UPPER = tick_sqrt(MAX_TICK)


def delta0(lower: int, upper: int, liquidity: int, *, up: bool) -> int:
    """Token0 delta for positive liquidity, with source funding direction."""
    numerator = liquidity * Q96 * (upper - lower)
    denominator = upper * lower
    return ceil_div(numerator, denominator) if up else numerator // denominator


def delta1(lower: int, upper: int, liquidity: int, *, up: bool) -> int:
    """Token1 delta for positive liquidity, with source funding direction."""
    numerator = liquidity * (upper - lower)
    return ceil_div(numerator, Q96) if up else numerator // Q96


def principal(liquidity: int, sqrt_price: int, lower: int = LOWER,
              upper: int = UPPER, *, up: bool = False) -> tuple[int, int]:
    """Compute actual or reference composition at the supplied sqrt price."""
    price = min(max(sqrt_price, lower), upper)
    return (
        delta0(price, upper, liquidity, up=up),
        delta1(lower, price, liquidity, up=up),
    )


def core_liquidity(other: int, target: int, sqrt_price: int) -> int:
    """LiquidityAmounts floor arithmetic for an in-range core addition."""
    intermediate = sqrt_price * UPPER // Q96
    by_other = other * intermediate // (UPPER - sqrt_price)
    by_target = target * Q96 // (sqrt_price - LOWER)
    return min(by_other, by_target)


def next_upper_tick(sqrt_price: int) -> int:
    """Find the first strict tick-spacing boundary above current price."""
    low = MIN_TICK // SPACING
    high = MAX_TICK // SPACING
    while low < high:
        middle = (low + high) // 2
        if tick_sqrt(middle * SPACING) > sqrt_price:
            high = middle
        else:
            low = middle + 1
    boundary = low * SPACING
    if boundary >= MAX_TICK:
        raise ModelDomainError("No nonempty upper-wing range.")
    return boundary


def mark(other: int, target: int, price: Fraction) -> Fraction:
    """Mark native token amounts at one explicitly chosen, nontrusted price."""
    return target + other * price


def whole(atoms: int) -> str:
    """Format values for humans without using float in the arithmetic."""
    with localcontext() as context:
        context.prec = 40
        return str(Decimal(atoms) / Decimal(UNIT))


@dataclass
class Pool:
    """One active core interval plus actual manager token custody."""

    sqrt_price: int
    liquidity: int
    other: int
    target: int
    fee_pips: int
    growth0: int = 0
    growth1: int = 0

    def swap(self, amount: int, *, target_in: bool) -> tuple[int, int]:
        """Execute exact input without crossing an active interval boundary."""
        if amount <= 0 or self.liquidity <= 0:
            raise ModelDomainError("A swap needs positive input and liquidity.")
        less_fee = amount * (FEE_DENOMINATOR - self.fee_pips) // FEE_DENOMINATOR
        old = self.sqrt_price
        if target_in:
            new = old + less_fee * Q96 // self.liquidity
            if new >= UPPER:
                raise ModelDomainError("Entry crossed the core upper bound.")
            consumed = delta1(old, new, self.liquidity, up=True)
            output = delta0(old, new, self.liquidity, up=False)
            self.target += amount
            self.other -= output
        else:
            numerator = self.liquidity * Q96
            new = ceil_div(numerator * old, numerator + less_fee * old)
            if new <= LOWER:
                raise ModelDomainError("Exit crossed the core lower bound.")
            consumed = delta0(new, old, self.liquidity, up=True)
            output = delta1(new, old, self.liquidity, up=False)
            self.other += amount
            self.target -= output
        if consumed > amount or min(self.other, self.target) < 0:
            raise ConservationError("Swap funding/custody mismatch.")
        fee = amount - consumed
        if target_in:
            self.growth1 += fee * Q128 // self.liquidity
        else:
            self.growth0 += fee * Q128 // self.liquidity
        self.sqrt_price = new
        return output, fee


@dataclass(frozen=True)
class Case:
    rule: MintRule
    fee_pips: int = 3000
    vault_fraction: Fraction = Fraction(1)
    deposit_target: int = 200 * UNIT
    swap_fraction: Fraction = Fraction(1, 2)


@dataclass(frozen=True)
class Event:
    action: str
    pool_sqrt_q96: int
    active_liquidity: int
    pool_other_atoms: int
    pool_target_atoms: int
    vault_idle_other_atoms: int
    vault_idle_target_atoms: int
    actor_other_atoms: int
    actor_target_atoms: int
    detail: str


@dataclass(frozen=True)
class Outcome:
    rule: str
    fee_pips: int
    actual_initial_vault_fraction: str
    deposit_target_atoms: int
    swap_fraction: str
    net_target_atoms: int
    net_target_whole: str
    final_actor_other_atoms: int
    minted_share_atoms: int
    core_added: int
    upper_added: int
    upper_lower_tick: int
    old_equity_price: str
    old_equity_mark_atoms: str
    credited_mark_atoms: str
    incumbent_target_claim_atoms: int
    incumbent_other_claim_atoms: int
    ambient_target_claim_atoms: int
    ambient_other_claim_atoms: int
    pool_target_residual_atoms: int
    pool_other_residual_atoms: int
    target_conservation_error_atoms: int
    other_conservation_error_atoms: int
    events: tuple[Event, ...]


def run_case(case: Case) -> Outcome:
    """Execute a closed target-funded deposit/exit and reconcile native ledgers."""
    if not 0 < case.vault_fraction <= 1 or not 0 < case.swap_fraction < 1:
        raise ModelDomainError("Fraction outside the case domain.")
    if not 0 <= case.fee_pips < FEE_DENOMINATOR:
        raise ModelDomainError("Invalid static LP fee.")
    old_liquidity = 100 * UNIT
    supply = 100 * UNIT
    total_liquidity = int(old_liquidity / case.vault_fraction)
    ambient = total_liquidity - old_liquidity
    vault_initial = principal(old_liquidity, Q96, up=True)
    ambient_initial = principal(ambient, Q96, up=True)
    pool = Pool(Q96, total_liquidity, vault_initial[0] + ambient_initial[0],
                vault_initial[1] + ambient_initial[1], case.fee_pips)
    initial_pool_other, initial_pool_target = pool.other, pool.target
    idle_other = 0
    idle_target = 0
    actor_other = 0
    actor_target = case.deposit_target
    events: list[Event] = []

    def record(action: str, detail: str) -> None:
        events.append(Event(action, pool.sqrt_price, pool.liquidity, pool.other,
                            pool.target, idle_other, idle_target, actor_other,
                            actor_target, detail))

    record("initial", "Actor has target only, no LP, opposing, shares or debt.")
    actor_target -= case.deposit_target
    swap_input = int(case.deposit_target * case.swap_fraction)
    entrant_other, entry_fee = pool.swap(swap_input, target_in=True)
    entrant_target = case.deposit_target - swap_input
    executed_price = Fraction(swap_input, entrant_other)
    record("entry_swap", f"target_in={swap_input}; opposing_out={entrant_other}; fee={entry_fee}")
    old_earned_target = old_liquidity * pool.growth1 // Q128
    idle_target += old_earned_target
    pool.target -= old_earned_target
    vault_checkpoint1 = pool.growth1
    old_other, old_target = principal(old_liquidity, pool.sqrt_price)
    old_target += idle_target
    record("incumbent_fee_checkpoint", f"old_target_fees={old_earned_target}")

    added = 0
    upper_added = 0
    wing_tick = next_upper_tick(pool.sqrt_price)
    wing_lower = tick_sqrt(wing_tick)
    entrant_idle_other = 0
    entrant_idle_target = 0
    if case.rule == MintRule.PROPORTIONAL:
        # Off-chain candidate search in this research control, not stateful zap.
        low, high = 0, supply * max(entrant_target, entrant_other) // max(1, old_target)
        while low < high:
            candidate = (low + high + 1) // 2
            liquidity = ceil_div(old_liquidity * candidate, supply)
            needs0, needs1 = principal(liquidity, pool.sqrt_price, up=True)
            needs1 += ceil_div(idle_target * candidate, supply)
            if needs0 <= entrant_other and needs1 <= entrant_target:
                low = candidate
            else:
                high = candidate - 1
        minted = low
        added = ceil_div(old_liquidity * minted, supply)
        paid0, paid1 = principal(added, pool.sqrt_price, up=True)
        entrant_idle_target = ceil_div(idle_target * minted, supply)
        actor_other += entrant_other - paid0
        actor_target += entrant_target - paid1 - entrant_idle_target
        price = Fraction(pool.sqrt_price**2, Q96**2)
        old_mark = mark(old_other, old_target, price)
        credit = Fraction(minted * old_mark, supply)
    else:
        added = core_liquidity(entrant_other, entrant_target, pool.sqrt_price)
        paid0, paid1 = principal(added, pool.sqrt_price, up=True)
        left0, left1 = entrant_other - paid0, entrant_target - paid1
        intermediate = wing_lower * UPPER // Q96
        upper_added = left0 * intermediate // (UPPER - wing_lower)
        wing_paid0 = delta0(wing_lower, UPPER, upper_added, up=True)
        entrant_idle_other = left0 - wing_paid0
        entrant_idle_target = left1
        if case.rule in (MintRule.EXECUTED_BALANCES, MintRule.EXECUTED_RANGES):
            price = executed_price
        elif case.rule == MintRule.SPOT_BALANCES:
            price = Fraction(pool.sqrt_price**2, Q96**2)
        else:
            price = Fraction(1)  # Ideal covered historical same-pool reference.
        reference_sqrt = isqrt(price.numerator * Q96**2 // price.denominator)
        if case.rule in (MintRule.EXECUTED_BALANCES, MintRule.SPOT_BALANCES):
            old_mark = mark(old_other, old_target, price)
            new0, new1 = principal(added, pool.sqrt_price)
            wing0, wing1 = principal(upper_added, pool.sqrt_price, wing_lower)
        else:
            basis0, basis1 = principal(old_liquidity, reference_sqrt)
            old_mark = mark(basis0, basis1 + idle_target, price)
            new0, new1 = principal(added, reference_sqrt)
            wing0, wing1 = principal(upper_added, reference_sqrt, wing_lower)
        credit = mark(new0 + wing0 + entrant_idle_other,
                      new1 + wing1 + entrant_idle_target, price)
        minted_value = supply * credit / old_mark
        minted = minted_value.numerator // minted_value.denominator
    if minted <= 0 or added < 0 or min(entrant_idle_other, entrant_idle_target) < 0:
        raise ModelDomainError("Unfundable/zero mint.")

    pool.other += paid0
    pool.target += paid1
    if upper_added:
        pool.other += delta0(wing_lower, UPPER, upper_added, up=True)
    pool.liquidity += added
    idle_other += entrant_idle_other
    idle_target += entrant_idle_target
    core_liquidity_after = old_liquidity + added
    supply_after = supply + minted
    record("add_and_mint", f"core_added={added}; upper_added={upper_added}; shares={minted}")

    remove_core = core_liquidity_after * minted // supply_after
    remove_wing = upper_added * minted // supply_after
    slice0, slice1 = principal(remove_core, pool.sqrt_price)
    wing0, wing1 = principal(remove_wing, pool.sqrt_price, wing_lower)
    slice0 += wing0
    slice1 += wing1
    pool.other -= slice0
    pool.target -= slice1
    pool.liquidity -= remove_core
    local0 = idle_other * minted // supply_after
    local1 = idle_target * minted // supply_after
    idle_other -= local0
    idle_target -= local1
    slice0 += local0
    slice1 += local1
    record("withdraw_slice", f"slice_other={slice0}; slice_target={slice1}")
    converted_target, exit_fee = pool.swap(slice0, target_in=False)
    actor_target += slice1 + converted_target
    record("exit_swap", f"opposing_in={slice0}; target_out={converted_target}; fee={exit_fee}")
    if actor_other:
        refunded = actor_other
        converted_refund, _ = pool.swap(refunded, target_in=False)
        actor_other = 0
        actor_target += converted_refund
        record("liquidate_owned_refund", f"opposing_in={refunded}; target_out={converted_refund}")

    vault_remaining = core_liquidity_after - remove_core
    remaining_wing = upper_added - remove_wing
    incumbent0, incumbent1 = principal(vault_remaining, pool.sqrt_price)
    final_wing0, final_wing1 = principal(remaining_wing, pool.sqrt_price, wing_lower)
    incumbent0 += final_wing0 + idle_other + vault_remaining * pool.growth0 // Q128
    incumbent1 += final_wing1 + idle_target
    incumbent1 += vault_remaining * (pool.growth1 - vault_checkpoint1) // Q128
    ambient0, ambient1 = principal(ambient, pool.sqrt_price)
    ambient0 += ambient * pool.growth0 // Q128
    ambient1 += ambient * pool.growth1 // Q128
    residual0 = pool.other - (incumbent0 - idle_other) - ambient0
    residual1 = pool.target - (incumbent1 - idle_target) - ambient1
    error0 = pool.other + idle_other + actor_other - initial_pool_other
    error1 = pool.target + idle_target + actor_target - initial_pool_target - case.deposit_target
    if error0 or error1 or min(residual0, residual1) < 0:
        raise ConservationError(f"Ledger failed: {error0=}, {error1=}, {residual0=}, {residual1=}")
    record("final", "No actor opposing, LP, vault shares, debt or unresolved exposure.")
    net = actor_target - case.deposit_target
    return Outcome(case.rule.value, case.fee_pips,
                   str(Fraction(old_liquidity, total_liquidity)), case.deposit_target,
                   str(case.swap_fraction), net, whole(net), actor_other, minted, added,
                   upper_added, wing_tick, str(price), str(old_mark), str(credit),
                   incumbent1, incumbent0, ambient1, ambient0, residual1, residual0,
                   error1, error0, tuple(events))


def research_results() -> dict[str, object]:
    """Return selected full ledgers and a finite, explicitly bounded search."""
    selected = [
        run_case(Case(rule=rule))
        for rule in MintRule
    ]
    rows: list[dict[str, str | int]] = []
    for rule in MintRule:
        for fee in (0, 500, 3000, 10_000):
            for fraction in (Fraction(1, 100), Fraction(1, 10), Fraction(1, 2),
                             Fraction(9, 10), Fraction(99, 100), Fraction(1)):
                result = run_case(Case(rule=rule, fee_pips=fee, vault_fraction=fraction))
                rows.append({"rule": result.rule, "fee_pips": fee,
                             "vault_fraction": result.actual_initial_vault_fraction,
                             "net_target_atoms": result.net_target_atoms,
                             "net_target_whole": result.net_target_whole})
    size_rows: list[dict[str, str | int]] = []
    for deposit in (2, 20, 200, 2000):
        for split in (Fraction(49, 100), Fraction(1, 2), Fraction(51, 100)):
            result = run_case(Case(rule=MintRule.EXECUTED_BALANCES,
                                   deposit_target=deposit * UNIT, swap_fraction=split))
            size_rows.append({"deposit_target_whole": deposit, "swap_fraction": str(split),
                              "fee_pips": 3000, "net_target_whole": result.net_target_whole})
    return {
        "classification": "standalone source-matched single-interval numerical model; NOT EVM/production validation",
        "assumptions": __doc__,
        "selected_full_ledgers": [asdict(result) for result in selected],
        "fee_depth_matrix": rows,
        "size_split_matrix": size_rows,
    }


if __name__ == "__main__":
    print(json.dumps(research_results(), indent=2))
