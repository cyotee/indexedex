# Kimi K3 — Cross-review: Uniswap V4 SE sleeve zap-in (2026-09-26)

Reviews the three ORIGINAL reports (`astra-original.md`, `grok-original.md`, `minimax-original.md`) as untrusted model evidence. My original findings (`kimi-original.md`) are preserved unchanged; revisions below are labeled. Research only — no code edits, tests, or implementation. Code citations re-verified against my own first-pass reads of `Common`/`InBase`/`InTarget`/`LiquidReserveTarget` and both family PRDs.

## 1. Agreements (all four originals)

1. **Root cause is identical across all four:** idle single-token zap-in mints shares correctly but the tail deploy computes `getLiquidityForAmounts(spot, fullRange, excess0, excess1)` with counter-token excess = 0 → L = 0 → excess stays free (`Common.sol:557-576, 843-845`; `InBase.sol:309-314`). Conjunction of D30 (full-range always-in-range) + D27 (deploy-excess-only) + D28 (no rebalance swaps) + D32 (leftover stays free). Consensus is well-founded in code.
2. **Blocked path untouched:** PM in-session ⇒ no swap, no unlock, sleeve mint; PM idle ⇒ vault may open unlock (`Common.sol:315-317, 676-680`).
3. **Sleeve fraction is per-token of TOTAL** (free+deployed), live oracle read (D17/D20); never sell the scarce-token sleeve to form ratio. Astra's arithmetic gloss (20%-of-total ⇒ free/deployed = 25%) is correct and consistent.
4. **Caller-only composition; public `rebalanceLiquidReserve` stays swap-free.** Whole-book backlog (blocked deposits, donations) is not cleared by someone else's zap-in; a permissionless whole-book swap is a distinct treasury-risk feature (Astra §3.5; Grok R5; MiniMax §3 row 3; my §3.2).
5. **Supersession set:** D27 (deposit shape), D28 (narrow carve-out: deposit-route swap ≠ rebalance swap), D32 (leftover fallback only), D24 (previews — see §4). D59, D17, D45, D1/D2/D4/D18 stay.
6. **Native/WETH:** WETH ERC-20 face, PoolKey order, wrap/unwrap only inside PM settlement (`Common.sol:411-425, 1096-1118`). No native sleeve, no payable ETH deposits.

## 2. Evidence that changes my view (revisions to kimi-original)

**R1 — Swap-before-mint beats mint-before-swap.** My original kept mint-first (share math untouched) with the swap on vault inventory post-mint, socialization "bounded by the TWAP gate." Grok (R2, Economics) and Astra (§4) convince me this is the wrong order: mint-first + whole-book trade socializes swap slippage/impact across incumbents, and `minSharesOut` then cannot bind the real economic outcome. Swap-before-mint charges LP fee + impact to the depositor's own issuance. **I retract my mint-first recommendation.** Consequence Astra correctly flags: this makes the **issuance equation approval-blocking** — dual min-ratio on post-swap amounts (`Common.sol:700-704`) vs the current invariant-growth single-side formula (`:706-712`) donate surplus differently when the incumbent book is skewed. The PRD must specify the exact equation, rounding, and fee attribution; no one-token NAV.

**R2 — Preview must include the swap leg.** My original recommended classifying swap+deploy as rebalance-like so D24 previews stay unchanged. That only worked under mint-first. Under swap-before-mint, `sharesOut` depends on the swap fill, so preview==exec REQUIRES simulating the composition quote (with hook adjustment) — D24 narrow supersession is mandatory, not optional (Grok Previews; Astra §4 including transition quotes `InQueryTarget.sol` and SY consumers). **Revision accepted.**

**R3 — Failure semantics: atomic revert pre-mint, not skip.** My original recommended skip-to-D32-leftover (D11-consistent). Under swap-before-mint the failing step precedes any mint, so an atomic revert costs the depositor only gas and socializes nothing; `minSharesOut` + an impact bound must bind the post-swap mint (Grok R2: "Do not best-effort an unbounded swap"). I narrow my D11-skip stance to post-mint deploy dust only. Related FACT Astra surfaced and I verify from my own read: `_rebalanceLiquidReserveBestEffort` calls `_rebalanceLiquidReserveInternal` directly (`Common.sol:734-739`) — no try/catch, so "best-effort" is naming, not exception isolation; downstream reverts propagate today. The PRD should require try/catch isolation or document propagation, independent of this zap-in change.

