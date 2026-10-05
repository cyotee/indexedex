# Grok original: search-free Hookless redesign

**Date:** 2026-10-03. **Author:** Grok (`xai/grok-4.7`), independent first pass. Not consensus. No implementation. No measured gas claim. Historical 19.9M-gas notes are unverified and predate later edits.

## 1. Ranked recommendation

**Yes, with explicit losses.** Adopt rank 1. Stop for an owner decision. Do not implement.

**Rank 1 — proportional core, plus a one-step formula conversion that reverts outside its domain, plus algebraic sleeve placement. No sizing search on deposit, redeem, or quote.**

- Ordinary dual deposit and in-kind redeem are arithmetic. They do not search.
- Idle single-token entry stays on `exchangeIn(token → shares)` and `quoteTransition(DepositExactIn)`. The vault, not the caller, sizes the swap. Orbital passes only an amount.
- Sizing is one quadratic candidate and **one** already-sized `SwapMath` check. If that check misses 1 bp, impact, funding, or the one-step domain, **revert**. Do not walk ±1, bisect, or cross ticks.
- Holder swap-repair is not on the user or quote path. Algebraic placement may run. It does not promise both sleeve targets.
- Public repair, if kept, is placement-only. A searched repair must not be called by quotes.

**Rank 2 — core only.** Single-token on-chain conversion unsupported. Acceptable only if the owner drops autonomous Orbital single-token nested deposits. A router or off-chain plan Orbital cannot pass is not a solution.

**Rank 3 — keep the current 32-refinement search.** Best liveness. Fails the search-free question. Not a redesign.

**Reject** spot NAV, oracle NAV, and idle one-sided invariant-growth mint. They let a later redemption extract the other leg. Reject `minOut = 0`, gas-cap raises, gas-dependent valuation, and treating `sharesJ` / `sharesK` as a reviewed accounting fix.

**Cannot preserve without search or a domain reject:**

1. Universal single-token alignment after a swap that crosses an initialized tick or changes active liquidity.
2. Exact-output two-leg share redemption. Stays `InvalidRoute`. The integer inverse is not proved.
3. Both sleeve targets after every user operation, when inventory ratio ≠ position ratio, without a holder swap.
4. Interleaved holder swap-repair inside ordinary quotes.

## 2. What changes, by design

### Rank 1 (adopt)

**Stays:** full-range position, not a recast range; fungible shares; `B = D + F + E` with fees once; caller credit excluded from incumbent reserves; swap repricing and own-LP accrual stay with incumbents; dual activation and F0 dead-sink shares; pretransfer law; direct PoolManager; hookless `hooks == 0`; Pons not merged; 1/50/25/10 bp constants if a path still trades; retain-and-book identified excess; nested unlock forbidden; blocked pay-from-local-cover only.

**User-visible:** idle single-token deposit/quote **reverts** outside the one-step domain instead of searching. Deposits no longer wait on holder repair. Sleeve may miss one or both targets. Single-token redeem of a **known** share amount still converts the already-sized opposing entitlement (tick traversal of that one swap is allowed). Exact-output share mint/redeem stays invalid until an integer inverse is proved. `rebalanceLiquidReserve` no longer swaps.

**D1–D31:** Amend D1 (same route, domain revert, not a new zap interface), D4 (no repair inside deposit order), D5 (post-swap alignment only inside the certified domain), D6 (idle path must not fall through to CP invariant-growth), D9 and D21 (no holder swap on the ordinary or quote path; 1 bp rho is not a deposit post-condition), D18 (algebraic placement may interleave; swap repair has no combined closed form, so omit it). Keep D2, D3, D7, D8, D10–D17, D19–D20, D22–D31. D17 does **not** yet authorize idle exact-share output: the candidate inverse is unproved. Pons must derive its own fee coefficients in its own planner (D22). A shared polynomial solver is allowed; a shared fee dispatcher is not.

### Sketch 1 alone (rank 2)

