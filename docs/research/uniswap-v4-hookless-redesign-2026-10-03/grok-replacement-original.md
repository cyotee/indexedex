# Grok replacement original: search-free Hookless redesign

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), operator-authorized replacement after the prior session's `RC_ATTRIBUTION`. Not continuity, not that session's memory, and not consensus. Peer-informed only by the human-authorized Astra original and the replaced Grok original, both treated as untrusted findings. No MiniMax or Kimi original exists. No implementation, measurement, or gas-improvement claim. Historical ~19.9M-gas notes stay unverified.

## 1. Ranked recommendation

**Partial yes.** Ordinary basket deposits, known-share redemptions, and their quotes can be search-free and can keep a reserved sleeve. Autonomous idle single-token Orbital buffering cannot, unless the owner adopts a different internal market.

**Rank 1 — adopt, subject to the owner accepting the lost behavior.** Proportional basket core, algebraic sleeve placement, and idle redemption of an already chosen share amount. No discovery loop on deposit, redeem, or quote. Public swap-repair may remain, but quotes must not call it.

**Rank 2 — only if the owner explicitly wants autonomous scalar entry.** Uniform internal constant-product settlement for single-token entry and the matching single-token exit, in both manager states. This is an internal market against holders, not the current post-swap zap. Do not mix it with pool-priced redemption.

**Reject as the adopted formula:** the replaced Grok quadratic-plus-one-check. It is a continuous candidate, not a directly sized integer identity. **Reject** spot NAV, oracle NAV, `minOut = 0`, gas-cap raises, gas-dependent valuation, and treating `sharesJ` / `sharesK` as reviewed accounting.

**Cannot preserve without search or an explicit reject:**

1. Universal idle single-token alignment to the post-swap incumbent book.
2. Exact-output two-leg share redemption. Stays `InvalidRoute`.
3. Both sleeve targets when the inventory ratio differs from the position ratio, without a holder swap.
4. Interleaved holder swap-repair inside quotes.
5. Orbital exact face-trimming and buffer inversion, unless rank 2's closed inverse is adopted.

## 2. Challenges to the two priors

**Astra.** Agree that deleting holder maintenance does not delete caller-composition sizing, and that a fixed-state invariant is not economic safety across repricing or maintenance. Disagree with ranking the internal market first while D5 still assigns swap repricing to incumbents. Idle redemption of a known share amount is already sized: burn `floor(l*r/S)`, pay the pro-rata slice, and forward-swap the known other entitlement (`Common.sol:178-192`). The search on that quote is the later `_inventoryRebalance` (`InQueryTarget.sol:150`), not the redemption swap. Forcing every idle scalar exit onto local cover is required only if entry is also internal CP. It is not required to make redemption search-free. Reinterpreting the 50 bp pool-impact bound as movement of `B1/B0` is a new bound, not D20.

**Replaced Grok.** Agree that basket mint and blocked F1 do not search, that tick crossing has no single quadratic, and that `UniswapV4ZapQuoter` searches (`UniswapV4ZapQuoter.sol:166-228`). Disagree that one quadratic root plus one `SwapMath` check is directly sized. A check that passes shows one integer passed; a check that fails does not show no nearby integer would pass. That is a reject policy, not a replacement for the search. Also disagree with deleting holder swap-repair entirely. The question forbids search on ordinary deposits, redemptions, and quotes, not on a separate public repair the quotes do not call. The fixture vault type is no longer an open gap: `deployUniv4Vault` deploys the hookless package (`UniswapV4DetfProductionSeDeployLib.sol:591-597`). The seeder's liquidity is a tight range around the current tick (`:577-588`), so active `L` need not equal vault `l`.

## 3. Quadratic test, by source inspection, not execution

**Inference, continuous model only.** Inside one step, active `L` and fee are constant and the next price stays strictly inside the first target. Exact-in net is `floor(x*(1e6-fee)/1e6)`; the fee is the complement (`SwapMath.sol:72-88`, upstream `main`, accessed 2026-10-03). Output and position deltas are functions of the rounded next sqrt. Clearing `(c-x)*B_out(t)=y(t)*B_in(t)` is degree 2 if fee and protocol take are proportional and `ρ=l/L` is constant. Protocol fee changes coefficients; it does not raise the degree. Token1-in is the same degree: sqrt moves linearly with net input, and token0 output is hyperbolic.

