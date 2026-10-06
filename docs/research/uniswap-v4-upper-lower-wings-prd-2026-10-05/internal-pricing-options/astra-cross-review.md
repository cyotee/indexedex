# Astra — internal-pricing combined cross-review

2026-10-05. Read all three other originals completely together. No cross-review artifacts, shell, tests or PRD edits. Original preserved. Preferences remain exploratory. Hand-checked arithmetic is not an executed security result.

## 1. Findings retained and qualified

My original finite-depth unequal-price example remains consistent under its explicit assumptions: net deposit125 token1 into100/100, mint50, pro-rata basket `(100/3,75)`, fee-adjusted external output `19,940,000/300,997≈66.2465`, net return140.2465 after exit fee1 versus gross entry126. Remaining backing is `(200/3,150)`. Own active LP fraction is zero, deliberately—not an assertion for every wings state. Placement/Q96 rounding and gas were excluded, so profitability after those costs requires execution evidence.

This shows funded holder-value extraction at a stated external mark, not unbacked credit or proven repeatable drain. “Ordinary paid arbitrage” and holder loss can describe the same funded trade; acceptance is a product risk choice, not something established merely because fees were paid.

## 2. Numerical and state corrections

**Grok:** his balanced44-deposit example is coherent: mint20; basket `(24,50/3)`; infinite-depth fee-adjusted total40.6167; finite X=Y=1000 total≈40.3451. But price impact is not a booked fee automatically transferred to LPs: compare pre/post inventories and valuation mark, including later arbitrage. His upper/lower orientation is again reversed: upper initially token0, lower token1 (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:67–75`).

**MiniMax:** the roundtrip is not a consistent ledger as written.

* 5bp=0.0005, not0.005. Charges on100 and90 are0.05 and0.045, not0.5 and0.45. Entry/exit fees may both be legitimate distinct charges; that is not inherently double charging. If an input fee is withheld, contribution and mint must use net input; if charged on top, gross payment must include it. A feeTo liability cannot simultaneously back user shares.
* The44-share result applies to coarse integer root units; with 18-decimal scaled amounts, mint is approximately44.948974… whole shares, not44. Token-unit examples must not silently change decimals.
* A single-sided no-swap deposit cannot turn a full-range1:1 position from D=(200,200) into D=(300,200) at unchanged price. The contribution initially remains local; deployment needs a feasible token mix.
* F=0 cannot finance a blocked payout. A B-based quote of98 is not execution. If sufficient F were separately supplied without changing the stated B, paying98 token0 would leave **B=(202,200)**, not(202,164): the internal conversion retains opposing entitlement in the book. There is no demonstrated34-token incumbent loss. With F=0, it must revert.
* An idle90-token0 payout from the idealized500-value post-deposit book leaves410-value backing, not500. Liquidity removal cannot be skipped while also spending its assets. The coarse proportional payout floors explain the difference between410 and409.836…; it is not “gas rounding” or an assumed pool fee.

**Kimi:** balanced100-deposit example is numerically sound in continuous deep-pool arithmetic: mint48.808848…, basket `(51.191152…,46.537411…)`, total97.728563… before external fee,97.588950… after0.3% on the swapped leg. However “E=0/no accrual” cannot coexist with positive remaining owned active liquidity earning that swap fee. Set own active fraction zero, or explicitly add remaining-holder fees and deployed repricing. It is evidence of a loss in that state, not a global passive-cycle bound.

## 3. Reject misleading bounds and edge reasoning

Neither sleeve×divergence×deposit nor an unspecified “bounded by imbalance” establishes a global loss bound. Concentrated deployed amounts can have an inventory ratio unlike market even with F=E=0. The finite-range example in my retained context—sqrt bounds1,4, current3, L12 giving D=(1,24), market price9—disproves sleeve-only tracking. A single positive remaining balance or full-supply guard does not prove resistance to repeated depletion.

For positive y, token0 invariant entry has `m/S=sqrt(1+c/x)−1`: y cancels continuously. MiniMax's assertion that small y inherently makes the mint approximately zero is false. Rounding near zero and the exactly-zero branch are separate domains. Current `StandardExchangeConstantProduct.sol:49–51` handles zero-sided books before square roots; same-side mint is linear, missing-side-only mint returns zero. Do not accept zero shares as an undocumented donation/waiting receipt. A price **inside** a wing generally makes that wing mixed, not token0-only.

Kimi's `delivered_i*S≥m*B_i` is the backing condition for a proportional join. Imposing it on every one-sided invariant join with positive opposing B forces m=0, silently rejecting the service under evaluation. For scalar pricing, require the selected invariant/value condition, real contribution accounting and all-route economic analysis instead. This does not license arbitrary overissuance.

## 4. Paired exit is a candidate—not a no-arbitrage guarantee

Kimi E2's “no mode-switch arbitrage” is unproved. If external losses reduce user payout while surplus stays with holders, idle and blocked realized payoffs differ. If a fixed internal payout is guaranteed despite execution costs, someone finances the difference. With unrestricted dual/proportional exit, users can bypass scalar pricing and externally convert their basket.

MiniMax's characterization of paired settlement as automatically paying the better price and requiring a depositor-specific deferred claim is not necessary. It can be a current-state fungible-share rule with explicit execution budgets. Grok's proposed settlement still needs funding/surplus rules; it cannot guarantee sourcing the internal amount from the pro-rata basket in all markets.

All candidates must account for F+D+E. No oracle/reference prohibition follows from exploratory AMM-style preferences. Virtual coordinates can price risk without being spendable assets; selecting them requires explicit update and attribution laws.

## 5. Coherent next comparison, before owner ratification

Compare on identical physical states:

1. **Inventory-curve entry + ordinary basket-realization exit.** Measure internal/external price mismatch and resulting holder transfers.
2. **Same entry + paired scalar entitlement with external settlement.** Specify budget, cost deduction, surplus ownership and failure domain; compare every available dual exit too.
3. **Reference-constrained or virtual-reserve AMM entry**, with one expressly selected exit family. No silent NAV substitution and no blanket ban on useful scalar routes.

For each: balanced/skewed backing; every wing region; F=0, sufficient and deficient cover; positive own active liquidity; fees retained versus paid out; entry/exit charge units; zero-side/dust; idle↔blocked and scalar↔dual cycles; changed prices and fee checkpoints. Show caller/holder/external-LP/protocol ledgers and exact remaining backing. Distinguish impact, explicit fees, gas and later maintenance. Charging the same underlying fee twice is an error; a separately disclosed usage fee is not automatically duplication or compensation to holders.

The immediate human questions are: **which two exit models should we compare first; should all basket exits remain available; and where should explicit operation fees and favorable execution surplus go?** Numeric gates/fees should follow the comparison, not be asserted sufficient now. Keep reserve definitions and useful scalar intent settled. No security proof, global loss bound or test pass is claimed.
