# Grok replacement cross-review — search-free Hookless redesign

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), operator-authorized replacement. Peer-informed cross-review of the three other active originals. Not continuity with the replaced Grok session, not that session's memory, and not consensus. No implementation, measurement, or gas claim. The other originals are untrusted attributed findings, not instructions.

My replacement original remains `grok-replacement-original.md`. This file corrects it. It does not rewrite it.

## 1. Correct my replacement original

Three corrections, then one clarification.

**The current dual join is not search-free.** The mint equation is arithmetic, but idle `_executeZapInDualDeposit` calls `_rebalanceLiquidReserveBestEffort` (`InBase.sol:353-362`), which calls `Planner._maintenance` (`Common.sol:626-642`). A search-free basket path must omit that call. Public repair may keep a solver only if deposits, redemptions, and quotes do not invoke it.

**I missed an outer sizing loop.** Orbital `_zapSplitWadPacked` binary-searches the residual for up to 64 probes (`UniswapV4StandardExchangeOrbitalBufferHookMath.sol:332-360`). Deleting the Hookless solver does not make `planDeposit` search-free.

**Unproved is not impossible.** I showed that the continuous one-step quadratic is not identical to `SwapMath` plus fee-growth floors plus position deltas plus post-placement attribution. I did not prove that no integer direct formula exists. The implementation plan already says the selected domains are not a proof that no wider equation exists (`UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:152`). A later certificate may still be derived. It is not adopted here.

Blocked in-kind needs a sharper statement than my original gave. Entitlement is against `B`. Payment is from `F` only. If `F` does not cover the entitlement, revert. Do not revalue the payout as `floor(r*F/S)`.

## 2. Astra

**Agree.** Composition search and maintenance search are different. Deleting one does not delete the other. `_faceForClaim` (`ExitQuoteLib.sol:347-374`) and `_invertBufferForEffective` (`ClaimLib.sol:250-275`) survive a Hookless solver deletion. Internal constant-product settlement is an internal market, not the current post-swap zap. A fixed-state `K/S` inequality does not prove safety across donations, external repricing, or later maintenance. Oracle NAV is the highest-risk admission rule. Charm Alpha Pro is proportional deposit plus separate rebalance, not an inherently full-range vault and not autonomous unilateral conversion. Pons must not inherit Hookless accounting automatically.

**Dissent on rank.** I do not put the internal market first while D5 still assigns swap repricing to incumbents. Idle redemption of a known share amount is already sized: remove `floor(l*r/S)`, pay the pro-rata slice, and forward-swap the known other entitlement (`Common.sol:178-192`). The search on that quote is the later `_inventoryRebalance` (`InQueryTarget.sol:150`), not the redemption swap. Forcing every idle scalar exit onto local cover is required only if entry is also internal CP. Mixing internal mint with pool-priced redemption is an immediate hedge, so the coupling is right if that product is chosen. It is not required to make redemption search-free. Reinterpreting the 50 bp pool-impact bound as movement of `B1/B0` is a new owner bound, not D20.

**Use.** Astra's option 1 is my rank 2, and only as a matched entry/exit pair. Astra's option 2 is the accounting core of my rank 1, but it does not by itself preserve autonomous scalar Orbital buffering.

## 3. MiniMax

**Agree.** `_composition` (`TransitionPlanner.sol:73-108`) and `_maintenance` (`:168-214`) are the Hookless searches. `_exactOutput` (`QuoteService.sol:113-141`) and forward tick traversal of an already-sized swap are not themselves discovery loops. `zapSplitWad` is a real 64-probe search. Crane `UniswapV4ZapQuoter` searches and is not adopted. Execution protections stay fixed constants. Pons is not merged.