**Fact: that polynomial is not the integer predicate.**

- Net input is a floor, then `getNextSqrtPriceFromInput` (`SwapMath.sol:86-87`). The next price is not `L*s/(L+n*s)`.
- Output uses `getAmount*Delta` rounded down (`SwapMath.sol:89-93`). Vault position amounts use the vault's `l` and its own rounding (`InventoryMath.sol:70-80`). `ρ*n` is not the position delta when `l` does not divide `L`, and it is not an identity even when `l=L`.
- Own LP fee is two floors: fee growth over active `L`, then growth times `l` (`QuoteService.sol:134-139`; `TransitionPlanner.sol:164`). The lost wei is not in `B`.
- Accepted alignment is after placement rounding, which the planner subtracts from contribution or backing (`TransitionPlanner.sol:135-143`). That loss is another integer delta at the new price, not a term of the pre-placement quadratic.
- If `computeSwapStep` lands on the target, the step did not consume the candidate inside one liquidity piece (`SwapMath.sol:76-81`). Domain failure, not a second root.

**Conclusion.** A quadratic may propose a candidate. It cannot be the sizing equation. Ranking it as the design that keeps single-token entry overclaims. No execution was run; a nearby passing integer remains possible and unmeasured.

## 4. Equations, domains, conservation

Raw token units. `B_i=D_i+F_i+E_i`, excluding caller credit, payout, and refund (`InventoryMath.sol:44-60`). `D` is finite-range position math, not infinite reserves. Collection is `(F,E)→(F+E,0)` once. No new entry fee. A pool swap's price move and own LP accrual stay in incumbent `B`, not in `C`.

**Basket core, both manager states, `S>0` and both incumbent legs positive.** Given supplied `C`, mint `m=min_i floor(S*C_i/B_i)`. Accept only if `10000*m*B_i>=9999*S*C_i` on each positive leg (`ProtectionMath.sol:105-110`). Exact-share request `m` requires `C_i=ceil(m*B_i/S)`, funded, and the forward mint at least `m`. Surplus wei is a booked donation, not searched away. Identified excess above `C` is retained and booked, not refunded on exact-in. No swap, so no placement-before-mint charge is required; algebraic placement may follow and must not change `m`.

Conservation: `B'=B+C`, `S'=S+m`. Placement moves `F↔D` inside that book. Rounding loss stays booked. No asset is created.

**Empty.** Both credits positive. `raw=floor(sqrt(C0*C1))`, caller `raw-minimum`, dead-sink unchanged. No unilateral activation.

**One positive incumbent leg.** Linear mint `floor(S*c/B)` and exit `floor(r*B/S)` only on that leg. Reject a deposit into the empty leg. Do not use one-sided invariant growth when both legs are positive (`StandardExchangeConstantProduct.sol:52-64` is the branch rank 1 must not take on a failed zap).

**Idle redeem of known `r`, `0<r<S`.** Snapshot `F` and `E`, collect once, remove `l_r=floor(l*r/S)`, pay the pro-rata local slice plus that removal's proceeds. Swap the already computed other entitlement with one forward simulation. Tick traversal of that sized swap is allowed. If it does not fully fill, revert. Do not probe a smaller amount. Do not call `_maintenance`.

**Blocked.** No swap and no `modifyLiquidity`. Single-token deposit uses the existing one-sided branch only in this state. Exact-share input is `_amountInForShares` (`:78-95`). Single-token exit is `_singleExit` (`:98-110`) and pays only if local `F` covers. `E` is not cover. Two-leg exact-output shares remain the bisection at `:113-128` and stay `InvalidRoute`. `quoteInputForExactShares` is already `InvalidRoute` when idle (`InQueryTarget.sol:29-31`). Rank 1 keeps that.

