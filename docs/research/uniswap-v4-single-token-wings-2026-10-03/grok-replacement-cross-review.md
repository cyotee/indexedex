# Grok replacement cross-review — mandatory scalar routes and wings

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Peer-informed review of the three other wings originals. Not continuity with the replaced Grok, not consensus, and not a vote that the design is safe. No implementation or gas claim. Basket-only remains unacceptable.

## 1. Corrections to my original

Orientation in my original stands: a token0 wing is strictly above the current tick; a token1 wing is strictly below. What I overstated is exit funding. `getLiquidityForAmount0/1` of a shortfall is a floor helper. Removal proceeds use `SqrtPriceMath` rounded down. One candidate can return proceeds below the shortfall. I do not adopt a `+1` liquidity stencil as a proof that two tries always pay `y`. The search-free rule is: one closed-form removal, then revert if cover is still short. That can reject a payable exit. It is a liveness gap, not a license to increment until it fits.

I also omitted an owner-approved scalar spread. A charge `λ` can compensate holders for internal imbalance. It is a new fixed constant, not a renaming of the 50 bp pool-impact bound. A trigger that falls back to basket-only conflicts with mandatory scalar service unless the owner explicitly accepts scalar outages.

A cap of three positions is enough when placement is deferred and a tainted wing forces new tokens into `F`. It stalls immediate wing placement. If wings are placed on the user path, the better bounded set is one full-range core, one active wing per side, and one crossed wing per side: five, not 256.

`zapSplitWad` retained with disclosure is not end-to-end search freedom. A deterministic Orbital split is an explicit product change, not a proved optimum.

## 2. Astra

**Agree.** Wings place; they do not value. `C1=0` still mints zero under min-ratio. Replacing binary search with Newton or interpolation does not remove sizing. Token0 wing above price and token1 wing below price match `getAmountsForLiquidity`: price at or below the lower bound holds token0; price at or above the upper bound holds token1 (Context7 `/uniswap/v4-core`, `LiquidityAmounts.sol`, accessed 2026-10-03). Three slots, fixed salts, no per-user range list. Consolidation must not assume an in-range wing has the core ratio. Same-pool TWAP is not an independent feed (`UniswapV4MultiPoolTwapOracleTarget.sol:32-44,82-97`). Eight interpolation attempts are not the probe bound. `zapSplitWad` remains unless Orbital itself changes. Idle exact-output two-leg redemption stays invalid.

**Dissent on rank.** Astra's rank 1 admits at an oracle price and, when idle, redeems by removing a pro-rata slice and forward-swapping the other entitlement at the pool. That is the attack Astra names: cheap admission, market-priced exit. The blocked formula `y=floor(r*V*(W-g)/(S*p*W))` is oracle-priced; the idle path is not. Do not pair them without an explicit owner acceptance of that arb. Independent `p_i` also do not freeze NAV, because `D(q)` moves with spot and `V` includes `D`. No production independent feed was established. I keep oracle admission as rank 3, conditional, and only if entry and exit use the same snapshot rule.

Astra's `floor(c/3)` sphere split is a concrete way to delete `zapSplitWad`. It is unproved economically. It is better than calling the loop out of scope. I adopt it as an optional Orbital amendment, not as demonstrated safety.

The loss identity `before(F+D)-after(F+D)>=0` matches Astra's signed formula when `dF` is `F_after-F_before`. Agree, with that sign stated.

## 3. MiniMax

**Agree.** A bounded position set is not automatically a sizing search. Out-of-range `getLiquidityForAmount*` is one arithmetic step. Blocked routes cannot place wings. Outer Orbital loops are not solved by a Hookless change. Pons is not merged. Charm is not this design.

**Orientation is reversed, and the deposit range is in range.** MiniMax says a token0-only range sits below the current tick, and defines `Below` (`tickUpper<=currentTick`) as token0-only. Source says that region holds token1. The deposit then sets `chosenLower=(currentTick/spacing)*spacing` and `chosenUpper=chosenLower+spacing`. The current tick lies in that bucket whenever it is not exactly the next boundary. `getLiquidityForAmount0` on the full width prices a position that is entirely below the price. An in-range `modifyLiquidity` of that liquidity also owes token1. The add is underfunded. This is a formula error, not a labeling quibble.

**The share rule extracts the other leg.** `m=floor(S*amountIn/(B_in+amountIn))` ignores the other backing. Shares then claim `B_other`. Units are raw token-in against a one-leg denominator, not value. The 1 bp test `10000*m*B_i>=9999*S*C_i` fails the other leg when `C_other=0` and `B_other>0`. Applying that test "to the deposited side" does not repair the claim on the other side. Wing liquidity does not supply this denominator.

**Consolidation call is zero in range.** `min(getLiquidityForAmounts(..., budget0, 0), getLiquidityForAmounts(..., 0, budget1))` is zero while price is inside the core, because each call takes `min(leg, liquidityOf(0))`. The plan's call passes both budgets. Reusing `_closedPlacement` does not fix a zero target.

