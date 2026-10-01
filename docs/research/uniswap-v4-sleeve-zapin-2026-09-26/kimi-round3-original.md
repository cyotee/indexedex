# Kimi K3 — Round 3 independent original: remaining open requirement questions

**Date:** 2026-09-26. Research only; no code/tests/shell/delegation. Read directly this round: updated moderator PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (PZ-1..8, G1–G6, ZA-1..19) and re-verified code regions `UniswapV4StandardExchangeCommon.sol:619-648, 685-713, 730-739, 996-999, 1260-1297`, `UniswapV4StandardExchangeInBase.sol:141-216, 273-315`. PZ-1..8 treated as FIXED; nothing below reopens them. No current-round peer files or cross-review artifacts read. No new external API claims; round-1 Context7 `/uniswap/v4-core` citation (2026-09-26) carries over: `unlock` is permissionless and calls `IUnlockCallback(msg.sender).unlockCallback`.

## 1. Frame: what is genuinely left

PZ-1..8 close route, scope, denominator, sequence, alignment, formula, basket credit and skew priority. What remains falls into three classes: (A) product/security choices still needing the owner (≤5, below); (B) engineering-spec obligations the PRD already names (§2); (C) accepted limitations to disclose, not solve (§3).

## 2. Owner questions (prioritized, with recommendations)

### Q1 — Caller-controlled branch selection: lock-mode pricing differential and roundtrip (critical subtlety; NOT a confirmed exploit)

**Fact base (verified):** the same deposit is priced by two different formulas depending on the gate. Idle composed route: book-aligned min-ratio on post-swap book (`Common.sol:700-704`, PZ-5). Blocked route: single-side invariant growth (`Common.sol:706-712`, ZR-3) with no swap and no deployment. The gate is transient per transaction; `PoolManager.unlock` is permissionless, so a **contract caller can self-select the blocked branch** by calling `exchangeIn` inside its own unlock callback (EOA transactions are always idle at vault entry; only contract callers — hooks, routers, DETFs, or an attacker contract — ever see blocked). Idle zap-out already swaps residual to a single token (`InBase.sol:200-202`), so a roundtrip exists: deposit token0 blocked (invariant-growth credit, zero swap cost) → later withdraw token0 idle.

**Analysis (inference, not an asserted exploit):** invariant growth is CP-honest single-sided pricing, so no branch is trivially exploitable in isolation; the issue is *differential treatment*: blocked depositors pay no composition cost and receive balance-sensitive pricing (rewarded when depositing the scarce token, penalized when abundant), while idle depositors pay swap fee/impact and receive proportional pricing. Compensating factor: blocked deposits earn no fees while sitting in the sleeve and cannot deploy. Whether any roundtrip systematically extracts value from incumbents beyond fees is unproven — I deliberately do not claim one.

**Owner question:** accept the branch differential as designed (blocked = CP-single-side pricing + no fees earned + no deployment; idle = proportional + composition costs), with disclosure and a mandated adversarial roundtrip test (blocked-deposit → idle-withdraw and idle-deposit → blocked-withdraw, both directions, skewed and aligned books, asserting no systematic gain net of fees)?
**Recommendation: accept + document + test (new ZA-20).** Unifying pricing is impossible when blocked (no swap available); forcing proportional pricing on the blocked branch would under-credit scarce-token deposits and over-credit abundant-token ones relative to CP fairness.

### Q2 — Execution protection under the unchanged ABI: what does `minSharesOut = 0` mean now?

**Fact base:** PZ-1/ZR-1 forbid new mandatory ABI args, so no `minCounterOut` parameter can be added to `exchangeIn`. Current check is `sharesOut < minSharesOut → revert` (`InBase.sol:296`); `0` is accepted. **Key structural observation:** because minting is last (PZ-4) and shares are priced on the post-swap measured basket (PZ-5/PZ-6), *any* value lost in the composition swap (fee, impact, sandwich) shrinks `C` and therefore shrinks `m` proportionally — **`minSharesOut` is already an end-to-end bound on total composition quality**, not just the mint leg. A caller who sets it correctly is protected without a swap-specific parameter; a caller who sets `0` opts out.

