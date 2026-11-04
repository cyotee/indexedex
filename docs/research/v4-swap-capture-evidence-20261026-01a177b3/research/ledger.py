#!/usr/bin/env python3
"""Exact one-interval ledger. Not a Foundry run and not Wings lifecycle execution."""

from __future__ import annotations

import json
from dataclasses import dataclass
from fractions import Fraction as F
from pathlib import Path


def f(value: int | str | F) -> F:
    return value if isinstance(value, F) else F(value)


@dataclass
class Book:
    r0: F
    r1: F
    l_vault: F
    l_ext: F
    fee0_vault: F
    fee1_vault: F
    fee0_ext: F
    fee1_ext: F
    idle0: F
    idle1: F
    supply: F
    a0: F
    a1: F
    shares: F

    def copy(self) -> "Book":
        return Book(**self.__dict__.copy())

    @property
    def liquidity(self) -> F:
        return self.l_vault + self.l_ext

    def vault_curve(self) -> tuple[F, F]:
        liquid = self.liquidity
        if liquid == 0:
            return F(0), F(0)
        share = self.l_vault / liquid
        return share * self.r0, share * self.r1

    def vault_opposing(self) -> F:
        curve0, _ = self.vault_curve()
        return curve0 + self.idle0 + self.fee0_vault

    def vault_target(self) -> F:
        _, curve1 = self.vault_curve()
        return curve1 + self.idle1 + self.fee1_vault

    def totals(self) -> tuple[F, F]:
        return (
            self.a0 + self.r0 + self.fee0_vault + self.fee0_ext + self.idle0,
            self.a1 + self.r1 + self.fee1_vault + self.fee1_ext + self.idle1,
        )


def swap(book: Book, amount_in: F, zero_for_one: bool, fee_pips: int) -> dict[str, F]:
    if amount_in < 0:
        raise AssertionError("negative swap")
    if amount_in == 0:
        return {"fee": F(0), "curve_in": F(0), "out": F(0)}
    liquid = book.liquidity
    if liquid == 0:
        raise AssertionError("swap against empty pool")
    fee = amount_in * fee_pips / 1_000_000
    curve_in = amount_in - fee
    product = book.r0 * book.r1
    if zero_for_one:
        new_r0 = book.r0 + curve_in
        new_r1 = product / new_r0
        out = book.r1 - new_r1
        book.r0, book.r1 = new_r0, new_r1
        book.a0 -= amount_in
        book.a1 += out
        fee_token = 0
    else:
        new_r1 = book.r1 + curve_in
        new_r0 = product / new_r1
        out = book.r0 - new_r0
        book.r0, book.r1 = new_r0, new_r1
        book.a1 -= amount_in
        book.a0 += out
        fee_token = 1
    h = book.l_vault / liquid
    if fee_token == 0:
        book.fee0_vault += h * fee
        book.fee0_ext += (1 - h) * fee
    else:
        book.fee1_vault += h * fee
        book.fee1_ext += (1 - h) * fee
    if out < 0 or book.a0 < 0 or book.a1 < 0:
        raise AssertionError("swap produced a negative balance")
    return {"fee": fee, "curve_in": curve_in, "out": out}


def add_vault_liquidity(book: Book, d0: F, d1: F) -> dict[str, F]:
    if d0 < 0 or d1 < 0:
        raise AssertionError("negative deposit tokens")
    liquid = book.liquidity
    if liquid == 0 or book.r0 == 0 or book.r1 == 0 or (d0 == 0 and d1 == 0):
        book.idle0 += d0
        book.idle1 += d1
        book.a0 -= d0
        book.a1 -= d1
        return {"used0": F(0), "used1": F(0), "d_l": F(0), "excess0": d0, "excess1": d1}
    d_l = min(d0 * liquid / book.r0, d1 * liquid / book.r1)
    used0 = d_l * book.r0 / liquid
    used1 = d_l * book.r1 / liquid
    excess0 = d0 - used0
    excess1 = d1 - used1
    if excess0 < 0 or excess1 < 0:
        raise AssertionError("liquidity add overspent")
    book.r0 += used0
    book.r1 += used1
    book.l_vault += d_l
    book.idle0 += excess0
    book.idle1 += excess1
    book.a0 -= d0
    book.a1 -= d1
    return {"used0": used0, "used1": used1, "d_l": d_l, "excess0": excess0, "excess1": excess1}


