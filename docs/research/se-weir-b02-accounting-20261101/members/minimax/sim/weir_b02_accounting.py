#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, getcontext
from typing import Iterable

getcontext().prec = 60
D = Decimal
ZERO = D("0")
ONE = D("1")
AUDIT_TOLERANCE = D("1e-48")


def fmt(value: Decimal, places: int = 12) -> str:
    return f"{value:.{places}f}"


def liquidity_for_amounts(price: Decimal, amount0: Decimal, amount1: Decimal) -> Decimal:
    q = price.sqrt()
    return min(amount0 * q, amount1 / q)


def amounts_for_liquidity(price: Decimal, liquidity: Decimal) -> tuple[Decimal, Decimal]:
    q = price.sqrt()
    return liquidity / q, liquidity * q


def audit_il(liquidity: Decimal, price0: Decimal, price1: Decimal) -> Decimal:
    q0 = price0.sqrt()
    q1 = price1.sqrt()
    return liquidity * (q1 - q0) ** 2 / q1


@dataclass(frozen=True)
class ConstantProductPool:
    token0: Decimal
    token1: Decimal

    @property
    def k(self) -> Decimal:
        return self.token0 * self.token1

    @property
    def price(self) -> Decimal:
        return self.token1 / self.token0

    def swap_token1_for_token0(self, amount_in: Decimal) -> tuple[Decimal, Decimal]:
        new_token1 = self.token1 + amount_in
        new_token0 = self.k / new_token1
        amount_out0 = self.token0 - new_token0
        return amount_out0, new_token1 / new_token0

    def backrun_to_price(self, target_price: Decimal) -> tuple[Decimal, Decimal]:
        target_token0 = (self.k / target_price).sqrt()
        token0_in = target_token0 - self.token0
        new_token1 = self.k / target_token0
        return token0_in, self.token1 - new_token1


@dataclass(frozen=True)
class Placement:
    offered0: Decimal
    offered1: Decimal
    liquidity: Decimal
    placed0: Decimal
    placed1: Decimal
    leftover0: Decimal
    leftover1: Decimal
    recovered0: Decimal
    recovered1: Decimal
    initial_value_at_p0: Decimal
    final_value_at_p0: Decimal
    loss_token1: Decimal
    audit_loss_token1: Decimal

    @property
    def audit_difference(self) -> Decimal:
        return self.loss_token1 - self.audit_loss_token1

    @property
    def audit_matches(self) -> bool:
        return abs(self.audit_difference) <= AUDIT_TOLERANCE


def placement_at(
    amount0: Decimal,
    amount1: Decimal,
    price0: Decimal,
    placement_price: Decimal,
) -> Placement:
    liquidity = liquidity_for_amounts(placement_price, amount0, amount1)
    placed0, placed1 = amounts_for_liquidity(placement_price, liquidity)
    recovered0, recovered1 = amounts_for_liquidity(price0, liquidity)
    leftover0 = amount0 - placed0
    leftover1 = amount1 - placed1
    initial_value = amount0 * price0 + amount1
    final_value = (leftover0 + recovered0) * price0 + leftover1 + recovered1
    return Placement(
        offered0=amount0,
        offered1=amount1,
        liquidity=liquidity,
        placed0=placed0,
        placed1=placed1,
        leftover0=leftover0,
        leftover1=leftover1,
        recovered0=recovered0,
        recovered1=recovered1,
        initial_value_at_p0=initial_value,
        final_value_at_p0=final_value,
        loss_token1=initial_value - final_value,
        audit_loss_token1=audit_il(liquidity, price0, placement_price),
    )


def print_placement(label: str, result: Placement) -> None:
    print(f"  [{label}]")
    print(f"    offered token0/token1       = {fmt(result.offered0)}/{fmt(result.offered1)}")
    print(f"    liquidity added             = {fmt(result.liquidity)}")
    print(f"    token0/token1 placed        = {fmt(result.placed0)}/{fmt(result.placed1)}")
    print(f"    leftover token0/token1      = {fmt(result.leftover0)}/{fmt(result.leftover1)}")
    print(f"    token0/token1 recovered P0  = {fmt(result.recovered0)}/{fmt(result.recovered1)}")
    print(f"    initial value at P0         = {fmt(result.initial_value_at_p0)}")
    print(f"    final value at P0           = {fmt(result.final_value_at_p0)}")
    print(f"    direct shortfall token1     = {fmt(result.loss_token1)}")
    print(f"    audit IL approximation      = {fmt(result.audit_loss_token1)}")
    print(f"    absolute audit difference   = {fmt(abs(result.audit_difference), 30)}")
    print(f"    audit matches direct        = {result.audit_matches}")
    print()