**Cap and salts.** Caller-supplied salts plus `MAX_WINGS=256` and a redemption loop over every wing are a dust and gas path. A quote that walks 256 positions is not a sizing search and can still miss the 31M SY cap. That is not a viable autonomous architecture. "Up to 8 probes" understates `_faceForClaim`'s continuing `while`. The TestBase path MiniMax calls missing was read in the replacement pass; I did not retry `V4FundedBindings.t.sol`.

MiniMax rank 1 is not adoptable as written.

## 4. Kimi

**Agree.** Admission and placement are a pair. The existing CP helpers are the oracle-free scalar arithmetic. Extend them only with an owner decision that this is no longer a forbidden silent substitute for min-ratio. Exact-input stays; two-leg exact-output stays invalid. Blocked funding is sleeve-only. `zapSplitWad` retained means no end-to-end search-freedom claim. The `while` continues past eight interpolations. Fixed-state `K/S` is not cross-state safety. Divergence is the cost. A spread `λ` is the right kind of mitigation if the owner approves a new constant.

**Orientation prose contradicts the citation.** Kimi quotes `q<=sqrtA ⇒ token0` and `q>=sqrtB ⇒ token1`, then says the token0 wing is fully below the current tick. The citation puts token0 above the price. The later trigger `q>=b` for a token0 wing matches the correct above-price wing after it has been fully crossed, not the below-price sentence. Implement the citation, not the "below" sentence.

**`+1` is not proved.** A round-up liquidity-for-amount plus one extra unit is a two-candidate stencil, which is not a search. It is not a proof that proceeds cover `s` for every Q96 edge. If both candidates pay short, revert. Do not loop.

**Divergence throttle.** Falling back to basket-only drops the mandatory scalar route when the arb is largest. That needs an explicit owner acceptance of scalar outages. I do not treat it as part of the default architecture.

Kimi's five-position cap is the right bound if placement is immediate. Per-leg "<1 unit" is true of the share-ceil gap, not of wing settlement versus `SqrtPriceMath`.

## 5. Final architecture

**Rank 1 — internal CP admission, deferred wing placement, matching exit.** Demonstrable share math is `StandardExchangeConstantProduct.sol:58-95` and `:98-110`, on `B_i=Dcore_i+Dwing_i+F_i+E_i`, both manager states. Mint and the exact-share inverse do not search. Exit computes `y` on that curve and pays only the requested token.

Idle funding after `y` is known: `F` first, then one removal from the still-one-sided output wing, sized once. If proceeds are short, revert. No swap, because entry was internal. Unlocked: `F` only. Wings are not cover. `E` is not cover.

Placement is separate and idle-only. Token0 wing: `tickLower=nextSpacingAbove(t)`, `tickUpper=maxUsable`. Token1 wing: `tickLower=minUsable`, `tickUpper=spacingAtOrBelow(t)`, strictly token1 while `sqrtPrice>=sqrt(tickUpper)`. Cap five if a deposit must place immediately; otherwise three plus local `F`. Salts fixed: `core`, `wing0`, `wing1`, and crossed slots only inside the cap. Dust aggregates. Do not scan widths.

Consolidation is a separate call. Remove the tainted wing, add to the full-range core with `getLiquidityForAmounts(q, coreA, coreB, proceeds0, proceeds1)`, book the limiting-leg residual, mint nothing. Debts round up; proceeds round down; `F+D` must not increase. No swap. Keeper failure leaves value in `D`.

Optional owner constant `λ` on scalar `c` and `y`, fixed, disclosed, not a migration of 1/50/25/10. Those keep their current meanings on basket joins and on any real pool swap. Rank 1 has no deposit swap, so 50 bp does not apply to it.

**Rank 2.** Same admission, wing add on the idle user path, five-position cap, local fallback if the active slot is tainted.

**Rank 3.** Oracle or TWAP admission only with an approved independent feed, staleness bound, spread, and the same rule on exit. Idle pool-swap exit is a different product and reopens Astra's attack. Same-pool spot is rejected as the feed.

**Reject.** MiniMax's one-leg share fraction. In-range "wings" funded as token0-only. Zero-leg core liquidity. Caller salts. Basket-only. Async receipts. Liquidity-unit shares across ranges. A quadratic treated as an integer identity. It remains unproved, not impossible, and it cannot run while unlocked.

## 6. Orbital and protections

Search-free SE calls: `exchangeIn(token→shares)`, `quoteTransition(DepositExactIn)`, `RedeemExactIn` via `_singleExit`, `quoteInputForExactShares` on both states, `ReceiveShares`, `sharesForNativeUp`. SY aliases those routes. Minima stay nonzero.

`_faceForClaim` and `_invertBufferForEffective` become one inverse call. Their loops are not eight probes. `zapSplitWad` stays until the owner approves a deterministic split such as Astra's fixed sales, with refund or booked excess under Orbital's own rule. Until then, `planDeposit` is not search-free. Pons unchanged.

## 7. Unresolved, not voted safe

No feed is approved. No `λ` is calibrated. No proof that any finite liquidity stencil always funds `y`. No proof the fixed-state CP inequality survives donation plus a later pool move of `D`. No proof a deterministic sphere split preserves Orbital economics. No measured gas. Owner must accept the internal market, the cover limits, the position cap, and whether `λ` exists, before any implementation.

**Stop. This review does not authorize code.**