Core `C_i = ceil(m * B_i / S)` and in-kind withdraw. Single-token becomes the caller’s problem. Amend D1 and D5 to drop automatic composition. Orbital cannot fill a manager-supplied swap amount, and during an unlock it cannot open another unlock. **Not acceptable for current Orbital** unless rank 1’s internal formula is also adopted.

### Sketch 2 (reject)

Unbalanced mint at spot or oracle NAV. Spot mint plus choice of redeem token is an inventory drain. An oracle is a new trust domain the PRD did not approve. Idle use of `StandardExchangeConstantProduct._sharesForDeposit`’s one-sided branch (`StandardExchangeConstantProduct.sol:58-64`) is the same extraction if the other token can later be redeemed at the internal curve or the pool.

### Sketch 3 (the conversion half of rank 1)

Direct sizing only while one arithmetic formula is correct. Out of domain: **reject**, not partial accept. `getLiquidityForAmounts` sizes placement at a frozen price. It does not size the pre-placement swap. “Full range” does not cancel other positions’ ticks, fees, or rounding.

### External leads, not authority

Charm Alpha Pro documents proportional `deposit(amount0Desired, amount1Desired)` and a separate `rebalance`. Full range is a `fullRangeWeight`, not the product. Docs accessed 2026-10-03: https://learn.charm.fi/charm/technical-references/core/alphaprovault. Arrakis V2 is a V3 multi-range vault; `rebalance` takes a manager swap payload. README accessed 2026-10-03: https://github.com/ArrakisFinance/v2-core. Neither is an autonomous full-range V4 formula. Gamma and Range were not primary-verified this pass. Do not copy a manager-supplied amount into an interface Orbital cannot populate.

## 3. Equations and conservation

**Fact.** Idle composition today bisects swap input, up to 32 refinements, each a forward quote of at most 64 core steps (`TransitionPlanner.sol:23-24,73-108`; `QuoteService.sol:28,67-111`). Maintenance bisects again (`TransitionPlanner.sol:168-214`). `quoteTransition(DepositExactIn)` calls that composition when idle (`InQueryTarget.sol:163-168`). Redeem then calls maintenance (`InQueryTarget.sol:149-150,183-188`). `UniswapV4ZapQuoter` also searches (`UniswapV4ZapQuoter.sol:43-47`). No gas comparison is claimed.

**Book, unchanged.** `B_i = D_i + F_i + E_i`. Credit, payout, and refund are excluded from incumbent `F` (`InventoryMath.sol:44-47,58-60`). Collection is `E → F` once (`InventoryMath.sol:62-67`). Own LP fee is fee-growth on owned `l`, not protocol or other LPs’ fees.

**Proportional mint, positive two-leg.** `m = min(floor(S*C0/B0), floor(S*C1/B1))`. Accept iff `10000*m*B_i >= 9999*S*C_i` for each positive leg (`ProtectionMath.sol:105-110`). Empty supply uses F0 only: both credits positive, `raw = floor(sqrt(C0*C1))`, caller shares `raw - minimum`, sink shares unchanged. One-sided incumbent book uses the existing linear rule only when that leg is truly empty and no opposite asset is donated. Do not use it to paper over a failed zap.

**Exact-share basket, dual core.** `C_i = ceil(m*B_i/S)` for `S>0`, `B_i>0`. Require `C_i` funded and `forward(C) >= m`. Surplus wei is donation to the book, not a search. Identified excess above `C` is retained and booked, not refunded on exact-in, and is not caller-alignment contribution.