def remove_vault_fraction(book: Book, q: F) -> tuple[F, F]:
    if q < 0 or q > 1:
        raise AssertionError("bad share fraction")
    curve0, curve1 = book.vault_curve()
    out0 = q * (curve0 + book.idle0 + book.fee0_vault)
    out1 = q * (curve1 + book.idle1 + book.fee1_vault)
    if book.l_vault:
        removed_l = q * book.l_vault
        liquid = book.liquidity
        book.r0 -= removed_l * book.r0 / liquid
        book.r1 -= removed_l * book.r1 / liquid
        book.l_vault -= removed_l
    book.idle0 -= q * book.idle0
    book.idle1 -= q * book.idle1
    book.fee0_vault -= q * book.fee0_vault
    book.fee1_vault -= q * book.fee1_vault
    book.a0 += out0
    book.a1 += out1
    return out0, out1


def quote_target(book: Book, fee_pips: int) -> F:
    sim = book.copy()
    opposing = sim.vault_opposing()
    target = sim.vault_target()
    if sim.l_vault:
        liquid = sim.liquidity
        removed = sim.l_vault
        sim.r0 -= removed * sim.r0 / liquid
        sim.r1 -= removed * sim.r1 / liquid
        sim.l_vault = F(0)
    sim.idle0 = sim.idle1 = sim.fee0_vault = sim.fee1_vault = F(0)
    if opposing == 0 or sim.liquidity == 0:
        return target
    sim.a0 += opposing
    sim.a1 -= 0
    before = sim.a1
    swap(sim, opposing, True, fee_pips)
    return target + (sim.a1 - before)


def start(vault_fraction: F, vault_l: F = F(100)) -> Book:
    if vault_fraction <= 0 or vault_fraction > 1:
        raise AssertionError("vault fraction")
    external = vault_l * (1 - vault_fraction) / vault_fraction
    liquid = vault_l + external
    return Book(
        r0=liquid,
        r1=liquid,
        l_vault=vault_l,
        l_ext=external,
        fee0_vault=F(0),
        fee1_vault=F(0),
        fee0_ext=F(0),
        fee1_ext=F(0),
        idle0=F(0),
        idle1=F(0),
        supply=vault_l,
        a0=F(0),
        a1=F(0),
        shares=F(0),
    )


def check(book: Book, t0: F, t1: F) -> None:
    got0, got1 = book.totals()
    if got0 != t0 or got1 != t1:
        raise AssertionError(f"conservation {got0} {got1} != {t0} {t1}")


def executed_round_trip(
    deposit: F,
    swap_fraction: F,
    vault_fraction: F,
    fee_pips: int,
    exit_swap: bool,
) -> dict[str, str]:
    book = start(vault_fraction)
    book.a1 = deposit
    t0, t1 = book.totals()
    spent = deposit * swap_fraction
    entry = swap(book, spent, False, fee_pips)
    p = spent / entry["out"]
    old_target = book.vault_target()
    old_opposing = book.vault_opposing()
    retained1 = book.a1
    retained0 = book.a0
    credit = retained1 + p * retained0
    value = old_target + p * old_opposing
    minted = book.supply * credit / value
    book.shares = minted
    book.supply += minted
    add_vault_liquidity(book, retained0, retained1)
    q = book.shares / book.supply
    remove_vault_fraction(book, q)
    book.supply -= book.shares
    book.shares = F(0)
    if exit_swap and book.a0:
        swap(book, book.a0, True, fee_pips)
    check(book, t0, t1)
    return {
        "rule": "executed-price",
        "exit_swap": str(exit_swap),
        "profit1": str(book.a1 - deposit),
        "end0": str(book.a0),
        "end_shares": str(book.shares),
        "minted": str(minted),
        "p": str(p),
    }


def proportional_round_trip(
    deposit: F,
    swap_fraction: F,
    vault_fraction: F,
    fee_pips: int,
) -> dict[str, str]:
    book = start(vault_fraction)
    book.a1 = deposit
    t0, t1 = book.totals()
    if swap_fraction:
        swap(book, deposit * swap_fraction, False, fee_pips)
    vault0 = book.vault_opposing()
    vault1 = book.vault_target()
    ratio = min(book.a0 / vault0 if vault0 else F(0), book.a1 / vault1 if vault1 else F(0))
    take0 = ratio * vault0
    take1 = ratio * vault1
    book.shares = ratio * book.supply
    book.supply += book.shares
    add_vault_liquidity(book, take0, take1)
    q = book.shares / book.supply
    remove_vault_fraction(book, q)
    book.supply -= book.shares
    book.shares = F(0)
    if book.a0:
        swap(book, book.a0, True, fee_pips)
    check(book, t0, t1)
    return {
        "rule": "proportional-vector",
        "profit1": str(book.a1 - deposit),
        "end0": str(book.a0),
        "ratio": str(ratio),
    }