**Owner question:** is `minSharesOut = 0` a permitted opt-out (recommend: yes — standard DeFi semantics; document that on this route it also unbounds the composition swap), or should the composed route reject `0` / apply a policy default bound (which requires choosing a reference — the still-open G5 bound source; a spot-relative cap does not establish fair price under manipulation)?
**Recommendation:** permit `0` as explicit opt-out, document the enlarged meaning, and keep G5's bound-source choice internal to solver quality (finite price limit), not as a second user-facing guarantee. Do not invent a TWAP mandate (PRD §7 agrees).

### Q3 — Pretransfer provenance on the composed route (previously flagged; needs a decision, not just a test)

**Fact base (verified this round):** `_secureTokenTransfer` (`Common.sol:1270-1289`) with `pretransferred=true` credits `amountIn ≤ U` where `U` = face unbooked balance (`balanceOf − (R − deployed)`); it does not prove the caller delivered it. A prior unbooked donation can satisfy the check and be captured as "current-call" principal — and under PZ-2 it would also become **swap input**, laundering a donation into composed, deployed inventory attributed to the capturer. PRD §6.1 records the gap and ZA-18 demands honest integrations stay supported, but no mechanism is chosen.

**Owner question (three options):** (a) accept the donation-capture race with tests and disclosure; (b) on the idle composed route only, require the measured-pull path (treat `pretransferred=true` as unsupported → revert), leaving blocked/Multi/withdraw pretransfer behavior untouched — ABI-preserving, kills the capture vector where new economics live, but breaks push-based integrators on that route; (c) add provenance accounting (e.g., per-call expected-delivery witness) — more design, still ABI-fragile.
**Recommendation: (b)** for the composed route in v1, revisited only if a real push-based consumer needs idle composition. Blocked-route pretransfer stays as-is (it mints against totals; capture risk there is the pre-existing accepted D29 surface).

### Q4 — Dust/min-compose threshold and prohibition of an idle sleeve-fallback

**Fact base:** ZR-4 allows "approved dust behavior" as a named no-composition case, and forbids silently converting a failed zap into a successful uncomposed one. But note the trap the PRD does not yet name: if the idle route may fall back to sleeve-only mint for dust, then *any* caller can choose sleeve-only economics at will (a contract caller already can, via Q1; a dust fallback extends this to EOAs). Composition becomes optional, and the bug this PRD fixes can be re-created deliberately.

**Owner question:** define a minimum composable amount (per-token, aligned with the D22 absolute floor) **below which the idle composed route reverts**, and confirm there is **no idle sleeve-only fallback** for non-dust inputs — idle composes or reverts, period?
**Recommendation: yes to both.** Idle route: compose or revert; dust threshold = `max(absoluteFloor_i, solver-tolerance-derived)`; below it, revert with a clear error. This keeps branch selection exclusively lock-driven (Q1) rather than amount-driven.

### Q5 — Coupled-token sleeve adequacy under skew, and zero-deployed/all-free behavior under `F = pD`

**Fact base:** targets are independent per token (`F*_i = T_i·p/(1+p)`, PZ-3). Under skew, per-token feasibility diverges (PRD §6.3: token0 free 128⅓ vs target 18⅓ — accepted residual). The uncovered corollary: blocked amount-out cover is only as good as the **worse** token; a fat token0 sleeve does not pay a token1 withdrawal (D18 verified, `InBase.sol:154-167`). Add/remove-only placement can refill a scarce-token sleeve by *removing* liquidity (returns both tokens at CL ratio; existing `_refillDeficitLiquidity`, `Common.sol:881-924` accepts dual overshoot) — so the scarce-token floor is recoverable when deployed exists, but **not** when `D = 0`. Edge: with `D = 0`, `F* = 0` → policy demands full deployment; a one-sided all-free book can deploy only at binding-min, leaving residue; and reporting views must define zero-deployed behavior (PRD §4 line 96 already flags `actualLiquidReservePercentage` free/total mislabeling).