def case_external_push(price0: Decimal, displaced_prices: Iterable[Decimal]) -> None:
    print("CASE 1: external push, then placement")
    print("  fixture: P0=1; balanced amount pair=100/100; existing liquidity L0=100; supply S=100")
    print("  share formula: added_liquidity * S / L0; idle is absent from the denominator")
    print("  Weir calls _compound before deposit/withdraw money operations")
    print()

    for price1 in displaced_prices:
        idle_result = placement_at(D("100"), D("100"), price0, price1)
        print_placement(f"vault idle placed at P'={fmt(price1, 0)}", idle_result)
        print("    all idle-placement loss is borne by existing holders")
        print("    one-sided idle at this price adds liquidity=0 and remains idle")
        print()

        new_shares = idle_result.liquidity * D("100") / D("100")
        total_position_value_at_p0 = D("200") + idle_result.recovered0 * price0 + idle_result.recovered1
        existing_holder_value_after = D("100") / (D("100") + new_shares) * total_position_value_at_p0
        caller_position_value = new_shares / (D("100") + new_shares) * total_position_value_at_p0
        caller_final_wealth = caller_position_value + idle_result.leftover0 * price0 + idle_result.leftover1
        caller_loss = idle_result.initial_value_at_p0 - caller_final_wealth
        print(f"  [same placement funded by a caller deposit at P'={fmt(price1, 0)}]")
        print(f"    new shares                  = {fmt(new_shares)}")
        print(f"    existing-holder value change= {fmt(existing_holder_value_after - D('200'))}")
        print(f"    caller final wealth at P0   = {fmt(caller_final_wealth)}")
        print(f"    caller placement loss       = {fmt(caller_loss)}")
        print("    caller loss is isolated from existing holders by proportional issuance")
        print()


def case_self_moved_trailing(price0: Decimal, displaced_prices: Iterable[Decimal]) -> None:
    print("CASE 2: self-moved trailing placement after a withdraw zap")
    print("  fixture: L0=100; S=100; exit fraction=1/3; later-compound idle=10/10")
    print("  zero-fee constant-product approximation supplies the post-swap live price")
    print("  source order is _compound then _withdraw, so the withdrawal cannot compound in the same call")
    print()

    exit_fraction = D(1) / D(3)
    withdrawn_liquidity = D("100") * exit_fraction
    withdrawn_net0 = withdrawn_liquidity
    withdrawn_net1 = withdrawn_liquidity

    for target_price in displaced_prices:
        initial_reserve = withdrawn_net1 / (target_price.sqrt() - ONE)
        pool = ConstantProductPool(initial_reserve, initial_reserve)
        amount_out0, post_swap_price = pool.swap_token1_for_token0(withdrawn_net1)
        trailing = placement_at(D("10"), D("10"), price0, post_swap_price)
        remaining_shares = D("100") * (ONE - exit_fraction)

        print(f"  [target post-swap price P'={fmt(target_price, 0)}]")
        print(f"    withdrawn net0/net1         = {fmt(withdrawn_net0)}/{fmt(withdrawn_net1)}")
        print(f"    _swap amount identity       = {fmt(withdrawn_net1)}")
        print(f"    token0 out (CP approximation)= {fmt(amount_out0)}")
        print(f"    post-swap live price        = {fmt(post_swap_price)}")
        print("    sold slice is the withdrawn net, not the whole vault balance")
        print_placement("later compound of booked idle at the moved live price", trailing)
        print(f"    remaining holders           = {fmt(remaining_shares)} shares")
        print(f"    loss borne by remaining holders = {fmt(trailing.loss_token1)}")
        print(f"    loss per remaining share       = {fmt(trailing.loss_token1 / remaining_shares, 15)}")
        print()


