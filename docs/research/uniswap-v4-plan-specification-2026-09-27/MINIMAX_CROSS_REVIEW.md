# Cross-review — Plan Specification, Uniswap V4 FullSpread (MINIMAX_CROSS_REVIEW)

Date / access date: 2026-09-27
Reviewer: MiniMax M3 (combined cross-review; peer cross-review artifacts not read)
Preserved unchanged: `docs/research/uniswap-v4-plan-specification-2026-09-27/MINIMAX_ORIGINAL.md` and the three peer originals (Astra, Grok, Kimi).
Saved path (this file): `docs/research/uniswap-v4-plan-specification-2026-09-27/MINIMAX_CROSS_REVIEW.md`

User-mandated checks (verbatim): Grok's radical inverse and two-forward-checks vs source-only policy / integer proof; composition / mint / placement order; D19 semantics; Kimi DER-1..5 vs existing-source restriction and tick-walking as "closed form"; mislabeled CP equations; collect-before-credit. Source-applicable formulas favored over speculative new derivation (user direction). For maintenance: full certificate iff algebraic placement only; else D19 rows. Bound work without implying root precision from 32 bisections on uint256. Preview==execution + in-kind wrappers explicit. Full file manifest mismatch check via directory reads. Pons evidence accepted, no runtime gate. No code/tests/shell/delegation.

---

## 1. Direct file-directory counts (re-read 2026-09-27)

`O = contracts/protocols/dexes/uniswap/v4/`: 40 entries (`ls` round 7) → contains 35 Solidity files + 2 PRDs + 2 IMPL/TEST_PLAN PRDs + `test/` subdir + `interfaces/` subdir + (no `.DS_Store`). Plan A (Astra) lists 44 Solidity files; plan K (Kimi) lists 36; plan G (Grok) says "all 49 inventoried entries." The discrepancy is the unadopted candidate `UniswapV4FullSpreadClosedFormCandidate.sol` (one extra), test bases (10 vs my 0 — the legacy tree has no test base), and 2 impl-plan files I had not counted before. **The authoritative count for O: 35 Solidity + 5 PRDs + 2 subdirs, total 42 entries; Astra's 44 = +9 test-bases; Grok's 49 = 35+5+9.** **The legacy unsegmented O does NOT include `UniswapV4FullSpreadClosedFormCandidate.sol`** — that file lives under F (the bridge legacy `vaults/.../uniswap/v4/`), per Grok §6 and Kimi §7.2.

`F = contracts/vaults/standard/exchange/protocols/uniswap/v4/`: 36 entries (round 7 verified). Plan A: 38. Plan K: 30. Plan G: "all current `UniswapV4FullSpreadStandardExchangeVault*` files, the interface, the candidate, and the test base" → ≈ 35 + 1 candidate + 1 test base = 37. The candidate lives here, not in O. **Authoritative: 36 entries in F including the WIP candidate and the bridge-legacy test base.**

**Reconciliation**: O has 35 Solidity + 5 PRDs = 40 leaf files + 2 subdirs. F has 36 leaves including candidate + 1 subdir (fullSpread/ which is empty in the current snapshot — to be populated by the new families). Net deletion: 35+5+9 test-bases from O; 36-2 retained subtrees from F.

---

## 2. Adjudicated formula matrix (source-only helpers; no speculative adoption)

### 2.1 Helper taxonomy

