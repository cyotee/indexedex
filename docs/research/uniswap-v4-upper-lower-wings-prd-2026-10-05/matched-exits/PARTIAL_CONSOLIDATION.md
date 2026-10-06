# Matched exit comparison — partial consolidation

Date: 2026-10-05. Research only; owner preferences remain exploratory. No PRD revision, implementation plan, code, tests, shell or configuration operations.

## Status and continuity

Four independent originals completed. Astra and Grok reviewed all three other complete originals together. MiniMax's cross-review returned `[RC_POLICY] tool policy validation failed` for its assigned Markdown write and no substantive findings. Round stopped; Kimi cross-review not requested. No bypass, replacement or session restart. This is partial research, not full-council consensus.

| Member | Retained session | Original | Review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [Original](astra-original.md) | [Review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [Original](grok-original.md) | [Review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [Original](minimax-original.md) | Failed; no review saved reported |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [Original](kimi-original.md) | Not requested after failure |

No original was revised. No peer cross-review was provided to another researcher. Researcher statements remain untrusted evidence requiring adjudication.

## Scope

Hold internal geometric entry fixed. Compare identical physical pre-withdrawal state under:

- A: realize the withdrawing holder's proportional basket, externally swap the opposing asset and pay actual proceeds after disclosed charges.
- B: calculate internal scalar entitlement, then externally fund it subject to a specified budget. The explicit comparison variant uses the same basket, pays at most its executable proceeds, and retains proceeds exceeding the internal entitlement for remaining holders.

R is local custody only. B is whole economic backing F+owned D+own E. The sleeve targets F=pD against vault-owned principal. These definitions are not reopened.

## Benchmark that matters

For ownership fraction q, compare remaining holders against their claim `(1-q)*B` immediately before withdrawal, not their earlier pre-deposit investment. Returning their book to the pre-deposit state can still reduce the claim they hold immediately before withdrawal.

Separate proportional allocation from subsequent market repricing, own fee recovery, settlement costs and rounding. A is an allocation baseline; it is not a guarantee that the remaining active positions never change market value during an exit swap.

## Case 1: initial price-matched book, then one-sided entry

Continuous arithmetic, equal token marks, no explicit operation fee, negligible external impact, zero owned active liquidity during swap.

Initial backing100/100, supply100. Deposit44 token0 without a swap. Invariant grows100→120, mint20. Pre-withdrawal backing144/100, supply120, q=1/6.

- Withdrawer's basket:24 token0 +16⅔ token1.
- Remaining-holder benchmark:120 token0 +83⅓ token1, worth203⅓.
- A pays40⅔ token0 before trading fees, preserving that allocation benchmark.
- Internal scalar entitlement T=144*(2q-q²)=44.
- The basket cannot obtain44 at the external price. Guaranteed payment from additional holder assets reduces their marked claim by3⅓ in this idealized case.
- With0.3% swap fee, A yields40.616⅔, and the gap grows to3.383⅓.

Strict basket-budget B must haircut to proceeds, reject, or require a separately authorized caller top-up. A guarantee requires explicit authorization of another funding source; it cannot be described as the withdrawer alone bearing all costs.

## Case 2: different market and internal inventory prices

Initial backing100/100, supply100, price2 token1/token0. Gross entry126 token1 includes1 fee paid outside the vault; net125 mints50 shares. Pre-withdrawal backing100/225, supply150, q=1/3.

- Basket:100/3 token0 +75 token1.
- Holder benchmark:200/3 token0 +150 token1, worth283⅓ at mark2.
- External post-removal active-segment virtual reserves10000/20000,0.3% input fee, no crossing; own positions remain inactive and earn no new fees.
- Basket proceeds Z=75+19,940,000/300,997≈141.2465 token1. Pool price moves to approximately1.98677.
- A pays140.2465 after1 exit fee. The user gains14.2465 versus126 paid, before gas/financing. Remaining holders retain their matched withdrawal allocation; their decline from original300 occurred at entry pricing.
- Internal T=225*(2/3-1/9)=125. Strict B pays124 after exit fee and retains approximately16.2465 surplus for holders.

If B rebates the surplus, it becomes A in this comparison. If proportional basket exits remain available, users can realize A themselves instead of accepting B's surplus retention. This is an economic bypass, not necessarily an authorization exploit.

## Active position and region qualifications

Astra also supplied an active finite-range example: sqrt bounds0.5/2, price1, owned liquidity100 yields D=50/50 and F=50/50. After the same44 entry and1/6 removal, remaining owned liquidity250/3 sits within post-removal total active liquidity1000. Swapping50/3 token1 at0.3% yields approximately16.3451 token0. Own active fraction1/12 earns1/240 token1 in new LP fees; remaining principal reprices. Fixed-mark holder P&L from the swap is approximately+0.0268, distinct from withdrawal allocation and insufficient to fill the internal-entitlement gap.

This is a finite-range active-segment illustration, not a full deployed three-wing simulation. Labeling the active slot center or wing does not prove the historical allocation reaches every illustrative state. Crossing multiple ranges, fee-growth integer floors and exact activation reachability remain evidence gaps.

Outside the envelope, deployed amounts can become one-sided; F or E may still make total backing two-sided. Current `StandardExchangeConstantProduct.sol:49–51` uses linear same-side issuance when only one side is backed and returns zero for missing-side-only input. Zero mint must not silently turn a deposit into a donation. No root division is reached for those zero-reserve branches.

## Capacity and repeated routes

- Idle with zero local output: principal removal may fund payout.
- Blocked with zero local output: positive payouts cannot use deployed principal/uncollected fees; revert atomically.
- Sufficient local cover makes an internal payout feasible, not necessarily economically equivalent to A.
- Users may choose or induce an outer-manager session; therefore idle/blocked routing is an economic surface, not merely a gas optimization.

Astra's fee-free fixed-price two-cycle illustration: first44 token0 entry followed by A leaves120/83⅓ and loses3⅓ to the entrant. A subsequent36⅔ token1 entry and A exit returns40 token1, gains3⅓, and restores100/100. Aggregate cycle profit is zero under these assumptions, but a trader entering only the second opportunity profits after another user supplies the imbalance. This neither proves drain nor universal safety under prices, fees and modes that change.

## Attributed corrections and rejected claims

- Astra consistently used matched pre-withdrawal benchmarks and separated active-position repricing; Grok checked the main ledgers.
- Grok's continued orientation assertion is rejected: with price inside center, price is BELOW the upper range (token0) and ABOVE the lower range (token1), per previously directly read local `LiquidityAmounts.sol:67–76`.
- MiniMax mixed coarse integer and continuous arithmetic, proposed a dimensionally invalid gap bound and compared remaining value to pre-deposit rather than matched withdrawal ownership. For its coarse helper inputs, `_singleExit` floors to98, not98.28. Its universal one-wei and bounded/non-draining claims are not adopted.
- Kimi's140-deposit example must give internal payout140 in its stated continuous same-token model, not138.39. Its stronger no-extraction and systematically-T-above-proceeds claims are rejected; Case2 reverses that ordering. The zero-reserve arithmetic-revert assertion is also incorrect.
- A haircut is not automatically better for the withdrawer; retained surplus is an explicit transfer. Fees, price impact, gas, rounding and later maintenance must not be collapsed into one charge or assumed compensation.
- Incidental LSP messages are not evidence that compiler errors are pre-existing.

## Conclusion and checkpoint

A has the simpler entitlement: liquidate the user's basket. B introduces another distribution rule governing the difference between an internal quote and realizable proceeds. Neither exit model by itself fixes a mispriced internal entry. A bounded reference/virtual-reserve entry model remains a research alternative, not ratified policy.

Moderator recommendation: use A as the analytical baseline, retain B only as explicitly budgeted variants (haircut, rejection/top-up, or separately authorized holder support), and evaluate all routes together. Do not fund B shortfalls silently from holders. No exact numerical gate or fee has been shown sufficient.

Next human checkpoint: review these distribution and availability tradeoffs; decide which variants merit the next bounded comparison. Full council completion also requires resolution of MiniMax's cross-review failure. No implementation is authorized by this report.

Source mechanism: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:37–64,98–110`; local finite-range mechanics `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:56–76`; wings PRD §§7–10. Researchers read sources in this round; moderator had directly read these shared mechanisms in preceding rounds. All numerical comparisons are analytical, with no new compiled runtime, dependency/version verification, simulation, test pass or gas measurement.