**Idle single-token, continuous inference, not an integer identity.** Inside one step, active `L` and fee are constant. For token0-in, net `n = x(1-φ)`, next sqrt `t = L*s/(L+n*s)` in unit-sqrt symbols, output `L*(s-t)`, `D0 ∝ (1/t-1/b)`, `D1 ∝ (t-a)`. Own input-token fee is linear in `x` if `l/L` is constant. Clearing the denominator in `(c-x)*B1(t) = out(t)*B0(t)` gives a quadratic `A x^2 + B x + C = 0`. Token1-in is also quadratic: sqrt price moves linearly with input, token0 output is hyperbolic. Coefficients depend on `F`, `E`, `l`, `L`, `s`, range bounds, and fee. **Inference, not a verified integer root.** Implementation must use `SwapMath.computeSwapStep` / `SqrtPriceMath` deltas for the one check (v4-core `SwapMath.sol:51`, `SqrtPriceMath` amount deltas; Context7 `/uniswap/v4-core`, accessed 2026-10-03). Upstream `main` is not a deployed pin.

**Domain (all required):** idle; `S>0`; both incumbent legs positive; price strictly inside the position; active `L>0`; fee `< 1e6`; next price strictly inside the first tick target, including bitmap-word boundaries; `0 < x < c`; 50 bp price impact on price, not sqrt price (`ProtectionMath.sol:98-103`); 10 bp shortfall versus the fee-inclusive quote; 1 bp alignment after placement rounding. Else `AlignmentNotAchievable` or `InvalidRoute` **before funding**. No second candidate.

**Conservation.** Incumbent snapshot excludes credit. The swap’s price move changes `D`; own LP fee increases `E` then `F`. Those deltas stay in `B'`, not `C`. `C = (c-x, out)`. Mint `m` against `B'`. Placement moves `F ↔ D` inside `B'+C`. Addition rounding loss is deducted from `C`, not hidden in incumbent principal (current planner `TransitionPlanner.sol:136-139`). No asset is created. The depositor’s swap fee is not assigned to `C`.

**Blocked / already unlocked.** No swap and no `modifyLiquidity`. Keep F1/F2/F3. F1 inverse is closed form (`StandardExchangeConstantProduct.sol:78-96`). Two-leg exact-output exit shares are bisection (`:113-128`) and stay invalid. Pay only if local `F` of the requested token covers. `E` is not cover.

**Redeem exact-in shares.** Remove `floor(l*shares/S)`, pay pro-rata local entitlement, swap the **known** opposing amount with the forward quoter. That traversal is execution of a sized swap, not discovery. Do not call `_maintenance`.

## 4. Sleeve

Adopt **placement reserves inventory**. `target_i = floor(T_i*p/(1e18+p))` with `T_i = D_i+F_i` after the user leg (`InventoryMath.sol:50-52,216-229`). Liquidity is the min of the two budget legs at the current price, stencil `{target, target-1, current}` only. No swap to equalize. Either free balance may be zero. Deadband stays the definition of a later “in band” report; a miss does not fail the user op and does not start a search.

Blocked operations pay only actual local cover of the requested currency. The sleeve does not promise withdrawals. Nested unlock stays forbidden.

Separate swap-maintenance is not required to have a sleeve. Rank 1 does not do it on ordinary calls.

## 5. Orbital and SY

**Fact.** Orbital `planDeposit` loads three legs and calls nested `quoteTransition` for `DepositExactIn` and `RedeemExactIn` (`ExitQuoteLib.sol:241-246,85-126,332-344`). `_claimIn` is another `DepositExactIn` (`:376-382`). `_faceForClaim` is Orbital’s own bisection, up to 8 probes (`:347-373`). `ReceiveShares` does not touch the pool (`IStandardExchangeTransitionQuote.sol:28-31`). The Univ4 SE fixture binds two vaults on one PoolManager (`TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:19-55`). This pass did not prove those vaults are the hookless planner under test.

**Replacement Orbital can call with no search:** `quoteTransition(DepositExactIn, amount)` and `exchangeIn(token, amount, shares, minShares, …)` where the vault sizes `x`. `quoteTransition(RedeemExactIn, shares)` for an already chosen share amount. `ReceiveShares` unchanged. While the manager is unlocked, `quoteStateWithUnavailableUnlock` and the blocked formulas only.