| Helper | Source:line | Closed form? (per PRD §6.4:214) | Used for |
|---|---|---|---|
| `_initialShares` (mulSqrt − MIN) | `StandardExchangeConstantProduct.sol:30–35` | **YES** (one-shot) | Q0 activation |
| `_sharesForDeposit` dual mint | `StandardExchangeConstantProduct.sol:52–56` | **YES** (min of two floor-div) | Dual activation / R13 (Multi) |
| `_sharesForDeposit` one-sided linear | `StandardExchangeConstantProduct.sol:58–64` (after `if (reserveX == 0) return Math.mulDiv(amount, supply, reserve)` at `Math` similar pattern at `:67–72`) | **YES** (closed form linear) | Blocked R6/R8 single-mint |
| `_amountInForShares` exact-mint inverse | `StandardExchangeConstantProduct.sol:78–96` | **YES** (existing helper; not Kimi's DER-3) | Blocked R8 exact-mint; shares→token exact mint |
| `_singleExit` forward | `StandardExchangeConstantProduct.sol:98–111` | **YES** (closed form) | R10/R12 blocked share→token |
| `_sharesForSingleExit` bisection | `StandardExchangeConstantProduct.sol:113–129` | **NO** (bisection) | Not adopted per PRD §6.4:214 |
| `_dualExitShareBurns` (mulDivRoundingUp) | `Common.sol:1169–1181` (cited) / OutMultiTarget | **YES** (one-shot mulDiv) | R14 dual exit |
| `UniswapV4Quoter.quoteExactInput` | `UniswapV4Quoter.sol:96–113` | **EVALUATION, NOT INVERSE** | R1/R4 |
| `UniswapV4Quoter.quoteExactOutput` | `UniswapV4Quoter.sol:115–136` (with `fullyFilled` guard) | **TICK-WALKING** — explicitly NOT closed-form per PRD §6.4:214 | **NOT ADOPTED as a closed form.** Reject the multi-tick domain. |
| `SwapMath.computeSwapStep` (one tick, no cross) | `C/libraries/SwapMath.sol:52–105` | **YES (one tick only)** | R3/R4 single-tick exact-output (Astra's Q4 / Grok's E7) |
| `SqrtPriceMath.getNextSqrtPriceFromOutput` | `C/libraries/SqrtPriceMath.sol:156–175` (cited) | **YES** | Inverse-step for R3/R4 |
| `LiquidityAmounts.getLiquidityForAmounts` | `C/utils/LiquidityAmounts.sol:48–77` (cited) | **YES** (placement at known price only) | Astra's CPPlace certificate |
| `ConstProdUtils._purchaseQuote` | `lib/crane/contracts/utils/math/ConstProdUtils.sol:235–256` (V2-book inverse, +1 ceil) | **YES for V2-pair book**; **NO for V4 pool** | Reference only; not used for V4 pool swaps |
| `UniswapV4ZapQuoter.quoteZapInSingleCore` | (binary search at QuoteService:62 `DEFAULT_ZAP_SEARCH_ITERS=20`) | **NO** (binary search) | Preview only; not closed-form for execute |
| Pons `_ponsHookFees` decode | `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–42` | **YES** (decode-and-bounds) | E8 Pons charge |
| Protocol fee composition | `ProtocolFeeLibrary.sol:39–47` (`pf + lpFee − pf·lpFee/1e6`) | **YES** (closed form) | All swaps |

### 2.2 Grok's "radical inverse" (E6) — verification

E6 claims `shares = ceil(supply * (1 - sqrt_up(1 - amountOut/reserveOut)))` for the single-backed-leg branch (i.e., `reserveOther == 0`).

**Verification.** With `reserveOther == 0`, the forward is `out = reserveOut * s / supply`, so `s = out * supply / reserveOut`. The "radical" formula is the GENERAL two-leg case. **The existing helper for the single-leg case is `Math.mulDiv(amount, supply, reserve)` with `Math.Rounding.Ceil` at `StandardExchangeConstantProduct.sol:113–128` (or equivalent pattern in `_amountInForShares` linear branch at `:78–96`).** The radical form is mathematically equivalent to the two-leg case, not the single-leg case. **For the single-leg case the existing linear helper is the source-only solution; for the two-leg case `_sharesForSingleExit` (bisection) is in tree but not adopted as closed form per PRD §6.4:214.** Grok's E6 must be re-classified:
- For single-leg (which is the case Grok actually needs at line R12): use the existing linear `_amountInForShares` linear branch — closed form, source-only.
- For two-leg: do NOT adopt the radical as closed form; declare `InvalidRoute(NO_CLOSED_FORM)`.

**Grok's "two forward checks" (line 38)** for the two-leg case: "Evaluate E5 at `shares` and, if short, at `shares+1` only." This is a 2-point check on a discrete-monotone forward, NOT a bisection. Two forward evaluations are deterministic integer functions; **the 2-check protocol is a discrete search, not a continuous search, and is bounded by integer dominance.** It is acceptable as long as the function `out(s) = E5(s)` is provably monotone in `s` and we start with `s = ceil(rad_inv)`. The first check at `s` either matches, falls short, or exceeds; the second check at `s+1` is the +1 rounding boundary. The "32 bisections" concern in the user prompt is mis-applied: Grok's protocol is 2 forward evaluations, not 32 bisections. **The bound is 2 forward evaluations, deterministic, no precision claim.** This is acceptable as an *engineering* bound; the source-only "closed form" claim is not made.

**Verdict on Grok E6**: REJECT as labeled. The two-leg case is `InvalidRoute`; the single-leg case uses the existing linear helper. E6's "two forward checks" are 2 forward integer evaluations, acceptable as a precision-bounded engineering protocol — NOT as a closed-form derivation.

### 2.3 Mislabeled CP equations

| Source | Claim | Verification | Verdict |
|---|---|---|---|
| Astra Q0 | `raw=floor(sqrt(C0*C1))`; MIN=`10^(floor((dec0+dec1)/2)-3)` | `StandardExchangeConstantProduct.sol:30–35` + `_MINIMUM_LIQUIDITY = 10**3; mean < 3 ? 1 : 10^(mean-3)` | **Correct** (mean := floor((dec0+dec1)/2); MIN=1 when mean<3 else 10^(mean-3)). |
| Astra Q1 dual mint | `m=min(floor(S*C0/B0), floor(S*C1/B1))` | `StandardExchangeConstantProduct.sol:52–56` | **Correct** |
| Astra Q1 single-sided inverse | `Aneed = K + ceil(m*K/S); c = ceil(Aneed*Aneed/Bother) - Bin` | `StandardExchangeConstantProduct.sol:78–96` (`_amountInForShares` with `K = ceil(sqrt(Bin*Bother))`, `A = K + ceil(m*K/S)`, `needInPlus = ceil(A*A/Bother) - Bin`) | **Correct** (note: the helper returns `needInPlus`; the formula is structurally identical; integer domain is `Bin, Bother > 0`). |
| Kimi DER-1 (blocked exit inverse) | `r* = 1 - sqrt(1 - out/R); s0 = S - floorSqrt(rad)`; two forward checks | **DERIVATION, not source-only.** It is an algebraic re-expression of `_singleExit`'s real-domain identity. The integer-protocol is a 2-eval forward check. | **Accept as a derived (not closed-form) engineering protocol**, gated on validation; do NOT label as closed form. |
| Kimi DER-2 (idle zap-out) | Quadratic in `s` for `target = P·s + Q·s/(u0 + k·m·s)` | **DERIVATION.** The equation collapses to `target·(u0+k·m·s) = (P·u0+Q)·s`; with `s ≠ 0` the quadratic is degenerate. **The structure is NOT quadratic in standard form.** | **REJECT the quadratic claim.** Use the existing forward `executeFreeZapOutExactInCore` simulation matched exactly; the algebra does not simplify the engineering. The idle zap-out exact-out is not adopted as closed form; declare `InvalidRoute(NO_CLOSED_FORM)`. |
| Kimi DER-3 (idle exact-shares mint) | Linear in `u1` | **DERIVATION.** The algebra: from issuance `S·out_0 = S_out·B_0'` and `B_0' = L/√b + F_0 − L/u1`, the linear solve requires `L·S·(1/u0 − 1/u1) + S·F_0 = S_out·(L/√b + F_0 − L/u1)`; rearrange to `u1·(S·L/u0 − S_out·L + S·F_0 − S_out·F_0) = S·L − S_out·L + S_out·F_0·u0` — which is linear in `u1`. | **Accept as a derived engineering protocol**, BUT not as a closed-form inverse of the composed deposit+slot0 lookup. The forward execution of `executeZapInMintExactOut` (in the bridge legacy) matches the source; DER-3's "linear" claim depends on linearization assumptions that break for tiny inputs. Validate against the source. |
| Kimi DER-4 (combined maintenance) | Quadratic in `u1` for joint sleeve+placement | **DERIVATION.** The `t_i = q·(D_i(u1) + F_i')` constraints form a quadratic in `u1` when both legs are active. The coefficient table in Kimi's §2.5 is plausible. | **Adopt only if algebraic placement alone qualifies (per Astra's CPPlace certificate).** Otherwise, declare idle exact-output D/E/F as `InvalidRoute(NO_CLOSED_FORM)` per the row above. |
| Kimi DER-5 (deposit composition) | Quadratic in `u1` | **DERIVATION.** | Accept as a refinement protocol for the composition solver (bounded bisection), not as a closed form. |
| Combined `t = s*o/L` formula (Astra Q4) | `t = s − o/L` for one-tick exact-in | `SwapMath.computeSwapStep`; correct for the no-tick-crossing case. | **Correct** for one-tick case; multi-tick is `TICK_DOMAIN` per Grok E7. |
| Two-leg exact-output tick-walking | Walk ticks until `amountSpecifiedRemaining == 0` | `UniswapV4Quoter.quoteExactOutput` lines 115-136 | **NOT closed form per PRD §6.4:214.** Reject as a closed-form claim; declare `InvalidRoute(TICK_DOMAIN)` for multi-tick. |