**R4 — TWAP gate is a recommendation, not approved law.** My original invoked "mandatory price gates with reserve-swap fallback" (CLAUDE.md non-negotiable 5) as if it bound SE vaults. That is DETF law. For the SE swap leg the impact-cap source is an OPEN decision: user-supplied `minCounterOut`/`minSharesOut`, finite `sqrtPriceLimitX96` from a spot-bps cap, or the bound TWAP (`_pokeBoundPoolTwap`) whose manipulation-resistance is unverified (Grok Unresolved 1). **Correction:** no TWAP requirement should be presented as inherited law.

**R5 — Selector strategy: I now lean additive opt-in over modifying the default route.** My original assumed amending the existing single-token zap-in. MiniMax's new-selector facet (`zapInSwapAndJoin`, blocked ⇒ revert `PoolManagerInteractionBlocked`) is more consistent with this repo's locked pattern of additive facets and "existing In/Out selectors, economics, sleeve gates do not change" (FULL_RANGE PRD goal 6, D48/D51). Grok's modify-default fixes UX for all callers but silently changes economics of an existing route integrators may rely on. **Owner decision; my recommendation: additive facet first, optional later default migration.** Under the additive design, MiniMax's blocked⇒revert is correct (the existing sleeve-mint route remains the lock-safe fallback).

## 3. Specific objections and corrections to peer findings

**MiniMax (most objections):**
- **FACTUAL ERROR** (§2.1, line 40): claims the single-token mint branch returns `mulDiv(amount, supply, reserve)`. False for the normal case — linear mulDiv applies only when one reserve is zero (`Common.sol:698-699`); with both reserves nonzero the single-side branch is the invariant-growth formula (`:706-712`). This matters for the issuance-equation spec (§2 R1).
- **D59 violation:** T3.EXT/§4.6 proposes single-token zap bootstrapping an empty vault via swap ("creates both-token LP position"). That is a D59 carve-out none of Astra/Grok/Kimi support; Astra explicitly warns against "a circular promise that a single-token first deposit creates its own counter-liquidity." **Reject unless the owner explicitly reopens D59.** Also §4.6 miscites "D8" (oracle stored-0 semantics) for the empty-mint rule.
- **`_executeDirectSwapIn` reuse (§4.2/§5) is wrong-shaped:** that helper pays `tokenOut` to a recipient and syncs/rebalances (`InBase.sol:72-87`); the composition swap must keep proceeds on the diamond. A new internal swap step is required — MiniMax's "no new code beyond wiring" implication understates the change.
- **Overstatement** (§1): "the vault is already at 100% sleeve / 0 deployed" — sleeve grows unboundedly *for the deposited token*, but an existing deployed book does not unwind.
- **Imported-position block (§8) is over-cautious:** under D57/§24.7.1 (lines 1153-1161) imported positions are normalized to full range and "an imported narrow-range position must not remain the backing structure of a newly activated vault"; both family PRDs' line-3 headers mark "unchanged imported ticks" as historical. Grok's R4 (out-of-range import deploys one-sided without swap; in-range import composes like managed) is better aligned with current authority. MiniMax also did no external-source verification (self-acknowledged gap) — its PoolManager claims rest on local code only.
- Credit where due: the DETF-side vs SE-side distinction (§2.5) is a useful, apparently accurate scoping contribution; and the opt-in facet surface is the strongest part of its report.