def case_whole_balance_dump(price0: Decimal) -> None:
    print("CASE 3: whole-balance dump versus Weir withdrawn-net swap")
    print("  fixture: opposing inventory B=100; exit fraction=2/3; pool reserves=1000/1000")
    print("  both swaps use the same source limit; the zero-fee CP model only prices their paths")
    print("  exit holder receives its fixed P0 token0 entitlement; residual value belongs to staker")
    print()

    inventory = D("100")
    exit_fraction = D(2) / D(3)
    weir_amount = inventory * exit_fraction
    dump_amount = inventory
    pool = ConstantProductPool(D("1000"), D("1000"))

    weir_out0, weir_price = pool.swap_token1_for_token0(weir_amount)
    dump_out0, dump_price = pool.swap_token1_for_token0(dump_amount)
    weir_state = ConstantProductPool(pool.token0 - weir_out0, pool.token1 + weir_amount)
    dump_state = ConstantProductPool(pool.token0 - dump_out0, pool.token1 + dump_amount)
    weir_backrun0, weir_backrun1 = weir_state.backrun_to_price(price0)
    dump_backrun0, dump_backrun1 = dump_state.backrun_to_price(price0)

    print(f"  Weir withdrawn-net amount       = {fmt(weir_amount)}")
    print(f"  024 whole-balance amount        = {fmt(dump_amount)}")
    print(f"  extra staker inventory sold     = {fmt(dump_amount - weir_amount)}")
    print(f"  Weir post-swap price             = {fmt(weir_price)}")
    print(f"  dump post-swap price             = {fmt(dump_price)}")
    print(f"  Weir token0 out / price slippage= {fmt(weir_out0)}/{fmt(weir_amount - weir_out0)}")
    print(f"  dump token0 out / price slippage= {fmt(dump_out0)}/{fmt(dump_amount - dump_out0)}")
    print(f"  return-to-P0 Weir input/output   = {fmt(weir_backrun0)}/{fmt(weir_backrun1)}")
    print(f"  return-to-P0 dump input/output   = {fmt(dump_backrun0)}/{fmt(dump_backrun1)}")
    exit_proceeds = weir_out0
    weir_staker_token1 = inventory - weir_amount
    weir_staker_value = weir_staker_token1


    dump_staker_token0 = dump_out0 - exit_proceeds
    dump_stayer_value = dump_staker_token0
    print(f"  exit proceeds at P0-equivalent  = {fmt(exit_proceeds)} token0")
    print(f"  Weir swap proceeds              = {fmt(weir_out0)} token0")
    print(f"  dump swap proceeds              = {fmt(dump_out0)} token0")
    print(f"  staker value at P0, Weir         = {fmt(weir_staker_value)}")
    print(f"  staker residual token0, dump    = {fmt(dump_staker_token0)}")
    print(f"  stayer value loss, dump vs Weir  = {fmt(weir_staker_value - dump_stayer_value)}")
    print("  model allocation: exit receives the Weir-path proceeds; staker receives the dump residual")
    print("  Weir has no whole-opposing-balance redemption swap")
    print()


def case_half_excess_balance(price0: Decimal, displaced_prices: Iterable[Decimal]) -> None:
    print("CASE 4: half-excess _balance at the live price")
    print("  fixture: one-sided token1 deposit=100; existing L0=100; supply S=100")
    print("  _balance uses the pre-swap live price; _deposit sizes at the post-swap live price")
    print()

    scenarios: list[tuple[str, ConstantProductPool]] = [
        ("no push, P=1", ConstantProductPool(D("1000"), D("1000")))
    ]
    for price in displaced_prices:
        scenarios.append((f"external push, P={fmt(price, 0)}", ConstantProductPool(D("1000") / price, D("1000"))))

    for label, pool in scenarios:
        amount0 = ZERO
        amount1 = D("100")
        amount0_in_token1 = amount0 * pool.price
        swap_input = (amount1 - amount0_in_token1) / D(2)
        amount_out0, post_swap_price = pool.swap_token1_for_token0(swap_input)
        balanced0 = amount_out0
        balanced1 = amount1 - swap_input
        added_liquidity = liquidity_for_amounts(post_swap_price, balanced0, balanced1)
        placed0, placed1 = amounts_for_liquidity(post_swap_price, added_liquidity)
        credit0 = balanced0 - placed0
        recovered0, recovered1 = amounts_for_liquidity(price0, added_liquidity)
        new_shares = added_liquidity * D("100") / D("100")
        total_position_value_at_p0 = (D("100") + added_liquidity) * (D("2") * price0.sqrt())
        existing_holder_value_after = D("100") / (D("100") + new_shares) * total_position_value_at_p0
        caller_final_value = recovered0 * price0 + recovered1 + credit0 * price0
        caller_loss = amount1 - caller_final_value

        print(f"  [{label}]")
        print(f"    live price before _balance    = {fmt(pool.price)}")
        print(f"    half-excess swap input         = {fmt(swap_input)}")
        print(f"    token0 out / post-swap price   = {fmt(amount_out0)}/{fmt(post_swap_price)}")
        print(f"    balanced n0/n1                = {fmt(balanced0)}/{fmt(balanced1)}")
        print(f"    liquidity sized at live price = {fmt(added_liquidity)}")
        print(f"    token0/token1 placed          = {fmt(placed0)}/{fmt(placed1)}")
        print(f"    token0 credit to caller       = {fmt(credit0)}")
        print(f"    token0/token1 recovered P0    = {fmt(recovered0)}/{fmt(recovered1)}")
        print(f"    caller loss at P0              = {fmt(caller_loss)}")
        print(f"    existing-holder value change  = {fmt(existing_holder_value_after - D('200'))}")
        print()


def main() -> None:
    price0 = ONE
    displaced_prices = (D("2"), D("4"))
    case_external_push(price0, displaced_prices)
    case_self_moved_trailing(price0, displaced_prices)
    case_whole_balance_dump(price0)
    case_half_excess_balance(price0, displaced_prices)

    for price1 in displaced_prices:
        result = placement_at(D("100"), D("100"), price0, price1)
        assert result.audit_matches
    assert liquidity_for_amounts(price0, ZERO, D("100")) == ZERO
    assert liquidity_for_amounts(price0, D("100"), ZERO) == ZERO
    print("All direct-versus-audit and one-sided-liquidity assertions passed.")


if __name__ == "__main__":
    main()