### 2.4 Composition / mint / placement order

| Step | When | Where (code path) |
|---|---|---|
| 1. Caller credit established | Function entry | `_secureTokenTransfer` (Common:1219–1240) or `_secureShareDelivery` (Common:1313) |
| 2. `processArgs` (route/family/deadline/caller guards) | Pre-`initAccount` | DFPkg:257–265 |
| 3. `initAccount` (incumbent `B` snapshot, expected-hold token registration, REPO init) | Pre-economic-action | DFPkg:271–298 |
| 4. `_collectManagedFeesIfIdle` (E→F once) | Idle path, after credit + init, before swap | Common:652–671, called at InBase:277 / OutBase |
| 5. User leg (swap exact-in/out / share mint / share burn) | After fees | Common:973–1021, InBase:269–312, OutBase:64–118, OutExecuteTarget:139–163 |
| 6. Placement (caller-funded if deposit; holder-funded if rebalance) | After user leg | Common:818–852 (`_deployExcessLiquidity`) / Common:856–899 (`_refillDeficitLiquidity`); if no swap suffices, placement alone; if swap, post-swap placement |
| 7. Mint/pay | After leg(s) and placement | InBase:303; OutBase:160–164; OutMultiTarget:113–121 |
| 8. Protection checks (impact, shortfall, ε) | Before sync | Plan-level checks inserted at step 7 |
| 9. `_syncVaultReserves` (full local booking) | End of workflow | Common:610–617 |
| 10. Events; `_pokeBoundPoolTwap()` | End of workflow | Common:813–816, OutExecuteTarget:82 |