**Owner question:** (i) confirm per-token independent targets remain the whole policy (no coupled minimum-cover requirement across tokens), with published sleeve health reported as `min_i(F_i/F*_i)` for operators; (ii) confirm `D = 0 ⇒ F* = 0 ⇒ best-effort full deploy, never revert solely for that`, with blocked cover simply unavailable until deployment exists?
**Recommendation: yes to both**, plus NatSpec/view updates so an all-free book is never labeled "on target" and a zero-deployed book never divides by zero.

## 3. Accepted limitations to disclose (not questions)

1. **Hook-sourced inventory never composes.** The motivating consumers (buffer hooks) always call mid-unlock → always the blocked branch. Alternating-token hook flow deploys over time via ordinary tail rebalance (both excesses present), but persistent one-sided hook flow accumulates as undeployed sleeve indefinitely (ZR-5 accepted). Release notes should say so.
2. **Skew residual is permanent until exogenous correction** (withdrawals, price moves, opposite-side deposits) — PZ-7 accepted; residual must be a *reported quantity* (engineering item E4), not just narrative disclosure.
3. **`p=1e18` = half-free maximum**; no all-liquid mode (PRD §4, fixed).
4. **Semantic change of existing 0.20e18 settings** (20% of deployed = 16.67% of total cover) — release documentation duty; no re-anchor (G3 fixed).

## 4. Non-owner engineering-spec / test obligations (already implied; consolidated)

- **E1 — Bound source & solver:** G5 selection; bounded monotone solver for `C(x) ∥ B(x)` with ≤ fixed probes (precedent `Common.sol:182-200`); finite `sqrtPriceLimitX96` (not the MIN/MAX at `Common.sol:669-670`); convergence proof under hook-adjusted quotes (ZA-15).
- **E2 — Hook/dynamic-fee support matrix:** define projectable-hook set (`_supportsProjectedHook` / `_adjustHookSwap`, `Common.sol:94-96, 226`) with fail-closed behavior elsewhere; preview/execution parity only within it (ZA-8/9/10).
- **E3 — Ordering spec:** fee-collect → measured pull → bounded swap → post-swap B/C measurement → placement to fixed `F*` → mint → checks; one-vs-two unlock decision with callback authentication (`Common.sol:996-999`) and zero residual deltas.
- **E4 — Reporting:** residual composition event (basket, deployed, retained, post `F/D` per token), deployed-relative sleeve ratio view with defined `D=0` behavior, relabel/retain `actualLiquidReservePercentage` decision (`LiquidReserveTarget.sol:69-83`).
- **E5 — Exception isolation:** ZR-4 requires specified soft-failure semantics for optional housekeeping; current `_rebalanceLiquidReserveBestEffort` does not isolate downstream reverts (`Common.sol:734-739`) — specify try/catch or propagation.
- **E6 — Tests:** ZA-1..19 plus new **ZA-20 (Q1 branch-differential roundtrip)**, **ZA-21 (Q2 minShares=0 sandwich bounds)**, **ZA-22 (Q3 pretransfer donation-capture)**, **ZA-23 (Q4 dust revert / no idle sleeve fallback)**, **ZA-24 (Q5 D=0 and scarce-token sleeve recovery via remove)**.

## 5. Out of scope / already resolved (do not re-ask)

PZ-1..8; D59 bootstrap; full-range imports; native/WETH; swap-free public rebalance; denominator recalibration (rejected); opt-in selector (rejected); TWAP mandate (not law); backlog repair (separate feature).

## 6. Confidence and gaps

High: Q1 mechanics (gate transience, permissionless unlock, dual pricing branches — code-verified), Q2 end-to-end bound observation (follows from PZ-4..6 algebra), Q3 code reading, Q4/Q5 logic. Medium: Q1's net roundtrip profitability — deliberately unproven; test will decide. Gaps: no tests run; upstream port pin unverified; `VaultFeeOracleQueryFacet` fallthrough lines cited by peers in round 2 remain unverified by me (consistent with D8 law). Nothing here authorizes implementation.
