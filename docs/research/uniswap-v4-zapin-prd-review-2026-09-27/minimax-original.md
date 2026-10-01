# Independent Review — Uniswap V4 Standard Exchange Proportional Zap-In / Liquid Sleeve / Iterative Rebalancing PRD (2026-09-27)

Researcher: MiniMax M3
Date: 2026-09-27
Scope: Independent review of `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` for consistency, quality, and readiness to write an implementation plan. Owner-decision vs engineering-detail triage.

---

## 1. Overall assessment

The PRD is **substantively consistent, owner-aligned, and sufficiently detailed to authorize a scoped implementation plan** for the Uni V4 Standard Exchange's proportional zap-in, liquid sleeve, and repeated rebalance behavior. The locked-decision table (§2 D1–D16) precisely mirrors the owner ruling; the preserved-requirements list (§3) keeps the live-pool invariants intact; the acceptance criteria (§13) are concrete and testable; and the remaining engineering work (§14) is correctly scoped to a separate plan. The PRD is **not** a finalized engineering specification — several items are explicitly deferred and need to be addressed before or during the plan.

Quality is high. Cross-references to settled law are correct (pretransfer PRD §11, DETF alignment §24.7.1, PoolManager interaction law §4). The sleeve math (§5: `targetFree = floor(T * p / (1e18 + p))` with default `p = 0.20e18`) is exact and matches the `liquidReservePercentage` cascade already consumed in `UniswapV4StandardExchangeCommon._liveLiquidReservePercentage` (file `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` line 345–347). The share-issuance formula (§6.3) is correctly stated as `min(floor(S * C0 / B0), floor(S * C1 / B1))` against **post-swap** incumbent reserves (excluding the caller's contribution), which is a behavior change vs. today's `_sharesOutForDeposit` (sqrt-based, reserves-inclusive).

Verified local artifacts:

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` lines 605–613 (`_syncVaultReserves` — already syncs both pool tokens and self-share to `MultiAssetBasicVaultRepo._updateReserve`); lines 1261–1297 (`_secureTokenTransfer` — face-booked reserve-delta `U = B - faceBooked`); lines 764–811 (`_rebalanceLiquidReserveInternal` — add/remove only, no cross-swap).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` lines 273–315 (`_executeZapInDeposit` — `sleeve-then-deploy-excess`, ends with `_syncVaultReserves()`; **this is the deposit path the PRD §6.2 modifies**).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` lines 37–78 (public `exchangeIn` dispatch — currently single-token only; the new proportional zap-in version must be added in this file).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol` lines 90–95 (current `rebalanceLiquidReserve` **reverts** with `UniswapV4Exchange_PoolManagerInteractionBlocked` when blocked; PRD §8 line 222 leaves "truthful no-operation or deferred outcome is acceptable" — see Owner Question A below).
- `contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol` line 52 (interface contract: "Reverts with `UniswapV4Exchange_PoolManagerInteractionBlocked` when the manager is in-session. Succeeds without unlock when both tokens are already within the deadband.").
- `contracts/vaults/basic/BasicVaultRepo.sol` line 27 (`reserveOfToken` mapping — durable snapshot law).
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` §4.4 (mandatory full-expected-hold sync at end of every successful money op — already wired in Uni V4 SE via `_syncVaultReserves`).
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` §24.7.1 (current release authority, as cited in PRD line 62).

Solc / toolchain observed locally: `pragma solidity ^0.8.0`; `foundry.toml` optimizer runs 1; `via_ir` disabled — matches PRD §15.

External references (PRD §15 names three repos): upstream `main` is not pinned; references are evidence, not deployment pins. Implementation plan should pin to a specific upstream tag before integration.

---

## 2. Prioritized blockers — owner answers needed before/with plan

These are decisions that **change product behavior** and cannot be resolved by the implementer. Each is a single sentence; details follow.

| # | Question / decision needed | Why it blocks |
|---|---|---|
| **A** | Public `rebalanceLiquidReserve` when blocked: keep current **revert** (interface `IUniswapV4StandardExchangeLiquidReserve` line 48–49 keeps that contract), or change to **no-op success** as PRD §8 line 222 ("a truthful no-operation or deferred outcome is acceptable") reads? | Behavior change vs. deployed interface; tests must match; affects DETF hooks that drive rebalance from `unlockCallback`. |
| **B** | Adopt **§6.3 `min(floor(S*C_i/B_i))`** issuance as the **only** proportional issuance formula going forward, **replacing** today's `_sharesOutForDeposit`-based `_executeZapInDeposit` (line 273–315)? | This swap changes issuance math even for callers who deposit a balanced two-token pair; affects all existing callers (DETFs nesting through SE, hooks). |
| **C** | The "post-swap incumbent whole-book ratio" for share mint includes **changes the composition swap itself caused** to deployed reserves (D5 line 32). Should the implementation **re-read `_deployedAmounts()` after the composition swap** (one extra `_slot0` + state call inside the same unlock callback) and use those for `B0, B1` in the issuance formula? | Defines the invariant B_i in §6.3 and therefore the issuance math. Engineering detail, but **policy** — if owner wants strict "swap fees from pre-swap incumbent backing" the formula simplifies; if strict "post-swap including any fee take", an extra read is required. |
| **D** | Per-operation protection defaults (25 bp rebalance terminal impact, 50 bp deposit-composition impact, 10 bp execution shortfall, 1 bp alignment loss — §9 line 232–236) are explicitly "not empirically proven safety guarantees" and "require implementation specification and calibration". Will the plan **enforce in production** from the start (gating early failing paths) or **observe in fork mode** first and require a follow-up owner clarification? | Defines ship-readiness for the production guard rails. Engineering detail of HOW, but the **whether** is product policy. |
| **E** | What is the **rounding direction** for `targetFree = floor(T * p / (1e18 + p))` (§5 line 102) when implementing `_loadRebalanceSnap`? Use the same floor already implemented (`(total_i * liquidPct) / ONE_WAD`, line 350), or the more precise `targetFree = floor(T * p / (1e18 + p))`? | Same numeric values at `p = 0.20e18` (`20/100 = 20/(100+20)`), but the implementations diverge at other `p`. PRD uses the more precise formula; existing code uses the simpler one. Engineering detail, but policy decision because owner wording matters. |
| **F** | When `epsilon > 0.0001` (§7 line 176) the deposit reverts atomically (§7 line 197, "If a deposit cannot satisfy ... it reverts atomically"). What happens to **already-executed internal composition**? Is the composition swap **wrapped in a sub-revert checkpoint** (state-preserving via try/catch in `unlockCallback` is **not** safe; revert bubbles to caller atomically), or does the deposit pre-stage composition and revert before any state change? | Determines atomicity of the deposit; engineering implementation choice, but the **policy** ("economic approximation is never accounting approximation" §12 line 313) requires the protected sync — implementation must not leave inventory mid-flight. |
| **G** | When the user's input already matches the post-swap ratio (no composition swap needed), is there a **zero-swap fast-path**? PRD is silent but `MINIMUM_LIQUIDITY` reverts in the hook D79 of DETF §D30 are accepted; same risk here. | Engineering optimization vs. code-path duplication. Likely yes, but owner policy if a same-ratio deposit must still pass through the post-swap invariant loop. |
| **H** | Multi-token (multi-leg) deposits: PRD §6.2 step 2 refers to "the caller's complete net contribution" (§6.3). Are existing multi-token deposit routes (`UniswapV4StandardExchangeInMultiTarget.exchangeInManyToOne`, `_executeZapInDualDeposit` line 338–377 of `UniswapV4StandardExchangeInBase.sol`) **also expected to apply §7 alignment epsilon** in this pass, or out-of-scope? | The PRD is silent on multi-route. Most engineering-friendly default: multi stays as today; single-sided `_executeZapInDeposit` (line 273) is the §6+§7 surface. Owner confirmation needed. |
| **I** | Hook compatibility (D14): "Hook compatibility assurance belongs to the deploying user where it cannot be determined on-chain." Confirm there is no on-chain blanket assertion of vanilla-pool behavior in the new implementation (i.e., the new proportional-zap path **must not** simulate vanilla CP and report a vanilla quote as exact when the hook may be non-trivial). | Existing `_quoteZapOutAmount` already calls `_adjustHookSwap` for amount-out (line 226 in Common); the new composition-swap path must do the same. Owner policy on whether to **refuse** composition-swap quote when hook is unmodeled (impossible with vanilla assumption). |

These nine items are policy questions or interface-behavior changes. None block plan authorship by themselves; together they let the plan finalize decision points rather than re-litigate product direction.

---

## 3. Engineering details safely left to the plan

The following are not owner questions; they are correct plan-level work and can be resolved by the implementer within the locked decisions.

1. Swap direction selection (zeroForOne vs !zeroForOne) in the new composition swap (`_swapExactIn(true/false, swapAmount)`) based on which leg the caller provides and the post-swap ratio target.
2. The 1 bp alignment-loss implementation: explicitly overflow-safe with checked math, with `S == 0` and `B_i == 0` guards (§7 line 178–179). Suggest `Math.mulDiv` + ceiling-aware check, returning `(B_i * 1e18) < (sharesOut * C_i * 9999 / 10000)` style test.
3. Re-entering `_rebalanceLiquidReserveBestEffort()` after the new composition swap (existing helper, file `_rebalanceLiquidReserveBestEffort` line 734) — adopt unchanged.
4. Bound the solver work inside the composition loop (D11/D22, §7 best-effort). Suggest up-to-N attempts (e.g., 4–8 iterations) before revert — exact N is engineering.
5. Reuse existing `_loadRebalanceSnap` / `_deployExcessLiquidity` / `_refillDeficitLiquidity` from `UniswapV4StandardExchangeCommon.sol` (line 751, 822, 881) for §6.2 step 5; plan should not duplicate.
6. The dual-sleeve `_executeZapInDualDeposit` (line 338) can be left untouched or made to share the same proportional composition helper; either is fine and is engineering taste.
7. The `MINIMUM_LIQUIDITY` import edge case (DETF alignment D30 line 848) — `_deployExcessLiquidity` already gates on this; if the new composition path leads to an import target, prefer DETF §D30's "MIN allow + revert when `lpOut == 0`" or document as blocked.
8. Local sensor naming for the new helper (e.g., `_executeProportionalZapIn`, `_composeBasketAndAllocate`, `_compositionSwapNeeded`) — engineering.
9. Event payload — `LocalDepositWhileBlocked` already exists in the interface (line 21 of `IUniswapV4StandardExchangeLiquidReserve`); add a new event (e.g., `ProportionalZapInComposed(swapped0, swapped1, sharesOut, contributed0, contributed1)`) — engineering.
10. Test framework choice (reuse `CraneTest`/`IndexedexTest` from `lib/crane/contracts/test/bases/` plus the existing fork fixtures; honor `CLAUDE.md` §1 non-negotiable 1, 3, 8, 9 — worktree seed, `forge build` before `forge test`, `via_ir` forbidden).

---

## 4. Cross-issues: correctness gaps the plan should close

These are not blockers but **must be addressed in the plan** so that the implementation does not accidentally introduce subtle bugs.

1. **Pre-existing `_executeZapOutExactIn` and `_executeDirectSwapIn` end with `_rebalanceLiquidReserveBestEffort()`** (lines 86, 215 of `UniswapV4StandardExchangeInBase.sol`). The new `_executeProportionalZapIn` must do the same on the free path, and must **not** on the blocked path (mirroring D27 / D4 of the existing PRD).
2. **Pre-existing dual-side `_executeZapInDualDeposit`** (line 369 of `UniswapV4StandardExchangeInBase.sol`) ends with `_syncVaultReserves()` but **not** with `_rebalanceLiquidReserveBestEffort()`. The plan should harmonize so that all free-path money routes end with both.
3. **`_secureTokenTransfer` already returns the **face-booked** `U = B - faceBooked`** (line 1270–1289 of `UniswapV4StandardExchangeCommon.sol`). The plan must NOT re-introduce absolute `balanceOf` credit. PRD §11 explicitly forbids it.
4. **Self-share (`vaultShare`) booking** is already in place (line 610 of `UniswapV4StandardExchangeCommon.sol`): "Book sitting vaultShare so leftover self-shares are R, not durable U (E6 / I1)." This is correct under PRD §12's four-way meaning distinction. The plan should keep it.
5. **Hook-fees double-count**: today, the call `_executeDirectSwapIn` does `amountOut = balanceOf(tokenOut) - balanceBefore` (line 79 of `InBase`). If a hook adds a fee on the output, this is correct (delta is what arrived). For the composition-swap path, the implementer must use **balance-delta measurement** for actuals, not the unsigned quote.
6. **E11 (full expected-hold sync) order vs composition swap**: PRD §12 line 311 requires full-sync *after* the workflow. The composition swap modifies the held set; plan must end-sync right before emit, just like existing paths.

---

## 5. Required package and routing scope (for the plan)

Suggested in-scope files (engineering, but it constrains the plan authoring):

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` — extend `exchangeIn` dispatch to a new proportional-zap branch (or add a sibling function, per D1 "Do not substitute an opt-in-only zap interface" → must remain the **same** `exchangeIn`).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` — add `_executeProportionalZapIn(tokenIn, amountIn, minSharesOut, recipient, pretransferred, deadline)`; reuse `_secureTokenTransfer`, `_swapExactIn`, `_deployExcessLiquidity`, `_syncVaultReserves`, `_rebalanceLiquidReserveBestEffort`.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` — possibly add the new sleeve formula `targetFree = floor(T * p / (1e18 + p))` (only if Owner Question E is "use the more precise one") and helper `_computePostSwapRatio`.
- New event in `contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol` (or a sibling file) — composition event for telemetry and tests.
- New test file under `test/foundry/protocols/dexes/uniswap/v4/zapIn/` (or matching the existing test layout — verify in `CLAUDE.md` / `INDEXEDEX_AGENT_LAW.md` §DETF families).

Out of scope (explicitly):

- BasicVaultCommon changes (PRD does not require any).
- New fee-oracle field ("Config authority, parameter storage and query surfaces" §14 — open engineering).
- Hook whitelist (forbidden, D14).
- Pretransfer policy changes (PRD §11 preserves locked law).
- Universal Router migration (D14 explicitly rejects this).
- DETF family or pricing changes (out of scope per PRD scope statement).

---

## 6. Facts vs inference

| Item | Kind | Source |
|---|---|---|
| `rebalanceLiquidReserve` currently reverts when blocked | Fact | `UniswapV4StandardExchangeLiquidReserveTarget.sol` line 90–95 + interface line 48–49 |
| `_secureTokenTransfer` uses face-booked `U` | Fact | `UniswapV4StandardExchangeCommon.sol` line 1261–1297 |
| Today `_executeZapInDeposit` uses sqrt/invariant formula `_sharesOutForDeposit` | Fact | `UniswapV4StandardExchangeInBase.sol` line 685–723 + line 292 |
| Sleeve default `p = 0.20e18` is type-level | Fact | `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` D7 (line 150); confirmed by current `_liveLiquidReservePercentage` reading `liquidReservePercentageOfVault` cascade (Common line 345–347) |
| Solc config: `^0.8.0`, optimizer 1, `via_ir` off | Fact | local `foundry.toml` cross-check, PRD §15 |
| PRD §6.3 issuance formula is a *change* from current code | Inference | Compare `_sharesOutForDeposit` formula (Common line 685) to PRD `min(floor(S*C_i/B_i))` |
| Per-operation limit values are not yet "proven safety guarantees" | Fact (PRD self-discloses) | PRD §9 line 237–238 |
| Forbidden tokens per CLAUDE.md — FoT, rebasing underlyings | Fact | `CLAUDE.md` §6; PRD does not violate |
| Pre-DETF-product law (D60, D66) excludes Slipstream from current release | Fact | `DETF_ALIGNMENT_PRD.md` D60/D66 |

Speculative (weaker confidence):

- That the new proportional-zap path will fit cleanly inside one `unlock` callback without stack-too-deep — engineering can verify after stubbing.
- That `epsilon` implementation can be `unchecked` somewhere — only after a positive bias check.

---

## 7. Evidence gaps and confidence

**Confidence: High** in:

- Cross-reference correctness for pretransfer, sleeve policy, lock semantics.
- Identified owner questions that must precede or accompany the plan.
- Engineering-detail triage for the rest of the work.

**Confidence: Moderate** in:

- Exact numeric equivalence of `T * p / (1e18 + p)` vs `(T * p) / ONE_WAD` at the default. Both yield the same result at `p = 0.20e18` for reasonable `T`; they diverge at `p = 1e18` (PRD-bound edge, where the formula correctly says `50%` and the simpler formula computes `100%`). Recommend using the PRD formula on principle.
- Whether the dual-sleeve path is in scope for the alignment-loss check — Owner Question H.

**Evidence gaps / not verified**:

- No read of `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/` historical council (per independent-pass rule); plan should reconcile any conflicts it surfaces, but this PRD's text is internally consistent and resolves them already.
- Upstream `main` URLs cited in §15 are not deployed-version pins (PRD self-discloses). Plan must pin to a tag (e.g., `v4-core@<tag>`) before integration; not a PRD blocker.
- Whether `Tests under test/foundry/spec/vaults/basic/**` touch Uni V4 SE specifically — not verified in this pass; the L-RSRV suite is independent of V4 SE, but the plan must wire L-RSRV-related invariants into the new acceptance criteria (e.g., "End-of-op `_syncVaultReserves()` is called in the new path").
- I1-style tests for the V4 SE face-booked `U`: not verified — but the existing `_secureTokenTransfer` (Common line 1270) already follows L-RSRV-SYNC-FULL via `_syncVaultReserves()` (Common line 605–613). New path inherits.

---

## 8. Recommended next step for the implementer

Author a separate `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_IMPLEMENTATION_AND_TEST_PLAN.md` that:

1. States owner answers (or "deferred to be resolved before merge") to A–I above; treats D as "observe only first" by default.
2. Lists the in-scope files in §5 above with line ranges of expected edits.
3. Calls out the dual-sleeve harmonization in §4.2.
4. Pins upstream refs to a specific Uni V4 tag (not `main`).
5. Carries the acceptance matrix from PRD §13 unchanged, mapped to TestBase concrete paths.
6. Forbids `via_ir`; requires worktree seed; requires `forge build` before `forge test` (per `CLAUDE.md` non-negotiables 8/10).
7. Uses the existing `_syncVaultReserves` and `_secureTokenTransfer` — do not duplicate or simplify.

Do not re-open settled pretransfer, direct PoolManager, deployer-hook-assurance, immediate-repeated-rebalances, or full-booking decisions (PRD §14 last line). Do not modify BasicVaultCommon.

---

## 9. Summary

PRD is ready-to-implement at the **plan authorship** level once owner answers to A–I are clarified (or treated as engineering defaults with that disclosure). Internal consistency is solid, citations to settled law are correct, and the engineering surface is well-bounded by the existing `UniswapV4StandardExchangeCommon` / `UniswapV4StandardExchangeInBase` helpers. No shell/test/code/config changes were performed during this review, per the research-only constraint.