def quote_mint_then(
    deposit: F,
    vault_fraction: F,
    fee_pips: int,
    jit_multiple: F,
    exit_mode: str,
) -> dict[str, str]:
    book = start(vault_fraction)
    book.a1 = deposit
    t0, t1 = book.totals()
    value0 = quote_target(book, fee_pips)
    minted = book.supply * deposit / value0
    book.a1 -= deposit
    book.idle1 += deposit
    book.shares = minted
    book.supply += minted
    jit0 = F(0)
    jit1 = F(0)
    if jit_multiple:
        jit_l = book.liquidity * jit_multiple
        jit0 = jit_l * book.r0 / book.liquidity
        jit1 = jit_l * book.r1 / book.liquidity
        book.a0 += jit0
        book.a1 += jit1
        t0 += jit0
        t1 += jit1
        book.r0 += jit0
        book.r1 += jit1
        book.l_ext += jit_l
        book.a0 -= jit0
        book.a1 -= jit1
    sleeve_covered = None
    if exit_mode == "quote":
        value1 = quote_target(book, fee_pips)
        payout = book.shares * value1 / book.supply
        sleeve_covered = book.idle1 >= payout
        if book.idle1 < payout and book.l_vault:
            curve0, curve1 = book.vault_curve()
            liquid = book.liquidity
            removed = book.l_vault
            book.r0 -= removed * book.r0 / liquid
            book.r1 -= removed * book.r1 / liquid
            book.l_vault = F(0)
            book.idle0 += curve0
            book.idle1 += curve1
        if book.idle1 < payout and book.idle0:
            book.a0 += book.idle0
            book.idle0 = F(0)
            before = book.a1
            swap(book, book.a0, True, fee_pips)
            gained = book.a1 - before
            book.a1 -= gained
            book.idle1 += gained
        if book.idle1 < payout:
            raise AssertionError("quote payout exceeds fundable target")
        book.idle1 -= payout
        book.a1 += payout
        book.supply -= book.shares
        book.shares = F(0)
    elif exit_mode == "slice":
        q = book.shares / book.supply
        remove_vault_fraction(book, q)
        book.supply -= book.shares
        book.shares = F(0)
        if book.a0:
            swap(book, book.a0, True, fee_pips)
    else:
        raise AssertionError(exit_mode)
    if jit_multiple:
        d0 = jit_l * book.r0 / book.liquidity
        d1 = jit_l * book.r1 / book.liquidity
        book.r0 -= d0
        book.r1 -= d1
        book.l_ext -= jit_l
        book.a0 += d0
        book.a1 += d1
        if book.a0 < jit0:
            need = jit0 - book.a0
            swap(book, need, False, fee_pips)
        if book.a0 > jit0:
            swap(book, book.a0 - jit0, True, fee_pips)
        book.a0 -= jit0
        book.a1 -= jit1
        t0 -= jit0
        t1 -= jit1
    check(book, t0, t1)
    return {
        "rule": "live-quote-mint",
        "exit": exit_mode,
        "jit": str(jit_multiple),
        "profit1_after_jit_repay": str(book.a1 - deposit),
        "end0_after_jit_repay": str(book.a0),
        "value0": str(value0),
        "minted": str(minted),
        "vault_fraction": str(vault_fraction),
        "sleeve_covered": str(sleeve_covered),
    }


def vault_swap_quote_mint(deposit: F, swap_fraction: F, vault_fraction: F, fee_pips: int, exit_mode: str) -> dict[str, str]:
    book = start(vault_fraction)
    book.a1 = deposit
    t0, t1 = book.totals()
    book.a1 -= deposit
    pending1 = deposit
    spent = deposit * swap_fraction
    book.a1 += spent
    pending1 -= spent
    entry = swap(book, spent, False, fee_pips)
    value = quote_target(book, fee_pips)
    minted = book.supply * deposit / value
    book.idle1 += pending1
    book.idle0 += entry["out"]
    book.a0 -= entry["out"]
    book.shares = minted
    book.supply += minted
    if exit_mode == "slice":
        q = book.shares / book.supply
        remove_vault_fraction(book, q)
        book.supply -= book.shares
        book.shares = F(0)
        if book.a0:
            swap(book, book.a0, True, fee_pips)
    elif exit_mode == "quote":
        value1 = quote_target(book, fee_pips)
        payout = book.shares * value1 / book.supply
        if book.idle1 < payout:
            raise AssertionError("quote payout exceeds idle target")
        book.idle1 -= payout
        book.a1 += payout
        book.supply -= book.shares
        book.shares = F(0)
    else:
        raise AssertionError(exit_mode)
    check(book, t0, t1)
    return {
        "rule": "vault-swap-then-quote-mint",
        "exit": exit_mode,
        "profit1": str(book.a1 - deposit),
        "end0": str(book.a0),
        "value0": str(value),
        "minted": str(minted),
    }