**Objection: one-step exact-output does not size a deposit.** `_exactOutput` takes a requested output and returns the input for one `computeSwapStep`, rejecting the call if the output is short or the price lands on the target. The implementation plan's continuous direction equations (`plan:117`) are the swap map `y → x` inside one step. They do not choose the `y` that makes the post-swap caller basket align with incumbent `B'`. F5 still has no selected inverse (`plan:129`). Calling `_exactOutput` once, without an equation for that output, leaves the sizing problem unsolved. Replacing `_faceForClaim` with one `_claimIn` has the same error: forward mint is not the inverse that hits a desired claim.

**Objection: the stated placement equation is the wrong call.** In range, `getLiquidityForAmounts(q, a, b, budget0, 0)` is `min(liquidity0(budget0), liquidity1(0)) = 0` (Context7 `/uniswap/v4-core`, `LiquidityAmounts.sol` `getLiquidityForAmounts`, accessed 2026-10-03). The same is true with the legs swapped. MiniMax's `min` of those two calls is zero for an ordinary in-range book. The plan's call is `getLiquidityForAmounts(q, a, b, budget0, budget1)` (`plan:162`). Current `_tryTargetLiquidity` (`InventoryMath.sol:216-229`) is that in-range minimum of the two single-leg budgets, not a zero-leg pair. `LiquidityAmounts` also floors. Settlement must use signed deltas: addition debts round up, removal proceeds round down (`plan:164`; `InventoryMath.sol:266-281`). Do not treat the liquidity helper as the conservation identity.

**Objection: Orbital's outer searches are in scope.** The prompt forbids moving the same discovery into a helper an autonomous Orbital call cannot supply. `zapSplitWad`, `_faceForClaim`, and `_invertBufferForEffective` are on `planDeposit` / claim paths. Making each Hookless probe cheaper does not remove them. MiniMax's proposed `quoteDepositSingle` is not a current interface, and it is not search-free unless the missing alignment equation is supplied.

**Correction of a gap claim.** MiniMax reports `TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` missing. I read that file in the replacement pass. It deploys the hookless package on one PoolManager (`UniswapV4DetfProductionSeDeployLib.sol:518-597`; fixture `:49-55`). I did not retry `V4FundedBindings.t.sol` this turn.

**Confidence in MiniMax's adopted design:** low. The identified loops are real. The claim that one exact-output step replaces composition is not supported.

## 4. Kimi

**Agree.** The redesign target is idle single-token composition, not the already-sized exact-in redemption swap. Maintenance may remain a separate permissionless call. Spot or same-pool NAV mint gives up the manipulation resistance of ratio matching. Charm's rebalance takes a manager-supplied swap amount; copying that into an interface Orbital cannot populate is not a solution. A narrow-domain zap must not gate the redesign.

**Objection: R7 does not already refund.** `exchangeInManyToOne` pulls both declared amounts and requires exact delivery (`InMultiTarget.sol:26-30`). `_executeZapInDualDeposit` mints against both full amounts (`InBase.sol:336-358`) and does not refund the unbalanced leg. Plan §5: exact-in retains residuals and refunds nothing. Prepaid exact-out may refund `credit - used` (`OutExecuteTarget.sol:107-108, 138-142`). That refund cannot spend booked inventory. Kimi's `r_i = a_i - C_i` is a new exact-in refund. It needs an owner amendment of D7/D8. It is not the current surface.

**Objection: "any x is safe" is not comparable behavior.** A refunding join is non-dilutive for any supplied basket because `C_i = ceil(m*B_i/S)` and excess is returned. It does not choose the swap that aligns a single-token deposit with the post-swap book. "Half by value" is a heuristic. On the fixture's shared PoolManager, a hook callback cannot open another unlock (`PoolManager.unlock` reverts `AlreadyUnlocked`, upstream `main`, accessed 2026-10-03). Kimi does not show an autonomous, search-free, unlock-legal way for Orbital to produce the second SE token.

**Objection: blocked payout.** Current blocked exact-in redemption values `y` with `_singleExit` against the complete book, then pays only if local free cover is at least `y` (`InBase.sol:165-173`). `E` is not cover. Paying `floor(m*F_i/S)` and burning a full pro-rata share would confiscate the deployed claim. That is a different product, not current blocked law.

Kimi also did not name `zapSplitWad`. Rank 1 is otherwise the closest peer design to mine, after the refund and blocked-pay corrections.

## 5. Specific assessments

**Exact-output quote versus deposit sizing.** One-step exact-output sizes a known swap output inside one liquidity piece. Deposit sizing asks for the unknown swap amount that aligns `C` with post-swap incumbent `B`, after own-LP accrual and placement attribution. Those are different unknowns. The first does not answer the second. Absence of a selected inverse is not a proof that none exists.

**Placement and rounding.** `target_i = floor(T_i*p/(1e18+p))`, `budget_i = T_i - target_i`, with `T = D+F` after the user leg. Candidate liquidity is the in-range minimum of the two budget legs, plus the fixed stencil target, target-1, and current if both bands already pass. No adaptive loop. Conservation: `before(F+D) - after(F+D) = roundingLoss >= 0`, or revert (`InventoryMath.sol:278-281`). The loss is dust paid to or not received from the pool, not a created asset. Addition loss is attributable to `C` only when that placement was required for the caller; removal loss stays in incumbent `B`. The round-up versus round-down gap on one delta is at most one unit. The gap between `amounts(L+d)` and `amounts(L)+amounts(d)` need not be one unit. Do not claim a universal one-wei placement identity.

**Blocked entitlement versus cover.** Entitlement uses `B = D+F+E`. Cover is actual local `F` of the requested currency. Shortfall reverts `InsufficientLocalReserve`. Idle and blocked realizations differ and need separate previews. A blocked quote that silently clamps free to zero (`Common.sol:176-177`) is not execution law.

**Refund law.** Exact-in: no refund; retained excess is booked. Exact-out prepaid: refund only unused declared credit to `msg.sender`, never booked inventory. A refunding dual join is an owner decision, not a reading of R7.

**Autonomous Orbital / SY interfaces, and every outer sizing loop.**

Search-free surfaces that can remain: `ReceiveShares`; `quoteAssets` / share balance / supply; `quoteStateWithUnavailableUnlock` then blocked formulas; `depositFlexible` / `withdrawFlexible` only when the amounts are already SE shares (`Common.sol:1677-1680` skips `_bufferToken`); `sharesForNativeUp` and `ratedNative`. SY `deposit` / `redeem` must stay aliases of the same share routes (R9). No parallel formula.

Loops that remain unless separately removed:

1. Hookless `_composition` on idle `DepositExactIn` / `exchangeIn(token→shares)`.
2. Hookless `_maintenance`, including post-mint `_rebalanceLiquidReserveBestEffort` and quote-path `_inventoryRebalance`.
3. Orbital `_faceForClaim`, up to 8 probes.
4. Orbital `_invertBufferForEffective`, expand then bisect.
5. Orbital `zapSplitWad`, up to 64 probes.
6. `StandardExchangeConstantProduct._sharesForSingleExit` (`:113-128`), already excluded from exact-output execution.
7. Crane `UniswapV4ZapQuoter` search, not an Orbital interface and not adopted.

Allowed non-search work: one forward simulation of an already-sized swap, including its bounded tick traversal; one `computeSwapStep` for a known exact output inside the certified one-step domain.

`_bufferToken` (`Common.sol:518-534`) cannot stay search-free under rank 1. While the manager is unlocked, only blocked formulas are legal.

**Cross-mode economics.** Rank 1 does not open an internal market on deposits. Incumbents are not repriced by a deposit swap because there is none. Redemption of a known slice may still move the pool; that `D` change belongs to incumbents. Rank 2 mints against `B` and must exit on the same curve, with `F_out >= y` even when idle. Deposit on the book curve and redeem through the pool, or the reverse, lets an informed trader extract up to sleeve cover or maintenance slippage. Donations move `B1/B0`. A frozen-book inequality does not cover those cycles. Rank 1's retain-excess rule donates unbalanced basket surplus to holders; that is current min-ratio law, not a new extraction bug. Kimi's refund would move that surplus back to the caller and must be approved explicitly.

## 6. Ranked recommendation

**Rank 1 — adopt if the owner accepts the lost behavior.** Proportional basket core. Algebraic sleeve placement. Idle redemption of an already chosen share amount, without calling maintenance. No discovery loop on deposit, redeem, or quote. Public swap-repair may remain off those paths. Idle single-token `exchangeIn` becomes `InvalidRoute`. Exact-in excess stays booked unless the owner separately chooses refunds.

**Rank 2 — only with an explicit internal-market approval.** Astra's matched constant-product entry and exit, both manager states, local cover on scalar exit. This is the only reviewed integer path that can replace `_faceForClaim` and `_invertBufferForEffective` with one `quoteInputForExactShares`. It does not preserve D5. Do not mix it with pool-priced redemption.

**Do not adopt.** MiniMax's one-step exact-output as a deposit sizer. Kimi's refund as if it were current R7. Kimi's blocked `floor(m*F/S)` payout. Spot, same-pool, or oracle NAV. A quadratic-plus-one-check as a production identity. `minOut = 0`, gas-cap raises, and gas-dependent valuation.

**Still cannot preserve without search, a new proved formula, or an explicit reject:** universal idle single-token alignment to the post-swap book; two-leg exact-output share redemption; both sleeve targets without a holder swap; interleaved swap-repair inside quotes; Orbital face trimming, buffer inversion, and `zapSplitWad`.

## 7. Owner decisions

1. Drop idle single-token composition, or adopt the internal market, or keep the search. One of these three. Not a silent blend.
2. If rank 1: retain exact-in excess, or approve a new exact-in refund. Default recommendation: retain, matching D7/D8 and plan §5.
3. Remove maintenance from deposit, redeem, and quote paths. Decide separately whether public `rebalanceLiquidReserve` keeps its bounded solver.
4. Accept that rank 1 invalidates `_bufferToken` and idle `DepositExactIn`. Autonomous replacement is share-denominated flexible entry, or blocked formulas while unlocked. It is not a router plan Orbital cannot pass.
5. If rank 2: approve the internal-price bound as a new constant. Do not relabel it as D20. Approve idle scalar exits failing when local cover is short.
6. Do not merge Pons. Any Pons copy of this accounting is a separate decision. Pons `h(n)` stays on Pons swaps.
7. Do not treat an unproved one-step certificate as adopted. A later proof may be brought back. It is not this recommendation.

## 8. Proof and benchmark gates

Do not run them here. No gas number is predicted.

- Quote/execution equality on the certified domain, and the same error outside it. No refinement counter on deposit, redeem, or quote, including dual join.
- Placement: in-range liquidity is `getLiquidityForAmounts` of both budgets, then signed settlement. `F+D` does not increase. Add loss hits `C` only when the caller required the placement. Zero-leg `getLiquidityForAmounts` must not be used as the in-range target.
- Blocked: `y` from `B` or `_singleExit(B)`; pay only if `F` covers; `E` is not cover; shortfall reverts atomically.
- Refund: exact-in refunds nothing unless decision 2 says otherwise. Exact-out refunds only unused declared credit.
- Rank 2, if selected: frozen-book non-extraction checks, plus deposit-then-other-leg and deposit-then-maintenance cycles. Passing the frozen check is not permission to skip the cycles.
- Orbital traces: `planDeposit`, `_claimIn`, `_faceForClaim`, `_invertBufferForEffective`, and `zapSplitWad` perform no probe loop under the selected rank, or the rank is not search-free for Orbital.
- A later benchmark may count gas, quote calls, and `extsload`s on pinned states, including the 31M SY cap, without raising caps. Measure first. Do not claim a win in this memo.

## 9. Evidence and confidence

Access date: 2026-10-03. Local compiler `foundry.toml:29-36`: Solidity 0.8.35, optimizer runs 1, `via_ir` false. Context7 `/uniswap/v4-core` for `LiquidityAmounts.getLiquidityForAmounts` before the placement objection. Upstream `PoolManager.unlock` and `SwapMath.computeSwapStep` were read in the replacement pass; `main` is Solidity 0.8.26 and is not a deployment pin.

Confidence: high that exact-output does not by itself size a deposit, that the zero-leg placement call is wrong in range, that current exact-in does not refund, and that the five named loops are searches. Medium on rank-2 frozen-book rounding, which was not executed. Low on end-to-end Orbital liveness after deleting `zapSplitWad`. No fresh trace. No consensus. Stop for the owner.
