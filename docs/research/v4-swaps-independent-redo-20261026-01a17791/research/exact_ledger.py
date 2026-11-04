"""Exact rational single-interval evidence, not an EVM or Wings reproduction.

Token0 is opposing, token1 target. Initial sqrt price is 1, vault core L=100.
Ambient L=100/fraction-100. Fees are separate claims, as in V3/V4, not
automatically reinvested. Matched entrant tokens add core liquidity; surplus
stays idle (equivalently an inactive wing ONLY while no boundary is crossed).
No hook, protocol fee, debt, JIT, gas charge or external liquidation.
Run: python3 docs/research/v4-swaps-independent-redo-20261026-01a17791/research/exact_ledger.py
"""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction as F
from typing import assert_never


class Rule(Enum):
    """The explicit issuance cutoff; exits always pay actual slice proceeds."""

    EXECUTION = "post_swap_balances_at_execution_average"
    PROPORTIONAL = "position_vector_with_refund"
    NO_JOIN = "swap_and_reverse_without_vault_join"


@dataclass(frozen=True, slots=True)
class Result:
    """Closed token claims and action amounts, all exact rational numbers."""

    rule: Rule
    vault_fraction: F
    deposit: F
    split: F
    fee: F
    entry_output: F
    entry_fee: F
    old_vault_target_fee: F
    execution_price: F
    old_book_mark: F
    minted_per_old_share: F
    core_added: F
    surplus_other: F
    surplus_target: F
    withdrawn_other: F
    withdrawn_target: F
    exit_fee: F
    exit_output: F
    final_target: F
    profit_target: F
    incumbent_other: F
    incumbent_target: F
    ambient_other: F
    ambient_target: F
    conservation_other: F
    conservation_target: F


def run(rule: Rule, fraction: F = F(1), deposit: F = F(200),
        split: F = F(1, 2), fee: F = F(3, 1000)) -> Result:
    """Execute entry, fee checkpoint, funded join, slice burn and actual sale."""
    total_l = F(100) / fraction
    ambient_l = total_l - 100
    spent = deposit * split
    effective = spent * (1 - fee)
    sqrt_price = 1 + effective / total_l
    pool_x = total_l / sqrt_price
    pool_y = total_l * sqrt_price
    acquired = total_l - pool_x
    entry_fee = spent * fee
    vault_fee = fraction * entry_fee
    ambient_fee = (1 - fraction) * entry_fee
    remaining = deposit - spent
    price = spent / acquired
    book = F(100) / sqrt_price * price + 100 * sqrt_price + vault_fee

    match rule:
        case Rule.EXECUTION:
            ratio = (remaining + price * acquired) / book
            added = min(acquired * sqrt_price, remaining / sqrt_price)
            idle_x = acquired - added / sqrt_price
            idle_y = vault_fee + remaining - added * sqrt_price
            refund_x, refund_y = F(0), F(0)
        case Rule.PROPORTIONAL:
            ratio = min(acquired / (100 / sqrt_price),
                        remaining / (100 * sqrt_price + vault_fee))
            added = 100 * ratio
            idle_x = F(0)
            idle_y = vault_fee * (1 + ratio)
            refund_x = acquired - added / sqrt_price
            refund_y = remaining - ratio * (100 * sqrt_price + vault_fee)
        case Rule.NO_JOIN:
            ratio, added, idle_x = F(0), F(0), F(0)
            idle_y = vault_fee
            refund_x, refund_y = acquired, remaining
        case unreachable:
            assert_never(unreachable)

    pool_x += added / sqrt_price
    pool_y += added * sqrt_price
    actor_fraction = ratio / (1 + ratio)
    removed_l = actor_fraction * (100 + added)
    withdrawn_x = removed_l / sqrt_price + actor_fraction * idle_x
    withdrawn_y = removed_l * sqrt_price + actor_fraction * idle_y
    pool_x -= removed_l / sqrt_price
    pool_y -= removed_l * sqrt_price
    final_idle_x = idle_x * (1 - actor_fraction)
    final_idle_y = idle_y * (1 - actor_fraction)
    remaining_vault_l = 100 + added - removed_l
    remaining_total_l = total_l + added - removed_l

    # One exact-in sale includes any refunded opposing tokens. Separate sequential
    # sales with fees are a different path, not silently equivalent.
    sold = withdrawn_x + refund_x
    effective_sale = sold * (1 - fee)
    final_sqrt = remaining_total_l * sqrt_price / (
        remaining_total_l + effective_sale * sqrt_price)
    output = remaining_total_l * (sqrt_price - final_sqrt)
    pool_x += sold
    pool_y -= output
    exit_fee = sold * fee
    vault_exit_fee = exit_fee * remaining_vault_l / remaining_total_l
    ambient_exit_fee = exit_fee * ambient_l / remaining_total_l
    incumbent_x = remaining_vault_l / final_sqrt + final_idle_x + vault_exit_fee
    incumbent_y = remaining_vault_l * final_sqrt + final_idle_y
    ambient_x = ambient_l / final_sqrt + ambient_exit_fee
    ambient_y = ambient_l * final_sqrt + ambient_fee
    final_target = withdrawn_y + refund_y + output
    error_x = incumbent_x + ambient_x - total_l
    error_y = incumbent_y + ambient_y + final_target - total_l - deposit
    assert error_x == 0 and error_y == 0
    assert pool_x + final_idle_x == incumbent_x + ambient_x
    assert pool_y + final_idle_y + ambient_fee == incumbent_y + ambient_y
    assert min(final_idle_x, final_idle_y, refund_x, refund_y) >= 0
    return Result(
        rule, fraction, deposit, split, fee, acquired, entry_fee, vault_fee,
        price, book, ratio, added, idle_x, idle_y - vault_fee,
        withdrawn_x, withdrawn_y, exit_fee, output, final_target,
        final_target - deposit, incumbent_x, incumbent_y, ambient_x, ambient_y,
        error_x, error_y,
    )


def main() -> None:
    """Print selected ledgers and a finite fee/depth/split grid."""
    for rule in Rule:
        result = run(rule)
        print(result)
        print("target_profit_decimal", float(result.profit_target))
    for fraction in (F(1, 100), F(1, 10), F(1, 2), F(9, 10), F(99, 100), F(1)):
        for split in (F(49, 100), F(1, 2), F(51, 100)):
            result = run(Rule.EXECUTION, fraction=fraction, split=split)
            print("depth_split", fraction, split, float(result.profit_target))
    positive = 0
    cases = 0
    for fraction in (F(1, 100), F(1, 10), F(1, 2), F(9, 10), F(99, 100), F(1)):
        for fee in (F(0), F(5, 10000), F(3, 1000), F(1, 100)):
            for split in (F(49, 100), F(1, 2), F(51, 100)):
                for deposit in (F(2), F(20), F(200), F(2000)):
                    result = run(Rule.EXECUTION, fraction, deposit, split, fee)
                    positive += result.profit_target > 0
                    cases += 1
                    control = run(Rule.PROPORTIONAL, fraction, deposit, split, fee)
                    assert control.profit_target <= 0
    print("execution_positive_cases", positive, "total_cases", cases)


if __name__ == "__main__":
    main()