**Rank 2, only with owner approval, and only as a matched pair.** Idle and blocked single-token entry both use `:58-95`. The matching exit uses `:98-110` and requires `F_out>=y` even when idle. Do not pool-swap that exit: entry at the book price and exit at the pool price is an immediate hedge. At fixed external position state, the ceil-denominator branch is built so rounding surplus stays with holders. That is a fixed-state statement. It does not price the book against the pool, and it does not survive a later maintenance swap or a donation that moves `B1/B0`.

## 5. Sleeve and blocked cover

Adopt reserved placement, not accidental leftovers and not continuous rebalancing. Live `p`, default `0.20e18`. `target_i=floor(T_i*p/(1e18+p))` with `T_i=D_i+F_i` after the user leg (`InventoryMath.sol:50-52,216-229`). Liquidity is the minimum of the two budget legs at the current price. Either free balance may be zero. Deadband stays `max(absoluteFloor, target/20)` and is a later maintenance report, not a user-op failure.

Separate public repair may still swap under the existing 25 bp bound, off the quote path. Rank 1 does not promise both targets after every user operation.

Blocked operations pay only actual local cover of the requested currency. Nested unlock stays forbidden: `PoolManager.unlock` reverts `AlreadyUnlocked` (upstream `PoolManager.sol`, `unlock`, accessed 2026-10-03). Upstream `main` is Solidity 0.8.26 and is not a deployment pin.

## 6. Orbital, SY, Pons

**Search-free calls Orbital can keep under rank 1.** `quoteTransition(ReceiveShares)` (`IStandardExchangeTransitionQuote.sol:28-31`). `quoteTransition(RedeemExactIn, shares)` after the rebalance call is removed. `quoteAssets`, `quoteShareBalance`, `quoteTotalSupply`. `quoteStateWithUnavailableUnlock`, then the blocked formulas. `depositFlexible` / `withdrawFlexible` when the flags say the amounts are already SE shares (`Common.sol:1677-1680` skips `_bufferToken` for those legs). `sharesForNativeUp` and `ratedNative` (`ClaimLib.sol:314-329`).

**Calls that become invalid while idle.** `exchangeIn(token→shares)`, `previewExchangeIn`, `quoteTransition(DepositExactIn)`, `quoteExternalDeposit` of a pool token, and `quoteInputForExactShares`. `_bufferToken` (`Common.sol:518-534`) is the autonomous scalar path and cannot be preserved. A router plan Orbital cannot pass is not a substitute. While the manager is unlocked, only the blocked formulas are legal.

**Outer searches that survive a Hookless solver deletion.** `_faceForClaim` bisects up to 8 probes (`ExitQuoteLib.sol:347-374`). `_invertBufferForEffective` expands and bisects (`ClaimLib.sol:250-275`). `quoteExternalExchange` calls `_inventoryRebalance` (`InQueryTarget.sol:82`). `planDeposit` calls `DepositExactIn` and `RedeemExactIn` (`ExitQuoteLib.sol:85-126,332-344,376-382`). Rank 1 replacement: deposit the already-sized offered face, value minted shares at `shares × rate`, and do not invert for a face that hits `needed`. That leaves residual face untrimmed. Rank 2 can replace those two loops with one `quoteInputForExactShares` only after that function is defined on the idle domain. Until then, do not invent the inverse.

SY `deposit` / `redeem` stay aliases of the same share routes. No parallel formula. Pons is not merged and does not inherit this accounting change. Pons must not call the Hookless planner (D22). Its fee model is a separate owner decision.

## 7. D1–D31 amendment ledger

Keep D3, D7, D8, D10–D16, D22–D26, D28, D29, and D31 in both ranks. Refresh D27 and D30 for every changed route. D17 still means closed form only. It does not authorize the quadratic or the two-leg exact-output bisection.

