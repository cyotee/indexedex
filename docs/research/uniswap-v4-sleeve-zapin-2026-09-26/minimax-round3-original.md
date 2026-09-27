# MiniMax-M3 — Round 3 original: residual requirement gaps

**Author:** minimax/MiniMax-M3 (independent)
**Date:** 2026-09-26
**Prior files preserved:** `minimax-{original,cross-review,round2-original,round2-cross-review}.md` — unchanged.
**Authority re-read this pass:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (PZ-1..8 accepted); `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:349–365, 685–713`; `InBase.sol:281–315, 338–377`; `LiquidReserveTarget.sol:60–95`. No peer reads, no cross-review artifacts, no Context7 call this pass (no new external API claim).

The accepted PZ-1..8 set is fixed for this pass. The questions below are **additional genuine gaps** the council should resolve before the implementation plan, not reopenings.

---

## Q1 (Owner; security) — Pretransfer provenance on the composition path

The existing `_secureTokenTransfer` (`Common.sol:1270–1289`) returns the secure-pull delta when `!pretransferred` and accepts `amountIn ≤ U` (unbooked face) when `pretransferred == true`. **It does not prove provenance**: a pre-deposit can be replayed against a second call if the prior tranche still sits in `U`. With the new path minting shares proportional to `c = pull + measured swap delta`, a replay would mint shares on the second call against a deposit already used to mint on the first call.

**Recommendation.** Require `pretransferred == false` on the new path (fresh `transferFrom` per call). For DETF / external `IStandardExchange` callers that cannot re-enter on demand, add a per-caller consumed-tranche bitmap or nonce in the new facet; do not allow residual `U` credit. This is a smaller blast radius than widening pretransfer acceptance vault-wide. **Do not** weaken `_secureTokenTransfer` itself; the new path is a stricter surface.

## Q2 (Owner; product) — `actualLiquidReservePercentage` view and residual reporting

`actualLiquidReservePercentage(token)` (`LiquidReserveTarget.sol:69–83`) currently reports `free/total`, the old denominator. Under PZ-3 the policy is `free/deployed`. **Owner question:** does the existing view repurpose to `free/deployed` (matching `targetLiquidReservePercentage`), or do we ship a new `actualPolicyFree(token)` view alongside?

**Recommendation.** Repurpose `actualLiquidReservePercentage` to `free/deployed`; it is the natural counterpart of the new oracle `p`. Add a per-token `materialSkewResidual(token)` view returning `max(0, |free_i − F*_i| − deadband_i)` so ZA-1 acceptance (and operators) can independently observe the disclosed residual under PZ-7 without inferring it from share price. Both are **view-only, no setter**.

## Q3 (Owner; product) — Coupled `F* = T/(1+p)` targets under extreme skew

`F*_i = p/(1+p) · T_i` is per-token, **not** coupled. With extreme skew `T = (0.01, 1000)` and `p = 0.20`, `F*_0 ≈ 0.00167`, well below `_absoluteFloor` (`Common.sol:354–365`; 18-dec = `1e12`). Today the rebalance deadband (`_shouldRebalanceToken`, line 371–379) checks `targetFree == 0 ⇒ free > floor`. **Owner question:** when one side's `F*_i` is below `floor`, does the new composition path (a) revert `InvalidRoute`, (b) treat that side as `F*_i = 0` (deploy everything) and accept the policy asymmetry, or (c) accept a caller-supplied flag?

**Recommendation.** Revert `InvalidRoute` when either side's `F*_i > 0 && F*_i < floor`. The asymmetry in (b) silently violates the "per-token `F*_i`" promise; (c) adds a setter-like surface and confuses previews. Disclose in ZA-1 that thin-book vaults are outside the new path and continue to use the existing blocked sleeve-mint + D32 leftover shape.

## Q4 (Owner; product) — All-free / zero-deployed recovery and first-mint interaction

If `T > 0` but `D = (0,0)` (e.g., donations to sleeve, no LP), the new path can deploy the first position via composition + `addLiquidity`. With `totalSupply > 0` but `D = 0`, `_sharesOutForDeposit` (`Common.sol:700–705`) returns `min(a0·S/R0, a1·S/R1)` — both `R_i` are pre-call `F_i` (positive), so shares > 0.

**Subtlety.** With `totalSupply == 0` (first-ever mint), `_sharesOutForDeposit` returns `mulSqrt(c0, c1)` only when both sides > 0 (`Common.sol:693–695`). The new path's composition provides that, so **the new path could bootstrap a fresh vault with a single token via internal swap**. D59 currently enforces dual bootstrap via separate `joinUnbalanced`. **Owner question:** does the new path *replace* the dual-bootstrap requirement, or is the very first deposit still required to fund both tokens through the existing `_executeZapInDualDeposit`/`exchangeInManyToOne` surface?

