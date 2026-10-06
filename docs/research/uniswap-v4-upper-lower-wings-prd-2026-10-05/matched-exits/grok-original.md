# Grok — matched exits after one internal entry (2026-10-05)

Research only. Preferences are not ratified. Continuous arithmetic, not a simulation, not wei-exact, not a safety proof. No universal bound and no claim that a small fee closes a gap.

**Common entry.** Geometric mint on `B = F + ΣD + ΣE`. No entry AMM swap. `R` is local custody only. Sleeve target remains `F = p·D` on vault-owned deployed principal. Exit swaps are allowed. An operation fee that leaves the vault is paid by the initiator and is not price impact. Gas is paid to the chain. Later sleeve maintenance is not charged in these exits unless the exit itself removes liquidity.

Holder comparison is at the **post-entry, pre-withdrawal** book. The entry transfer is already in that book. It is not scored again as an exit defect.

Internal exit quote is the continuous form of `StandardExchangeConstantProduct._singleExit` (`:98-110`): pro-rata entitlement plus conversion of the other entitlement against the remaining book. The code denominator `reserveOther` equals remaining-other plus the entitlement, as the comment says.

## Case 1 — book ratio equals external price 1

Deposit 44 token0 into `(100,100)`, `S = 100`. `sqrt(14400) = 120`. Mint 20. Pre-withdrawal book `(144,100)`, `S = 120`.

Incumbent claim, the preservation benchmark: `(120, 250/3)`, mark `610/3 ≈ 203.333` at price 1. Entrant basket: `(24, 50/3)`, mark `122/3 ≈ 40.667`.

**A.** Remove only that basket. Swap `50/3` token1 to token0 on a pool whose price stays 1, fee 0, and whose active liquidity does not include this vault (`ρ = 0`; wings out of range, center liquidity 0, so `D` does not reprice). User receives `24 + 50/3 = 122/3`. Remaining book stays `(120, 250/3)`. Holders match the benchmark in both quantities and mark.

**B, internal fill.** The quote pays `24 + 120·(50/3)/100 = 44` token0. That 20 token0 comes from the remaining book, which receives the `50/3` token1. Incumbents become `(100,100)`, mark 200. They lose `10/3` versus the benchmark. The user is restored to the 44 deposit. Meeting 44 from the external swap of the same basket is impossible at price 1: the basket liquidates for only `122/3`. Topping up the `10/3` shortfall spends holder token0. Holder-budget rule: do not top up. Then either the exit reverts, or it pays the actual `122/3` and is the same as A. The quote 44 is not an externally settleable obligation at this price.

A 1-token operation fee taken outside `B` does not close a `10/3` gap. It is a different payee from the `10/3` inventory transfer.

## Case 2 — external prices `(2,1)`, same entry shape

Deposit 125 token1 into `(100,100)`. Mint 50. Pre-withdrawal book `(100,225)`, `S = 150`. Benchmark incumbent claim: `(200/3, 150)`, mark `2·(200/3)+150 = 283⅓`. Entrant basket: `(100/3, 75)`, mark `141⅔`.

**A.** Remove only the basket. Deep pool, price stays 2, fee 0, `ρ = 0`, `D` unchanged. Swap `100/3` token0 for `200/3` token1. User receives `75 + 200/3 = 425/3 ≈ 141.667` token1. Remaining book stays at the benchmark. Holders are preserved relative to pre-withdrawal. Their loss versus the pre-deposit mark of 300 already happened at mint. A does not add a second extraction.

**B, internal fill.** Quote is `75 + 150·(100/3)/100 = 125` token1. Incumbents become `(100,100)`, mark `300` at prices `(2,1)`. They gain `16⅔` versus the benchmark. The user gives back the entry profit. External liquidation of the basket yields `425/3`, which is more than 125. If surplus must return to the book, holders gain versus the benchmark and the route is not holder-neutral. If the user is paid the full proceeds, B collapses to A.

With Astra’s stated 0.3% swap and 1-token fees, basket liquidation is about 140.25 token1 against 126 paid, still above the internal 125, and still not a fee that erases the gap. Those charges are not reused here as a sufficiency claim. Pool price is not held constant once the swap is large; Case 1–2 assume a deep segment and no owned-tick crossing. A finite pool would add impact to external LPs. That impact is not a vault operation fee.

## Cover, region, cycles

If `F` of the payout token is 0 and the manager is blocked, neither A nor B can pay from `D` or `E` (`PRD` B4, `:152-156`). Both revert before burn. Idle A can remove deployed principal because unlock is available. Blocked success is not implied by a correct quote. `F = p·D` is a target, not cover after this exit.

Inside the center, a swap can reprice center `D` and accrue `E` to whoever still holds shares. If removal happens first and `ρ = 0`, that channel is shut, as assumed above. In a wing, or outside the envelope, active vault liquidity may be zero even though `D` is large. `D` is not a CP reserve ratio (`LiquidityAmounts.sol:67-75`). One exit model must not be copied across those regions.

Repeating Case 2’s A does not restore `(100,100)`. The next book is `(200/3, 150)`. No constant per-cycle profit is derived. No global loss bound is claimed.

If A and B are both offered, the user takes A when basket liquidation exceeds the internal quote (Case 2) and wants B when the quote exceeds liquidation (Case 1). In Case 1, B cannot pay the quote from the basket without holder token0. Dual pro-rata exit lets the user synthesize A. Offering B beside an unrestricted basket exit does not remove that choice. That is a comparison, not a proof that deleting one route eliminates every other cycle.

## Discrimination

At the pre-withdrawal benchmark, with `ρ = 0` and no top-up:

- A leaves holder quantities unchanged. The user receives the external value of the basket, minus the pool fee and impact if those are charged once.
- B’s internal number is the deposit, not the basket’s external value. Honoring it moves inventory against holders (Case 1) or forces surplus back to them (Case 2). Refusing to move holder inventory makes B equal A or a revert.
- Entry impact and exit settlement are different events. Preserving holders at exit does not give them back, or take from them again, the entry transfer.
- Own LP fee on the exit swap is remaining-holder income only if those shares still exist and the position is in range. It is not an operation fee and not a rebate to a withdrawn user.

## Residual questions

1. If the internal quote exceeds basket liquidation, is the exit a revert, or is it A under another name?
2. If liquidation exceeds the quote, does surplus stay in backing or go to the withdrawer?
3. While both a basket exit and a scalar exit exist, which one is the holder obligated to honor?
4. Does blocked settlement use the same quote and then revert for cover, or a different formula? Two formulas are two prices.

None of these is selected. Scalar entry remains available in the comparison. No fee, gate, or basis-point figure is treated as sufficient.