def no_vault_round_trip(deposit: F, fee_pips: int) -> str:
    book = start(F(1))
    book.a1 = deposit
    t0, t1 = book.totals()
    spent = deposit / 2
    first = swap(book, spent, False, fee_pips)
    swap(book, first["out"], True, fee_pips)
    check(book, t0, t1)
    return str(book.a1 - deposit)


def main() -> None:
    zero = executed_round_trip(F(200), F(1, 2), F(1), 0, True)
    if F(zero["profit1"]) != F(80, 17):
        raise SystemExit(f"zero-fee identity failed: {zero['profit1']}")
    fee_row = executed_round_trip(F(200), F(1, 2), F(1), 3000, True)
    deposit_only = executed_round_trip(F(200), F(1, 2), F(1), 3000, False)
    proportional = proportional_round_trip(F(200), F(1, 2), F(1), 3000)
    control = no_vault_round_trip(F(200), 3000)

    grid = []
    positive = 0
    proportional_positive = 0
    for fraction in (F(1, 100), F(1, 10), F(1, 2), F(9, 10), F(99, 100), F(1)):
        for fee in (0, 500, 3000, 10000):
            for split in (F(49, 100), F(1, 2), F(51, 100)):
                for deposit in (F(2), F(20), F(200), F(2000)):
                    row = executed_round_trip(deposit, split, fraction, fee, True)
                    gain = F(row["profit1"])
                    if gain > 0:
                        positive += 1
                    if F(row["end0"]) != 0:
                        raise SystemExit("executed exit left opposing")
                    control_row = proportional_round_trip(deposit, split, fraction, fee)
                    if F(control_row["profit1"]) > 0:
                        proportional_positive += 1
                    grid.append(
                        {
                            "vault_fraction": str(fraction),
                            "fee_pips": fee,
                            "split": str(split),
                            "deposit": str(deposit),
                            "executed_profit": row["profit1"],
                            "proportional_profit": control_row["profit1"],
                        }
                    )

    quote_rows = []
    for fraction in (F(1, 2), F(1)):
        for jit in (F(0), F(10), F(100)):
            for mode in ("quote", "slice"):
                try:
                    quote_rows.append(quote_mint_then(F(200), fraction, 3000, jit, mode))
                except AssertionError as exc:
                    quote_rows.append(
                        {
                            "rule": "live-quote-mint",
                            "exit": mode,
                            "jit": str(jit),
                            "vault_fraction": str(fraction),
                            "error": str(exc),
                        }
                    )

    selected = {
        "domain": "infinite-range exact reserves; token1 target; token0 opposing; fee not added to curve",
        "zero_fee_executed_profit": zero["profit1"],
        "fee_3000_executed_profit": fee_row["profit1"],
        "fee_3000_deposit_swap_no_exit_swap": deposit_only,
        "fee_3000_proportional": proportional,
        "fee_3000_no_vault_swap_reverse": control,
        "executed_grid_cases": len(grid),
        "executed_grid_positive": positive,
        "proportional_grid_positive": proportional_positive,
        "quote_rows": quote_rows,
    }
    out = Path(__file__).with_name("results.json")
    out.write_text(json.dumps({"selected": selected, "grid": grid}, indent=2) + "\n")
    selected["vault_swap_then_quote"] = [
        vault_swap_quote_mint(F(200), F(1, 2), fraction, 3000, mode)
        for fraction in (F(1, 2), F(1))
        for mode in ("slice",)
    ]
    selected["decimals"] = {
        "zero_fee_executed_profit": format(F(zero["profit1"]), ".18f"),
        "fee_3000_executed_profit": format(F(fee_row["profit1"]), ".18f"),
        "deposit_swap_without_exit_target_delta": format(F(deposit_only["profit1"]), ".18f"),
        "deposit_swap_without_exit_opposing": format(F(deposit_only["end0"]), ".18f"),
        "proportional_profit": format(F(proportional["profit1"]), ".18f"),
        "no_vault_round_trip": format(F(control), ".18f"),
    }
    print(json.dumps(selected, indent=2))


if __name__ == "__main__":
    main()