**Recommendation.** Preserve D59 strictly: when `totalSupply == 0`, **the new composition path reverts** `ReserveNotLive`-style error; first deposit must use the existing dual-input surface. Once `isReserveLive`, the new path is allowed for subsequent single-token deposits. This matches moderator PRD §5 ZR-3 and D59 without reinterpretation.

## Q5 (Owner; product/security) — `minSharesOut = 0` protection under unchanged ABI

Existing `_executeZapInDeposit` (`InBase.sol:296`) and `_executeZapInDualDeposit` (`:359`) only enforce `minSharesOut` as a floor; they do not require `minSharesOut > 0`. A caller submitting `minSharesOut = 0` accepts any non-zero `m`. With the new path, the swap solver may round `m` to a small positive value (e.g., 1 wei) under dust / book-aligned composition.

**Owner question:** should the new path require `minSharesOut >= MIN_SHARES_FLOOR` (e.g., the same `DEAD_SHARES_SINK` floor at `Common.sol:308` / `10 ** max(0, 18-6)` = `1e12` for 18-dec), reverting `SlippageExceeded` otherwise?

**Recommendation.** Apply a per-decimals dust floor inside the new path only; **do not** change the existing `exchangeIn` ABI behavior. The new path is single-sided via internal swap and is more prone to dust-minting attacks than the existing dual-input path; a `MIN_SHARES_FLOOR` aligned with `_absoluteFloor` is consistent with D22 and symmetric in semantics.

---

## Non-owner engineering items (no owner decision required)

| Item | Recommendation |
|---|---|
| **Hook-aware quote coverage** | Verify `UniswapV4QuoteService._adjustHookSwap` (called at `Common.sol:226, 1134`) covers the new path's pre-trade quote; **fail-closed** for non-projectable hooks (Astra-flagged; moderator PRD §7). |
| **Bisection solver** | Reuse the `_inventorySharesIn` pattern (`Common.sol:182–200`, ≤8 probes + bisection); add explicit `maxSteps` constant; revert `SolverStepLimitExceeded` on the new path if the swap quote is too convex for the bounds. |
| **Solver dust tolerance** | Constant `MIN_COUNTER_AMOUNT = max(_absoluteFloor(counterToken), 1e6 wei)` (engineering choice; not owner). Revert `InvalidRoute` if `quoteSwap(x) < MIN_COUNTER_AMOUNT` for the chosen `x`. |
| **Preview parity** | Extend `IStandardExchangeInQueryTarget.quoteExternalDeposit` and `IStandardExchangeTransitionQuote` projections to model the composition: book-aligned `c` ⇒ `_sharesOutForDeposit(c0, c1, S_pre, R0_pre, R1_pre)`. Blocked path preview unchanged. |
| **Test-helper tightening** | Replace `_assertFreeWithinDeadband` slack (`LocalLiquidBuffer.t.sol:492–514`, currently ~25%/50% of total) with a strict per-token helper for the new path; ZA-1 acceptance uses the strict helper. |
| **First-mint vs totalSupply=0 handling** | Reuse existing `_initialResidualShares` (`Common.sol:717–723`) on the new path only when `S_pre == 0`; but Q4 recommends reverting in that case — so this path is dead. |
| **`rebalanceLiquidReserve` permissionless** | Confirm current behavior preserved (`LiquidReserveTarget.sol:90–95`); backlog policy (PZ-8) means blocked-accumulated one-sided inventory stays; tail rebalance after the new path is best-effort and may leave documented residual. |
| **Event surface** | Add `LocalDepositComposed(address tokenIn, uint256 amountIn, uint256 swapIn, uint256 swapOut, uint256 sharesOut, uint256 deployedL)` for telemetry / indexers; preserve existing `LocalDepositWhileBlocked` and `LiquidReserveRebalanced`. |
| **Roundtrip / lock-mode pricing subtlety** | The user does not control `canOpenPoolManagerUnlock()`; MEV surface is the standard sandwich surface on the bound pool, not a new path-specific issue. Disclose in ZA-15 and require `minCounterOut` + finite `sqrtPriceLimitX96`. **No confirmed exploit** under unchanged ABI; not a blocker. |
| **Self-LP fee attribution** | Already locked in PZ-4 (post-swap snapshot; incumbent gains fee; caller pays via slightly less counter-token); record in ZA-7. |

---

## Confidence and gaps

- **High** Q1 pretransfer provenance, Q2 view repurposing, Q4 D59 interaction (existing code makes the call straightforward).
- **Medium** Q3 thin-F* floor (subtle but tractable), Q5 minShares dust floor (engineering judgement; consistent with D22).
- **Low** caller-controlled lock-mode pricing — investigated and **not a confirmed new attack surface**; standard sandwich MEV on the bound pool applies. No exploit invented.
- **Gaps**: `apply_patch` unavailable (used `write`); moderator PRD §7 hook-aware coverage re-confirmed as engineering item; no peer reads, no Context7 calls; no shell/tests; pre-existing `_assertFreeWithinDeadband` slack cited from moderator PRD §2 (test file not opened this pass).

Stopping here per assigned task. Originals preserved.