**Astra:**
- Agree with the approval-blocking economic spec, post-swap CL ratio solver (not 50/50, not vault-total ratio — note vault-total ratio is Multi D44's rule and must stay Multi-only), explicit dust/boundary behavior, and hook-compatibility fail-closed quotes. The `UniswapV4QuoteService.sol:138-145` "legacy sum-based initial zap quoting" flag is **unverified by me** — implementation plan must check before reuse.
- The deadband-test-laxity claim (`_assertFreeWithinDeadband` allowing total/4–total/2 slack, `LocalLiquidBuffer.t.sol:492-514`; T1b at 148-163) is **corroborated by Grok (31) but unverified by me**: the cited path does not exist at `test/foundry/spec/protocols/.../standardExchange/` and scoped glob retries abort on broken `lib/crane/.grok/skills/*` symlinks (recorded; not retried). Treat as probable-but-unverified; the regression test must use strict per-token target assertions regardless.
- Minor: Astra's T/ abbreviation uses `protocol/` (singular) — path likely `protocols/`.

**Grok:** fewest objections; strongest overall alignment with my revised position. One caution: "two unlocks are simpler" (Unresolved 4) — acceptable, but the swap+add must then treat the mint as occurring between them; share SoT reads must be consistent (totals include post-swap free balances either way, D9). Also Grok's vendored-port line cites (PoolManager.sol 55-64, LiquidityAmounts.sol 66-73) are consistent with upstream Context7 behavior but byte-level upstream pin remains undone (its Unresolved 5 — shared gap).

## 4. Precise recommended PRD decisions (for the owner)

1. **Scope:** new additive facet/selector for idle single-token composition zap (`tokenIn → swap portion → dual join → mint → deploy excess`), existing `exchangeIn` route byte-identical; Multi (D41-D52) untouched. Blocked ⇒ new selector reverts `PoolManagerInteractionBlocked`; existing sleeve-mint route remains the lock-safe path.
2. **Order:** pull → bounded swap of the depositor's excess-only input → mint on post-swap amounts via the explicitly specified issuance equation → deploy excess above live per-token targets → deadband + isolated best-effort tail rebalance. Never swap incumbent sleeve, deployed inventory, or donations.
3. **Issuance equation:** owner must pick and pin (dual min-ratio on post-swap amounts vs invariant-growth-equivalent), with rounding and hook-fee attribution written into the PRD before coding (Astra's blocker — I concur it is the top approval blocker).
4. **Impact protection:** mandatory finite `sqrtPriceLimitX96`/min-counter-out; source of the cap (user param vs spot-bps vs bound TWAP) is an open decision — do not cite DETF price-gate law as authority for SE.
5. **Failure semantics:** atomic revert for the pre-mint swap/mint phase; try/catch-isolated best-effort for post-mint deploy dust only; fix or document the current un-isolated `_rebalanceLiquidReserveBestEffort` (`Common.sol:734-739`).
6. **Previews:** narrow D24 supersession — preview simulates the swap leg (hook-adjusted), mint, and gate-matched route; update transition/SY quote surfaces; fail-closed for unsupported hooks.
7. **Bootstrap:** D59 unchanged — no swap-to-activate. **Imports:** D57-aligned — full-range in-range imports compose like managed; no special block. **Public rebalance:** D28 unchanged (add/remove only); backlog policy: cleared only by later deposit-path zaps/dual joins, unless the owner commissions a separate whole-book feature.
8. **Supersession text:** D27 (new deposit shape as additive route), D28 (carve-out clause: deposit-route user swap ≠ rebalance swap), D32 (leftover = fallback only), D24 (preview inclusion). Explicitly restate D57/D58/D59, D17/D20, D45, D1/D2/D4/D18 as in force.

## 5. Remaining approval blockers / unresolved

1. Issuance equation + rounding + fee attribution (approval-blocking; no formula exists in approved law — must not be invented by implementers).
2. Impact-cap oracle choice and bound; TWAP robustness unverified.
3. Default-route vs opt-in selector (owner decision; recommendation in §2-R5).
4. One-unlock vs two-unlock execution split.
5. Exact upstream v4-core commit pin for the vendored port (shared gap, all reports).
6. Unverified-by-me peer evidence: LocalLiquidBuffer test file/slack claims (glob blocked by broken `lib/crane/.grok/skills/*` symlinks), `UniswapV4QuoteService.sol:138-145` legacy quote flag, MiniMax's `InQueryTarget.sol:107-119` dual-preview gap claim.
7. Whether backlog ever gets a whole-book swap feature (recommend separate PRD if ever).

## 6. Dissent that remains unresolved

- **MiniMax vs the other three on D59 bootstrap-via-swap** — recommend the moderator record this as rejected absent owner ruling.
- **Kimi-original vs Grok/Astra on mint order and failure semantics** — resolved: I adopt swap-before-mint and atomic pre-mint revert (revisions R1-R3).
- No participant disputes root cause, gate semantics, sleeve-of-total, caller-only scope, or D28-preservation for public rebalance.

**Confidence:** high on agreements, corrections R1-R5, and the MiniMax factual error (verified against `Common.sol:692-713`). Medium on the selector recommendation. Originals preserved; this file is my only cross-review artifact.