**Orbital must change.** Delete `_faceForClaim`’s loop. If the integer inverse is later proved, one `quoteInputForExactShares` call replaces it. Until then, deposit the already-sized offered face and value minted shares at `shares × rate` (D60). Do not search for the face that hits `needed`. That is an Orbital economic change: leftover face is not trimmed inside the SE quote. `sharesJ` / `sharesK` may become the exact redeem share count of a sized output, not speculative state.

SY `deposit` / `redeem` must stay aliases of the same share routes. No parallel formula. Pons quotes must not call Hookless planning.

## 6. Risks

- **Domain griefing.** Initializing a tick or moving price to the step boundary forces a revert. That is accepted. A CP-mint fallback would turn griefing into extraction.
- **Donation.** Booked surplus changes `B` before the quadratic. Unbooked surplus can still be claimed under existing pretransfer law. Do not credit the depositor with incumbent fee or repricing.
- **Fee ownership.** Protocol fee and other LPs’ fees are not `E`. Counting both swap output and fee growth double-counts.
- **Rounding.** The real root can fail the integer 1 bp test. Reject. A nearby passing input is not evidence the formula is complete.
- **Same-pool repricing.** The depositor’s swap moves every in-range LP, including the vault. Assign that `D` change to incumbents.
- **Sandwich.** Keep 50 bp and caller `minShares`. Never `minOut = 0`.
- **Pons.** Extra `h(n)` changes coefficients. Sharing Hookless coefficients would mis-price and violate D22.
- **False liveness.** Rank 1 will reject deposits the current search would fill. That is the trade. Do not “fix” it by reintroducing a loop.

## 7. Later acceptance plan (do not run)

1. Independent integer proof or counterexample of the quadratic against `SwapMath` rounding, fee-growth floors, and position deltas. Include token0-in and token1-in, `l = L` and `l < L`, fee 0 and fee near `1e6`.
2. Property tests: candidate-plus-one-check never searches; out-of-domain reverts before pull; accepted mints meet 1 bp; rejected mints are not retried.
3. Conservation: `B'+C` reconciles to balances, position, and fee checkpoints. Addition rounding hits `C` only.
4. Quote/execution equality on the certified domain. Unsupported domains return the same error. No gas assertion in this research.
5. Orbital: `planDeposit` and `_claimIn` perform no bisection; unlocked context uses blocked formulas; sphere valuation uses `shares × rate`, not SE NAV.
6. Adversarial: donation before snapshot, tick-boundary griefing, redeem-other-leg after a rejected zap, blocked cover shortfall, Pons fee not booked as own LP fee.
7. Human gate before any code: accept domain reverts, algebraic sleeve misses, and forward-only Orbital deposits.

## 8. Evidence, confidence, gaps

| Claim | Kind | Confidence |
|---|---|---|
| Current idle deposit/quote searches | Fact, lines above | High |
| Blocked F1/F2 and dual min-mint do not search | Fact | High |
| Tick crossing has no single quadratic | Fact about piecewise `L` | High |
| Continuous one-step alignment is quadratic | Inference | Medium |
| Integer candidate usually passes 1 bp | Unmeasured | Low; do not assume |
| Charm/Arrakis are proportional-deposit, separate-rebalance leads | Docs read this pass | Medium; not full-range V4 vaults |

Local authority: PRD D1–D31 and sleeve/share sections (`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:28-58,118-206`); plan solver bounds (`docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:249-256`). PRD records Solidity 0.8.35, optimizer runs 1, via-IR off. This pass did not re-read `foundry.toml`.

**Gaps:** Gamma and Range contracts not read. `UniswapV4DetfProductionSeDeployLib` not read, so the failing fixture’s vault type is not confirmed. Quadratic coefficients not independently executed. No fresh trace. One tool call returned `RC_ATTRIBUTION` and was retried successfully; no bypass.

**Checkpoint.** Owner adopts rank 1, or explicitly keeps the search. This memo does not.