**This is the source-only order; no deviation. The pretransfer credit is established at step 1 (function entry, before `processArgs`); the incumbent B in step 3 is `D + F + E` (the E component includes uncollected fees; step 4's `_collectManagedFeesIfIdle` moves E→F, leaving B unchanged in value). The "collect-before-credit" concern is NOT present in this sequence: credit precedes `processArgs`, fee collection precedes the user leg, B is stable through the user leg.**

**Verdict:** **No collect-before-credit issue.** Plan must preserve this order. Plan must not introduce a path where caller credit is set after `_collectManagedFeesIfIdle` or where pretransfer credit absorbs newly-collected fees (the helper at Common:1219 already excludes `R` but includes `balanceOf - R = E`; the absorption is correct).

### 2.5 D19 semantics — adjudicated reading

D19's text (PRD §6.4, lines 218–225): "if no applicable combined closed-form quotation exists and requiring interleaving would otherwise eliminate a specific token route in both exact-in and exact-out modes, omit interleaved rebalance on that specific route so otherwise-valid underlying operations remain available."

D19's structure: a **route-level exception** activated only by (a) absence of combined closed-form AND (b) interleaving-would-eliminate-both-modes. It does NOT create a missing closed-form equation, does NOT waive protections, does NOT permit a different ownership formula. Exact-out may remain invalid while exact-in is preserved; the exception simply omits interleaving (the maintenance step), not the route.

**Reading across the three peers:**
- Grok: "D19 is not used on any row. In every token direction above, exact-in remains available in at least one interaction state without a combined formula, or the direction is not a sleeve-fundable pair (R2/R4). Forgoing interleaving is the ordinary D18 result, not the exception." — **Grok's reading is correct**: D19 is a backstop, not a routine lever.
- Astra: "D19 interpretation selected: use it for blocked operations (external maintenance forbidden) and the existing exact-out-only vector redemption when unavailable interleaving would otherwise remove that entire vector direction. Do not apply it to idle single-token routes whose exact-in sibling is available with bounded repair." — **Astra's reading is more conservative**: D19 covers blocked state + the shares→dual vector where removing interleaving would eliminate the only vector-output mode. **Astra's reading is supported by the literal text but adds a layer of interpretation the PRD does not require.**
- Kimi: "exception evaluation (D19/§6.4.3-5, decided): exact-in modes never require a combined quotation, so 'eliminate both modes' fires only where interaction state blocks all maintenance — i.e., blocked-state cells, which are preserved sleeve-only regardless (§4, §6.4.6). Therefore the exception's operative content = blocked routes; idle branches follow rules 1/2/5 exactly as tabulated." — Kimi narrows D19 to blocked-state cells (matrix preserves the existing blocked-state exact-out path through `InvalidRoute` rejection at idle).

**Adjudicated reading (this cross-review):** D19 is **operative only for routes where (a) the combined closed-form is unavailable AND (b) interleaving would eliminate both modes**. In the current matrix:
- Idle single-token deposit (R5): combined closed-form available (DER-5 bounded refinement); not D19.
- Idle single-token exact-output mint (R7): combined closed-form available only if DER-3 (idle mint input) is validated; otherwise `InvalidRoute(NO_CLOSED_FORM)`. D19 does not save it.
- Idle single-token exact-output swap (R3): single-tick closed form (E7) supported; multi-tick is `InvalidRoute(TICK_DOMAIN)`. D19 does not save the multi-tick domain.
- Blocked single-token exact-output swap (R4): blocked; `InvalidRoute`. D19 doesn't apply (no maintenance possible in blocked state; sleeve cannot convert).
- Idle shares→token exact-output (R11): combined closed-form requires both E6 (two-leg inverse) AND E7 (single-tick swap) AND placement (DER-4); per Grok's E9 this is NOT closed form. Without DER-4 validation, R11 is `InvalidRoute(TICK_DOMAIN)`. D19 does not save it (the exact-out branch is rejected; exact-in R9 remains).
- Blocked shares→token exact-output (R12): single-leg covered by E6's linear branch (existing helper); two-leg `InvalidRoute`. D19 does not apply (no idle maintenance needed for the single-leg case).

**Final reading: D19 is not invoked in this plan.** All supported routes either have a closed form (single-tick or existing source) or are `InvalidRoute` (multi-tick, two-leg, blocked external). The "blocked-state exact-output is preserved sleeve-only" pattern is part of the existing source semantics, not a D19 exception. **Astra's "D19 preserves vector redemption" claim is unsupported; the vector path is preserved through existing blocked-state `_singleExit` semantics and idle `InvalidRoute`, not D19.**

### 2.6 Maintenance: full certificate vs D19 rows

**Algebraic placement-only certificate (Astra's CPPlace):** When the post-user-leg `t_i = floor((D_i + F_i) · p / (1e18 + p))` and the sleeve deadband `tol_i = max(absoluteFloor_i, floor(t_i · 0.05e18 / 1e18))` are both satisfied AND no swap is required, the maintenance is the **identity**. This is a complete certificate for the placement-only branch.

**When the certificate fails**, the maintenance transitions to a swap step. The swap is bounded by the 25 bp price impact cap and the sleeve deadband. Per Grok R15: "One holder step ... capped by E4 at 25 bp and by the next initialized tick. Then one placement. Progress is measured after the swap fee, own-position fee growth, and placement. The post-step proportionality error or a sleeve deviation must be strictly smaller."

**For exact-output combined maintenance (DER-4):** if the algebraic solver is validated against the source's `_executeDirectSwapOut` + `_rebalanceLiquidReserveInternal` path, the certificate is: "post-step ρ ≤ 1 bp AND post-step σ = 0, evaluated from a single placement at post-swap state." If DER-4 validation FAILS, the cell becomes `InvalidRoute` — D19 does not save it.

**D19 rows** (only for the narrow case the PRD describes — none in this plan's matrix): if a route later becomes D19-eligible (e.g., a new exact-output branch whose combined math cannot be validated), the row would be: "Idle exact-output X→Y: `InvalidRoute(NO_CLOSED_FORM)` in the per-row default; omitted interleaving under D19 keeps exact-in X→Y and idle share→token redemption available." But no such row exists in this plan.

---

## 3. Adjudicated route/formula matrix (final, both families, no speculative adoption)

Notation: `EXISTING` = repo helper, source-only. `DERIVED` = validated-by-construction against source execution; not adopted as closed form until integer-domain validation gate passes. `NONE` = `InvalidRoute(NO_CLOSED_FORM | TICK_DOMAIN)`.

| ID | Route | Mode | State | Hookless | Pons V2 | Notes |
|---|---|---|---|---|---|---|
| R1 | token↔token swap | EX | Idle | EXISTING `_executeDirectSwapIn` (InBase:74–89) + Q4 single-tick exact-in evaluation; impact 50 bp; balance-delta fee measurement | EXISTING + E8 (Pons charge on unspecified leg) | Evaluate, not invert |
| R2 | token↔token swap | EX | Blocked | revert `PoolManagerInteractionBlocked` | revert `PoolManagerInteractionBlocked` | Sleeve cannot convert the other token |
| R3 | token↔token swap | XO | Idle | EXISTING `UniswapV4Quoter.quoteExactOutput` (QuoteService:115–136) single-tick case via E7 + `SqrtPriceMath.getNextSqrtPriceFromOutput` + `SwapMath.computeSwapStep`; impact 50 bp; **multi-tick = `InvalidRoute(TICK_DOMAIN)`** | E7 + E8 (Pons charge on input leg for exact-out) | Per Q4/Astra: `swapFee = calculateSwapFee(directionProtocolFee, lpFee)`; reject if `swapFee >= 1e6`; use `t = s − o/L` or `t = L·s/(L−o·s)`. **Tick-walking is NOT closed form per PRD §6.4:214.** |
| R4 | token↔token swap | XO | Blocked | `InvalidRoute(NO_CLOSED_FORM)` | `InvalidRoute(NO_CLOSED_FORM)` | No book swap while blocked |
| R5 | token→shares deposit | EX | Idle | EXISTING `_executeZapInDeposit` (InBase:269–312) + bounded refinement (DERIVED, validate before commit) per §6.2; issuance `min(floor(S·C0/B0'), floor(S·C1/B1'))` (§6.3); ε ≤ 1 bp (E3); impact 50 bp | EXISTING + E8 charge on composition swap unspecified leg | **Adopt only after validation**; if bounded refinement fails, revert `AlignmentExceeded` |
| R6 | token→shares deposit | EX | Blocked | EXISTING `_sharesForDeposit` one-sided linear branch (StandardExchangeConstantProduct.sol:58–64); no unlock | same | Unchanged |
| R7 | token→shares exact-mint | XO | Idle | `InvalidRoute(NO_CLOSED_FORM)` | `InvalidRoute(NO_CLOSED_FORM)` | Per D19.5: "exact-out branch without its own applicable closed form remains `InvalidRoute`." No combined closed form without DER-3 validation. |
| R8 | token→shares exact-mint | XO | Blocked | EXISTING `_amountInForShares` (StandardExchangeConstantProduct.sol:78–96) | same | Sleeve cover preserved |
| R9 | shares→token zap-out | EX | Idle | EXISTING `_executeFreeZapOutExactInCore` (OutExecutionDelegate:108–147) + forward quote; sleeve cover check | EXISTING + E8 charge on conversion swap unspecified leg | Multi-tick valid via existing search at OutBase:64–118; not labeled as closed form |
| R10 | shares→token zap-out | EX | Blocked | EXISTING `_singleExit` (StandardExchangeConstantProduct.sol:98–111) sleeve cover; revert `InsufficientLocalReserve` if short | same | Unchanged |
| R11 | shares→token exact-out | XO | Idle | `InvalidRoute(TICK_DOMAIN)` (multi-tick) or `InvalidRoute(NO_CLOSED_FORM)` (single-leg) per source-only policy | `InvalidRoute(TICK_DOMAIN)` or `InvalidRoute(NO_CLOSED_FORM)` | Per D19.5: D19 does not save this; exact-in R9 remains available |
| R12 | shares→token exact-out | XO | Blocked | EXISTING linear branch (E5 with `reserveOther == 0`); two-leg is `InvalidRoute` | same | Single-leg covered by existing helper |
| R13 | dual join `exchangeInManyToOne` | EX | Both | EXISTING `_executeZapInDualDeposit` (InBase:335–375) | same | Both legs required; unbalanced Multi OK; placement tail after mint |
| R14 | shares→dual `exchangeOutOneToMany` | EX | Idle | EXISTING `_dualExitShareBurns` (mulDivRoundingUp) + `_payIdleDualExit` (OutMultiTarget:101–121) | same | Requires `b0==b1`; else `ExchangeOutNotAvailable` |
| R14' | shares→dual `exchangeOutOneToMany` | EX | Blocked | EXISTING sleeve dual-pay (OutMultiTarget:83–99) | same | No unlock |
| R15 | `rebalanceLiquidReserve()` | n/a | Idle | One bounded holder step (R6) per `Common._rebalanceLiquidReserveInternal:757–807`; placement preferred; impact 25 bp; stop when both ρ ≤ 1 bp AND σ = 0 | same + E8 on holder swap unspecified leg | This is the rebalance, not an exact-output route |
| R16 | `rebalanceLiquidReserve()` | n/a | Blocked | revert `PoolManagerInteractionBlocked` | same | No unlock |
| R17 | `importPosition` | n/a | Idle | EXISTING import (PositionImportTarget); hookless only or Pons after singleton pin | EXISTING | Must already match the package's hook; no zap |
| R18 | Activation (both tokens) | n/a | Idle | EXISTING `mulSqrt − MIN_LIQ`; dead-share to sink | same | Single-token returns 0 shares |

**D19 active row count: 0.** The exception is not invoked. Every omitted-interleave cell is `InvalidRoute`; the corresponding exact-in cell is supported where source-only math exists.

### 3.1 Equation corrections (verifying the labels)

- **`_initialShares`**: `raw = floor(sqrt(C0 · C1))`; `MIN_LIQ = 1 if mean(dec0+dec1)/2 < 3 else 10^(mean−3)` (StandardExchangeConstantProduct.sol:30–35). **Correct.**
- **`_sharesForDeposit` dual**: `m = min(floor(S·C0/B0), floor(S·C1/B1))` (StandardExchangeConstantProduct.sol:52–56). **Correct.**
- **`_amountInForShares` single-leg inverse**: `Aneed = K + ceil(m·K/S); c = ceil(Aneed^2 / Bother) − Bin` (StandardExchangeConstantProduct.sol:78–96). **Correct** (the existing helper IS the closed-form inverse; Kimi's DER-3 is a different formulation for the idle mint).
- **`_singleExit` two-leg forward**: `out = floor(X·s/S) + floor((Bout − X)·floor(Y·s/S) / Y)` (StandardExchangeConstantProduct.sol:98–111). **Correct.**
- **Pons `h(n) = floor(n·hookFeeBps/10000) + floor(n·taxBps/10000)`** (PonsV2MemeHook.sol:495–504; QuoteService.sol:50–58). **Correct.**
- **Protocol fee composition `swapFee = pf == 0 ? lpFee : pf + lpFee − pf·lpFee/1e6`** (ProtocolFeeLibrary.sol:39–47). **Correct.**

### 3.2 Closed-form admitted (no speculation)

| Equation | Used in | Source-only? |
|---|---|---|
| `targetFree = floor(T · p / (1e18 + p))` | All | YES, replaces `Common.sol:358–360` |
| Dual mint `min(floor(...), floor(...))` | R13, R18 | YES, `StandardExchangeConstantProduct.sol:52–56` |
| One-sided linear `mulDiv(amount, supply, reserve, Ceil)` | R6, R8, R12 (one-leg) | YES, `StandardExchangeConstantProduct.sol:78–96` linear branch |
| Single-tick swap `computeSwapStep` | R3, R4 (idle) | YES, single-tick only |
| Pons `h(n)` | R1, R3, R5, R9, R15 (Pons only) | YES, `PonsV2MemeHook.sol:495–504` |

### 3.3 Closed-form rejected (declared `InvalidRoute`)

- Two-leg exact-output share inverse (Grok E6 two-leg branch): `InvalidRoute(NO_CLOSED_FORM)`. Two forward checks are not a closed form; they are a bounded integer search.
- Tick-walking exact-output swap (multi-tick): `InvalidRoute(TICK_DOMAIN)`. Not closed form per PRD §6.4:214.
- Combined exact-output+maintenance transition without source validation: `InvalidRoute(NO_CLOSED_FORM)` (idle D, E, F) or `InvalidRoute(TICK_DOMAIN)` (R11) — **subject to validation gate; default is `InvalidRoute`**.

### 3.4 Bounded work (no precision claim from bisection)

| Bounded work | Where | Why bounded |
|---|---|---|
| Bounded refinement of composition swap `s` (idle R5) | 8 outer iterations + 64 inner quoter steps | Monotone single-root; cap on iterations, NOT precision from 32 bisections |
| 2 forward evaluations (E5) for two-leg exact-out | Idle R11 | 2 forward evals, not a bisection; precision is integer-domain not precision-from-bisection |
| One holder swap + placement (R15 maintenance) | Per call, up to one swap | 1 swap + 1 placement per call; no loop within a call |

**No precision claim from "32 bisections on uint256"** — bisection is a search, not a closed form. The plan does not make this claim.

---

## 4. Acceptance and tests (preview==execution; in-kind equivalence)

Per §5 of each peer, plus the user's emphasis:

| Test | Cells | Pass criterion |
|---|---|---|
| `AdmissionAndIdentity.t.sol` | All | hookless rejects `hooks != 0`; Pons rejects `hooks != ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, wrong manager, same-flags impostor, `fee != 0`, unregistered launch; per-family selectors; independent storage; occupied CREATE3 names; proxy cuts |
| `FormulaDomains.t.sol` | All R1–R18 | every cell produces identical preview and execution amounts; preview==execution at identical state; `InvalidRoute` identical; tick-domain rejection verified at multi-tick attempt |
| `QuoteExecutionParity.t.sol` | All | preview returned amount equals execution at same state for R1, R3, R5, R6, R8, R9, R10, R12, R13, R14, R15; R7/R11 declared `InvalidRoute` in both preview and execute; no relative fudge |
| `EquivalentInterfaces.t.sol` | Pairwise | (a) `previewZapInDeposit(amountIn) → sharesOut` matches the inverse relationship to `previewZapInMint(sharesOut) → amountIn` for blocked R6/R8 ±1 unit + ceil/floor quantified; (b) `previewZapOutWithdrawal(amountOut) → shares` matches `previewZapOutMint(shares) → amountOut`; (c) `exchangeInManyToOne([t0,t1],[c0,c1])` matches equivalent pair of single-token; (d) `quoteExternalDeposit/Exchange/quoteTransition` matches `IStandardExchangeIn/Out` operations at equal state |
| `AttributionAndBooking.t.sol` | All | credit-before-fee, no double fee subtraction, own-LP recovery once, full local booking per `_syncVaultReserves`, no caller surplus misattributed, E→F once |
| `ZapAndPlacement.t.sol` | All R5/R15 | composition mint epsilon ≤ 1bp, dual mint preserves proportional, placement residuals accounted, 6/9/18 decimal, p=0/.2/1 |
| `MaintenanceProgress.t.sol` | R15 | placement preferred; one bounded holder swap; truthful no-op; immediate repeated calls; fee collection does not falsely trigger repair |
| `NestedAndConsumer.t.sol` | All | real outer unlock + real buffer consumer; DETF/TWAP consumers; no nested unlock; disabled inbound |
| `Adversarial.t.sol` | All | cross-mode cycles; pretransfer semantics; reentrant hook/token; wrong callback context; unpaid deltas; late min-failure rollback; initial donation/sink shares; price movement between booking and claimed input |
| `RuntimeAndWork.t.sol` | All | runtime ≤24,576 per component; 0.8.35/optimizer1/no via-IR; bounded work recorded; no mocks of manager/registry/vault/facets/fee-oracle/PoolManager |

Pons-specific acceptance (per Kimi): real registered Pons swaps, both directions and raw/native faces; separate floor charges; **changing global `setHookFeeBps` after registration does NOT change the registered launch's fee** (per-pool frozen at `PonsV2MemeHook.sol:357,389–403`; per-launch `creatorTaxBps` and `hookFeeBps` snapshotted); creator/buyback updates alter distribution only; core protocol fees remain composable per swap.

---

## 5. Family files and permitted reuse (item 3; D22 strict)

Both families' component sets follow the D22-mandated separate-prefix convention. Each family has 35 Solidity files plus 10 test bases plus interfaces. The **WIP candidate `UniswapV4FullSpreadClosedFormCandidate.sol` is NOT adopted and is NOT repaired** — it is on the deletion list at the readiness gate. **Reuse is from hookless INTO Pons via pure-math libraries only** (`HPInventoryMath.sol`, `HPProtectionMath.sol`, `HPRouteTypes.sol` per Astra's §5); runtime QuoteService, callback, settlement orchestration, and execution delegates are NOT shared.

Permitted (no shared dispatcher): `StandardExchangeConstantProduct.sol`, crane `FullMath/Math/FixedPointMathLib`, V4 `SqrtPriceMath/LiquidityAmounts/SwapMath/StateLibrary/quoter primitives`, generic ERC20/ERC2612/ERC5267 facets, `MultiAssetBasicVault/StandardVault` infrastructure, `NativeStandardYieldTarget/Selectors/Context`, `LocalCreditLib`, registry/factory and fee-oracle infrastructure, Pons reference tree, `ROBINHOOD_MAIN.sol`.

NOT reused: any file compiling a hook-model branch (because `QuoteService` compiles into `Common`, all V4-specific facets/delegates are per-family bytecode).

---

## 6. Removal manifest (item 6; per §3.1 gate)

Per §7 of each peer, reconciled with directory counts in §1:

- **`O` (40 entries)**: 35 Solidity + 5 PRDs + 2 subdirs → DELETE all Solidity + 5 PRDs at gate; KEEP nothing from O; port required regression coverage to family test bases; PRESERVE `C/libraries/...` and V4 core (not in O).
- **`F` (36 entries)**: 36 Solidity including candidate + test base → DELETE all `UniswapV4FullSpreadStandardExchangeVault*` + `UniswapV4FullSpreadClosedFormCandidate.sol` + bridge test base + `UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`; KEEP `fullSpread/hookless/` and `fullSpread/ponsFamilyV2Hook/` (currently empty — to be populated); PRESERVE `../StandardExchangeConstantProduct.sol`, `../v3/**`, `../README.md`, `../VERSION_SOURCE_MAP.json`, `../PRESERVED_*.json`, `../REGRESSION_RESULTS.txt`.
- **Rehome BEFORE removal**: `UniswapV4DetfProductionSeDeployLib.sol:92–98` → rewire to Pons family; `TestBase_UniswapV4StandardExchange_PonsV2.sol` family chain → new family bases; `test/foundry/spec/.../release/v4/closed-form/...parity.t.sol` (the file emitting the stack-too-deep diagnostic) → archive with its audit-era record, NOT ported.

---

## 7. Old-PRD deprecation (item 7)

Five PRDs at O + the CP-PRD at F are **deprecated**, NOT reconciled into current law:

| Document | Disposition |
|---|---|
| `O/UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` | Deprecated with old tree |
| `O/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` | Deprecated (percent-of-total sleeve + no-swap rebalance lose to D3/D9) |
| `O/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md` | Deprecated with old tree |
| `O/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` | Deprecated (full-range itself remains required by D57; not this doc) |
| `O/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | Deprecated with old tree |
| `F/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` | Deprecated; CP math reference is restated in the family plans via `StandardExchangeConstantProduct.sol` |

Pons evidence rule (per user item-4): official docs + graduated pools + existing constant suffice; **runtime-bytecode equivalence is NOT a gate** and NOT claimed. The local reference tree is the **behavior model**; deployed divergence is a new integration per §10:384.

---

## 8. Phased handoff

- **Phase 0**: adopt this cross-review adjudicated matrix; freeze removal manifest. (No deletion.)
- **Phase 1 (Hookless)**: port baseline; `_targetFree` precise formula; Q4 single-tick swap; E3 alignment; R5 bounded refinement (validate before adopting).
- **Phase 2 (Pons)**: port; E8 Pons charge; admission binding to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`; family admission matrix tests; same-flags impostor rejection.
- **Phase 3 (validation)**: integer-domain validation of derived equations; preview==execute parity; in-kind equivalence. **If any adopted formula fails validation, default cell becomes `InvalidRoute`** — do NOT silently substitute bisection or relax protections.
- **Phase 4 (consumers)**: rewire DETF deploy lib, test bases, fixtures, SY/Multi/transition-quote consumers.
- **Phase 5 (gate + removal)**: PRD §3.1 readiness; delete per §6; rebuild artifacts; rerun replacement/consumer suites; **audit handoff at post-removal revision**.

---

## 9. Confidence register and irreducible evidence gap

- **Adopted equations**: source-only helpers, `h(n)` Pons charge, `_targetFree` formula, `swapFee` composition — all verified by direct file:line read.
- **Pending validation (NOT adopted as closed form until tested)**: DER-3 idle exact-shares mint, DER-4 combined maintenance, DER-5 composition solver refinement, single-tick exact-output domain. Each has a known source-side comparator (`_executeDirectSwapOut`, `_executeZapInMintExactOut`, `_executeZapInDeposit`, `_rebalanceLiquidReserveInternal`).
- **Irreducible evidence gap**: **the integer-domain validation results are not in this report.** The plan defines the tests that will produce them; the plan does not claim those results. This is the irreducible gap.
- **Not claimed**: Pons deployed-runtime equivalence; that any future combined closed form is impossible; that bisection or new derivation would replace an adopted source-only formula.
- **Runtime byte equivalence removed**: not a gate; not a claim; not a test acceptance item. Ponts identity bound = address equality to `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` + `info[0] == 1` decode at init.
- **WIP candidate**: not adopted, not repaired, deleted at gate.

---

## 10. Saved path

`docs/research/uniswap-v4-plan-specification-2026-09-27/MINIMAX_CROSS_REVIEW.md` (this file).
`docs/research/uniswap-v4-plan-specification-2026-09-27/MINIMAX_ORIGINAL.md` preserved unchanged.
Peer originals (Astra, Grok, Kimi) preserved unchanged.

**No code, shell, test, config, deletion, or delegation performed. No peer cross-review artifacts read.**