**Rank 1.** Amend D1: same family, but idle single-token `exchangeIn` reverts; the ordinary deposit is the proportional basket, not a new opt-in zap beside a still-searching route. Amend D4 and D5: no deposit composition swap and no post-swap alignment post-condition. Amend D6 so a failed or removed zap cannot fall through to one-sided growth. Amend D9 and D21: public repair may still swap, but quotes and user operations must not call it; 1 bp rho is not a deposit post-condition. Amend D18: algebraic placement may interleave; swap repair has no combined closed form and is omitted from ordinary routes. D19's both-modes exception is not a reason to keep a search. D2 and D20's 50 bp composition bound become inapplicable to basket deposits. Keep 25 bp on separate repair, 10 bp shortfall on any executed swap, and 1 bp on basket rounding. D25 stays fixed constants; do not retune them to buy liveness.

**Rank 2.** All rank-1 basket amendments, plus replace scalar D5–D6 with the internal curve, and do not apply D20's pool-impact bound to a fee-free internal settlement. Any internal-price bound is a new owner decision. Idle scalar exit cover is part of that decision, not a silent reading of the blocked-cover rule.

## 8. Risks

Donation of booked surplus changes `B` before mint. Unbooked surplus remains claimable under existing pretransfer law; freeze credit before collection. Protocol fee and other LPs' fees are not `E`. Counting swap output and fee growth double-counts. Same-pool redemption moves every in-range position, including the vault; that `D` change belongs to incumbents. Rank 2 adds a second market: a depositor can buy the cheap internal leg and redeem the other leg up to sleeve cover, or wait for maintenance to trade toward the pool. A fixed-state `K/S` inequality does not cover that cycle. Tick initialization can force rank-1 redemption to revert at the work limit; do not answer by searching a smaller swap. Sandwich protection remains caller `minShares` / `minOut` and the 10 bp shortfall. Never `minOut = 0`.

## 9. Later acceptance and benchmark plan

Do not run it here. Owner selects rank 1 or rank 2 first. Then, on registry-deployed proxies and production-first TestBases, after artifact build: exact quote/execution equality on the certified domain; the same error on unsupported domains; no refinement counter on deposit, redeem, or quote; conservation of `B'+C` against balances, position, and fee checkpoints; blocked cover shortfall reverts atomically; live `p` changes do not use pre-placement principal; donation and same-pool hedge cycles, including rank-2 deposit-then-other-leg exit if that rank is chosen. Replay `V4FundedBindings.t.sol` only as a later measurement, including the 31M SY cap, without raising caps. Orbital traces must show `planDeposit`, `_claimIn`, `_faceForClaim`, and `_invertBufferForEffective` performing no probe loop under the selected rank. A benchmark may count gas, quote calls, and `extsload`s on pinned states. This memo predicts no number.

## 10. Evidence, confidence, gaps

Access date for this pass: **2026-10-03**. Local compiler: `foundry.toml:29-36`, Solidity 0.8.35, optimizer runs 1, `via_ir` false. Context7 library `/uniswap/v4-core` before the upstream reads. Primary: `https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol` (`computeSwapStep` at lines 51-116) and `https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol` (`unlock` reverts `AlreadyUnlocked`; `modifyLiquidity` returns principal plus fees). Charm Alpha Pro, `https://learn.charm.fi/charm/technical-references/core/alphaprovault`: proportional `deposit` is retained until a separate `rebalance`; full range is a manager-set weight, not the product. It is a V3 lead, not a V4 formula. Arrakis, Gamma, and Range were not primary-read this pass and are not relied on.

| Claim | Kind | Confidence |
|---|---|---|
| Idle deposit and redeem quotes search today | Fact, lines above | High |
| Basket mint, blocked F1, and sized redeem swap do not discover an amount | Fact | High |
| Continuous one-step alignment is quadratic | Inference | Medium |
| That quadratic is an integer sizing identity | Rejected by source inspection | High that it is not proved; low that a one-check would usually pass |
| Rank 2 fixed-state rounding does not extract at a frozen book | Inference from the cited branch; not executed | Medium |
| Rank 2 is safe across maintenance or pool hedges | Rejected as a conclusion | High that it is not shown |

**Gaps.** No fresh trace, no integer counterexample execution, no deployed-bytecode pin, no proof of Orbital parity after deleting the outer loops. **Stop for the owner. This memo does not authorize implementation.**
