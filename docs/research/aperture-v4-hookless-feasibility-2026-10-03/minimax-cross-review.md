# MiniMax M3 — combined cross-review (Astra, Grok replacement, Kimi)

**Date:** 2026-10-03. **Round:** Aperture OptimalSwap + V4 hookless zap feasibility. **Read originals:** `astra-original.md`, `grok-replacement-original.md`, `kimi-original.md` as UNTRUSTED attributed model evidence. **No** peer cross-review/synthesis read. Originals preserved unchanged. No implementation, no delegation, no shell/test/deploy/config edits.

## 1. My original's polynomial-degree claim is wrong — the correct statement is quadratic

### 1.1 What I claimed

My original §2.3 asserted: "with `F_0 > 0` (the non-trivial sleeve case), the alignment equation is **degree 3 in x** and does not have a general closed-form algebraic solution (Abel-Ruffini)."

### 1.2 What I should have derived

Re-derivation on paper, verifying with the three originals' coefficients. Setup (continuous algebra, one tick segment, Q96-normalized real; `s` = current sqrt, `L` active pool liquidity, `l` vault-owned in-range liquidity, `f` total swap fee fraction, `γ = (1-f) · p_0`, `β' = L · p_0`):

```
After swap of x of token0 in (with net input = γx into L):
  p_T = p_0 · L / (L + γx)
  out_1 = β' · x / (L + γx) · 1/γ  (or equivalently β · γ · x / (L + γx) with β = L · p_0 / γ)

Caller basket:
  C_0 = c - x
  C_1 = β · γ · x / (L + γx)    (where β · γ = L · p_0 · (1-f) for dimensional check)

Incumbent post-swap (full-range core, F_0, F_1 sleeve, E_0,E_1 own-LP fees, "in-range" branch):
  D_0(x) = l · (1/p_T - 1/p_upper_vault) + F_0 + E_0(x)
          = l · ((L + γx)/(L · p_0) - 1/p_upper_vault) + F_0 + E_0(x)
          = (l · γ/(L · p_0)) · x + (l/p_0 - l/p_upper_vault) + F_0 + E_0(x)
  D_1(x) = l · (p_T - p_lower_vault) + F_1 + E_1(x)
          = l · (p_0 · L/(L + γx) - p_lower_vault) + F_1 + E_1(x)
          = (F_1 - l · p_lower_vault + E_1(x)) - (l · p_0 · γ/(L + γx)) · x
```

So `D_0` has a linear-in-x term plus a constant-plus-E_0(x); `D_1` has a constant-plus-E_1 minus a hyperbolic term in x (with x in the denominator through `1/(L+γx)`).

For the alignment `C_0 · B_1 = C_1 · B_0` (assuming B_0 leg binding), substitute and clear the `1/(L+γx)` denominator by multiplying through by `(L+γx)`. The remaining equation is:

```
α_const + α₁ · x + α₂ · x² = 0
```

i.e., **degree 2**. Adding sleeve `F_i` adds constants to coefficients. Adding own-LP-fee accrual `E_i(x)` where `E_0(x)` is `η · x + const` for linear fee-growth (or with denominator structure from boundary crossings) contributes linear-in-x (or degree-2 with denominator) terms that are still absorbed by the quadratic structure.

### 1.3 Where my error came from

I conflated `out_1`'s hyperbolic denominator with the incumbent `D_1`'s denominator, and mistakenly thought the cross-product introduced cubic terms. **Algebraically, multiplying both sides of `A · (L + γx) = B` (after the clear-denominator) collapses to a quadratic in x.** The denominators on both sides cancel to the same `(L+γx)²` because they share the same sqrt-price-decreasing structure.

I also wrongly invoked **Abel-Ruffini**. Abel-Ruffini says general degree-5+ polynomials are not solvable by radicals; degree 2 and 3 **are** solvable. So my "degree 3 + Abel-Ruffini" claim was internally inconsistent — even at degree 3, the cubic formula solves it. The right conclusion would have been: degree 3 solvable by cubic formula; degree 5+ higher (millions of LPs, 1 bp guards, multi-position with active-set changes) not solvable in general.

### 1.4 What the three originals correctly derive

- **Astra** §5: explicit coefficient set `(A·ℓ + L·U)·t² + (A·W − H·ℓ − Y·U + L·V)·t − (H·W + Y·V) = 0` for token0-in, and the symmetric form for token1-in. Quadratic preserved with `F`, `E`, `l`, `η = (ℓ/L)·(f−φ)`. **Correct.**
- **Grok replacement** §5: `(Q + ρβ)x² + (βB0 − cQ + P)x − cP = 0` with `P = B1·L`, `Q = B1·γ − ρβ`. Quadratic preserved. **Correct.**
- **Kimi** §4: "`A·t² + B·t + C = 0`, degree unchanged" with explicit `B0 = M·K + N_0`, `B_1 = β·l/L_K + A_1`. Quadratic preserved. **Correct.**

**All three other originals are right; my original is wrong.**

### 1.5 Restricted sufficient domain

Grok replacement §5 lists: "idle; both incumbent legs positive; price and next price strictly inside the vault position and inside the current initialized tick; `L>0`; fee below `1e6`; protocol fee either zero or folded into the coefficients with an explicit formula; no placement, or placement loss proved inside the 1 bp bound. I have not produced that integer proof." Kimi §4 adds: integer rounding; segmentation at boundary crossings; placement rounding; frozen conventions. Astra §5 names "one analytic candidate, and an exact forward/placement check satisfying all protections. Reject failure without probing."

**All three agree on the restricted sufficient domain** (idle; both legs positive; price strictly inside current initialized tick and inside the target range; L > 0; fee < 1e6; protocol fee folded in or zero; placement loss provably inside 1 bp bound). **All three agree on the integer-proof requirement.**

### 1.6 Continuous vs integer — distinction preserved

The continuous quadratic is a **candidate**. The integer proof requires (a) Q96 sqrt-price rounding; (b) `getAmount*Delta` round direction (V3's pool's favor); (c) own LP fee-growth flooring `floor(lpFee * 2^128 / L) * l / 2^128` (so `E_0(x) ≈ (ℓ/L)·f·x` is approximate, not exact); (d) prior-fee collection vs freeze-credit ordering; (e) placement rounding loss attribution (`HTransitionPlanner.sol:135–143` deducts from C or B, which is **outside** the polynomial); (f) cumulative vs snapshot E. **All three originals flag these; my original under-emphasized them.**

### 1.7 Multi-position/wings

Astra §5: "Multiple wings remain piecewise quadratic; they require more boundary/state bookkeeping, not automatically a higher polynomial degree." Kimi §4: "Out-of-range wings add position boundaries to the segmentation set, but an out-of-range wing's amounts are `t`-independent while uncrossed — wings simplify the solution (constant terms) until a boundary crossing, which then defines a new segment." Grok replacement §5: "does not cover wings, other LPs' ticks, or placement loss."

**All three agree: wings do not break the quadratic structure within an uncrossed-and-inactive segment.** Each wing contributes additively to incumbent `D_i` with `t`-independent terms (when out-of-range) or `1/t`/`t` terms (when in-range). Sum stays degree-2. **Wings increase the segmentation set**, not the polynomial degree.

## 2. Monotone vs binary search — Aperture is monotone, with two uncapped loops

### 2.1 What the three originals flag that I under-emphasized

Astra §3: "**New source-level caution:** dependency `nextInitializedTick` scans empty bitmap words until a nonzero masked word and explicitly assumes a next initialized tick exists. It has its own uncapped while-loop, in addition to `crossTicks`' uncapped do/while." 

Grok replacement §3: "There is no application-level step cap in this function."

Kimi §1: "**monotone final-segment discovery** ... work is naturally bounded by remaining budget and initialized-tick density — an uncapped loop whose iterations are economically bounded, which our work-bounded law would still need to cap explicitly."

**All three originals flag that Aperture has two uncapped loops** (the outer `crossTicks` `do { ... } while (true)` in `OptimalSwap.sol`, AND the inner `nextInitializedTick` `while (masked == 0)` in `uni-v3-lib/TickBitmap.sol:217` and `:228`). My original mentioned only one uncapped loop and didn't flag the bitmap inner-loop separately. **Correct in cross-review.**

For V4 hookless port: both loops must be explicitly capped (owner-approved constant). The prompt allows bounded traversal of an already-sized swap; "explicit" means a named cap, not an implicit budget bound.

## 3. Cross-review of Astra original

**Strong contributions:**
- Deepest source-trace; named exact dependencies and pinned Foundry config (`solc 0.8.26`, optimizer `4,294,967,295` runs, **via_ir=false**); **not local IndexedEx's 0.8.35/optimizer-1 baseline**. Important caveat I missed.
- Verified math dependency `@aperture_finance/uni-v3-lib v3.0.3` TickBitmap and SwapMath separately.
- **Explicit whole-book quadratic derivation including `l`, `F`, `E`, `η = (ℓ/L)·(f−φ)`**. Quadratic preserved with arbitrary incumbent. Correctly rejects my "degree 3" claim.
- Identified `nextInitializedTick`'s own uncapped while-loop (in addition to `crossTicks`' do/while). Two uncapped loops; my original under-mentioned.
- `Aperture's refund-all scratch-router pattern cannot be copied into persistent holder custody` — Aperture refunds; Hookless retains and books (PRD D8/D16). Important policy distinction.
- `HTransitionPlanner.sol:135–143` does placement loss attribution, **outside the quadratic**. Important caveat I missed.
- `_composition` does NOT remove `_maintenance`; "Do not append a searched repair and call the complete route analytic."
- `getLiquidityForAmounts` and a known-output `computeSwapStep` do **not** choose this `x`.
- `ProtocolFeeLibrary.calculateSwapFee = protocol+lp−floor(protocol*lp/1e6)`; `UniswapV4Quoter.sol:143–175,233–288` supplies core-compatible forward machinery but **not** the missing sizing rule.
- `nesting`/`AlreadyUnlocked` rule; Orbital calls Automan-style path inside its own unlock → reverts.
- License: Change Date **2026-07-01 passed**; Change License GPL-2.0-or-later; "no source-copy permission is inferred from this research."

**Disagreements:**
- Astra ranks: (1) Single-position port — most mature; (2) Whole-book one-segment analytic — strongest local next proof target; (3) Bounded whole-book segment walk — promising; (4) Orbital optimization — separate. **My original placed (1) and (2) at the same readiness level; Astra is right that (1) is more mature.**
- Astra's §6 sequence "Validate route/manager/hook, deadline, caller credit and minShares. Snapshot supply, complete incumbent D/F/E, liquidity/ticks, fee checkpoints..." mirrors Hookless's PRD plan but with **monotone-discovery under a bounded budget** rather than a 32-refinement loop. This is the right engineering translation.

**Dissent to record:** Astra's "no need to assume the sleeve is initially proportional" is correct: the quadratic works for any positive (or zero) `F_i`. My original's "F_0 = F_1 = 0 reduced to quadratic" was over-restrictive.

## 4. Cross-review of Grok replacement original

**Strong contributions:**
- **V3 → V4 amountSpecified sign inversion** explicitly called out: "V3 `_poolSwap` calls V3 `pool.swap` with **positive** `int256(amountIn)`... V4 `amountSpecified` is **negative** for exact input. A literal port inverts the swap." (Context7 `/uniswap/v4-core`.)
- Vendor gas claim explicitly flagged: "The NatSpec says gas is on the order of 10k and much less than binary search. That is vendor text. It is not a measurement from this repo."
- Explicit fee accrual as coefficient `η = (ℓ/L)·(f−φ)` (with protocol-fee split).
- `rho = l/L` simplification: "the position's own liquidity cancels out of the ratio condition. This is why it cannot, as written, see an incumbent vault position."
- Clearly states `mintOptimal` is two-token entry with caller-supplied ticks; `mintFromTokenIn` is the **separate** arbitrary-third-token interface. Correctly distinguishes them (which I conflated).
- Stronger license caution: "The text says the change license applies on the change date. This memo does not clear production use or a combined-work obligation. Do not copy the assembly. A clean-room port of the published idea still needs counsel."
- Outer loops: `_faceForClaim` and `_invertBufferForEffective` need `quoteInputForExactShares` (a share inverse, not `getOptimalSwap`). `zapSplitWad` searches a three-leg residual — Aperture has no third leg. Exact-output scalar redemption stays the bisection in `StandardExchangeConstantProduct.sol:113–128`.
- "Automan's view and execution can diverge if the pool moves between them. Hookless requires same-state equality (D30)."

**Disagreements:**
- Grok replacement §5 claim "B'0 = B0 + ρ · x (linear in x)" is an **approximation**; with sleeve F_0 ≠ 0 and own-LP-fee accrual not purely linear, B_0 has additional structure. But the overall quadratic degree is preserved (Astra's and Kimi's derivations confirm).
- Grok replacement's "A different one-segment quadratic can be written" is **correct** but understated; the right phrasing is "the *same*-degree quadratic extends with these fields."

**Specific correction to record:** Grok replacement's B_0 approximation is a placeholder for the more general derivation; my original's "F_0 + ρ · x" was the same approximation and likewise inadequate. The full coefficient set is in Astra §5 and Kimi §4.

## 5. Cross-review of Kimi original

**Strong contributions:**
- Cleanest trace of the algorithm steps (5 sub-bullets in §1).
- Coefficients given in source-equivalent form (`:14–19`) matching what I observe in `OptimalSwap.sol` (and what Astra derives).
- "L in the coefficients is the pool's active liquidity (impact), not the position's own liquidity — the position's own liquidity cancels out of the ratio condition."
- **Restricted domain detail**: "Sufficient domain, if a later proof is written: idle; both incumbent legs positive; price and next price strictly inside the vault position and inside the current initialized tick; `L>0`; fee below `1e6`; protocol fee either zero or folded into the coefficients with an explicit formula; no placement, or placement loss proved inside the 1 bp bound. I have not produced that integer proof."
- Verification of the rounding behaviour: "The boundary-step helper uses rounded-up gross input. This is **an analytic sizing implementation with rounding**, not a source-established universal exact-integer optimality theorem."
- Zero-L gap caveat: "I did not find a zero-liquidity special case that solves the quadratic; a zero `liquidity` in the coefficient divisions is an untested edge here." (Grok replacement)
- No-deployed-counterexample-mechanism statement: "No official hookless V4 OptimalSwap port located — evidence of absence in searched official sources, not a nonexistence proof."
- Fees-on-ownership: protocol fee goes to `feeTo`, own LP fee to incumbent, "once" per swap.
- **Outer-loop status**: "`zapSplitWad` is Orbital's sphere-residual split — untouched. Exact-output scalar redemption stays `InvalidRoute` beyond linear domains, as today."

**Disagreements:**
- Kimi's "Restated ranking" §8 ranks: (a) reusable now: monotone-discovery + quadratic pattern + whole-book coefficients; (b) port work; (c) research/liveness proof; (d) human decisions. **My original's ranking is broadly compatible but less specific about the integer-proof requirement.**
- Kimi's §6 autonomous-call sequence is the most explicit ("Validate...; Freeze credit; read slot0/L/fee/bitmap; certificate or capped discovery ≤ constant; solve quadratic; verify candidate (root-in-segment, max(P'/P,P/P')−1 ≤ 50 bp, funding, 1 bp inequality on exact integers); execute; book; preview == execution"). **This is the engineering blueprint.**

**Specific correction to record:** Kimi explicitly notes "Aperture's pool swap uses that global limit. The 50 bp check would have to be added around the result." — i.e., the sqrt-price-limit-min/max check is *not* a 50 bp protection; the 50 bp protection must be added by Hookless layer around the candidate. My original didn't emphasize this distinction.

## 6. Other key audit dimensions the prompt requested

### 6.1 Continuity / monotonic root-bracketing across segments

Astra §5: "The scalar comparison is continuously monotone before placement: spending input reduces caller input and increases caller output; incumbent input increases from principal conversion/own fees while incumbent output decreases. Hence `C_in·B_out − C_out·B_in` moves toward/through zero on a funded positive book. This supports a **whole-book boundary walk**."

This is the right framing: the alignment function `(c-x)·B_1(x) − C_1·B_0(x)` is monotone in `x` over each constant-L segment (the "direction-flip" check is exactly this monotonicity). The boundary-walk is monotone; the quadratic is a closed-form solution within a constant-L segment. **All three originals agree.**

### 6.2 Degenerate coefficients

Astra §4: "If a quadratic term is zero, solve the linear degeneration; if all vanish, classify the actual economic domain instead of dividing by zero." Grok replacement §3: "The assembly reverts `Math_Overflow` if a coefficient has the wrong sign... A zero `liquidity` in the coefficient divisions is an untested edge here."

Aperture's `Math_Overflow` (`:45`) reverts when `a` is not strictly greater than `amount0Desired`. This means the assembly detects coefficient sign failure. **For Hookless**, we need the same explicit zero-coefficient detection in the inner quadratic solve and an explicit `MathDomain` revert path, not a silent reversion.

### 6.3 Multi-position fixed active set

Astra §5: "The vault may own multiple positions, but no active set changes inside this segment. Inactive positions have constant amounts; active positions aggregate as `D0(t)=d0+ℓ/t, D1(t)=d1+ℓ*t`." Kimi §4: "Out-of-range wings add position boundaries to the segmentation set..."

Each in-range active position adds its `ℓ/t` (for D_0) or `ℓ·t` (for D_1) to incumbent. With multiple in-range positions, `D_0 = Σ_k ℓ_k/t` and `D_1 = Σ_k ℓ_k · t`. Both have the same `1/t` and `t` structure. **Sum stays degree-2.**

With active-set changes (position crossed during the swap), each crossing is a new segment. **Multi-segment piecewise quadratic.** Each segment is closed form; the walk is bounded by V4 tick bitmap; total work is bounded by the swap's price range.

### 6.4 Integer certificate vs liveness

Kimi §4: "Liveness (how often a passing integer exists when the candidate fails) is an empirical gate, unquantified here. Grok's round-1 objection (a failing check doesn't prove no nearby integer passes) limits *completeness claims*, not the legality of the policy."

Astra §5: "A credible first domain is one positive-liquidity core swap step, fixed owned-active set, f<1, certified representability, one analytic candidate, and an exact forward/placement check satisfying all protections. Reject failure without probing. This certifies successful calls but does not prove sufficient acceptance coverage."

All three agree: **integer certificate (root, root+1, root−1 wei variants; exact forward/placement check; 1 bp inequality; 50 bp impact; 10 bp shortfall; place/mint step) is a reject policy, not a probe sequence.** Accepting one candidate per call is search-free at the algorithm level. **Liveness** (how often the policy accepts vs reverts) is an empirical gate, not an analytical claim.

### 6.5 Bitmap-word stepping and source fee floors

Astra §3 (already cited): `nextInitializedTick` in `uni-v3-lib/TickBitmap.sol` has its own uncapped while-loop. **Two uncapped loops in the V3 source.** Both must be explicitly capped for V4 hookless.

Kimi §1: "work is naturally bounded by remaining budget and initialized-tick density — an uncapped loop whose iterations are economically bounded, which our work-bounded law would still need to cap explicitly."

For V4 hookless port: `StateLibrary.getTickBitmap(manager, poolId, wordPos)` (Crane V4 wraps `extsload`) is the V4 equivalent. The cap must be a named constant.

Aperture's source fee floors: `feePips` is a uint24; `MAX_FEE_PIPS = 1e6`; `fee` must be strictly less than 1e6 (`OptimalSwap.sol:62`). For V4: `ProtocolFeeLibrary.calculateSwapFee(protocolFee, lpFee)` returns uint24 with implicit rounding `protocolFee + lpFee − floor(protocolFee * lpFee / 1e6)` (Crane `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol`). V4 fees include LP + protocol; Aperture's V3 only includes LP. **For V4 hookless, the quadratic must use the combined fee (Astra's `η = (ℓ/L)·(f−φ)` already accounts for this).**

### 6.6 Actual single-token mintOptimal empty swapData vs unrelated-token mintFromTokenIn

Astra §3: "For one pool token, call `Automan.mintOptimal` with the other desired amount zero... With **empty swapData**, `_optimalSwapWithPool` calls `OptimalSwap.getOptimalSwap` on-chain."

Grok replacement §2: "`mintOptimal` pulls `amount0Desired` and `amount1Desired` from the caller. Either may be zero, so a one-token mint is a call with one desired amount set to zero and ticks supplied... `mintFromTokenIn` is different and not a pure scalar: the caller must already split `tokenIn` into `amount0Desired` and `amount1Desired` before `_swapApproveNpm` converts those pieces and then runs the optimal pool swap."

Kimi §2: "`mintOptimal(params, swapData, token0FeeAmount, token1FeeAmount)`: pull both desired amounts (either may be 0 → **single-token entry is the native case**); ... `mintFromTokenIn` is a separate arbitrary-third-token interface."

All three agree: **`mintOptimal` is single-pool-token entry (one desired amount may be zero) using direct pool swap on-chain**; `mintFromTokenIn` is the arbitrary-third-token entry requiring `swapData0`/`swapData1` and a permit-holder router. **My original conflated these.** I will correct this in the cross-review.

### 6.7 Return numbers vs executed action plan

Kimi §1: "It is a **view returning numbers**; a separate layer executes."
Grok replacement §2: "The view `getOptimalSwap` returns numbers only. The money path both computes and executes. It does not hand Orbital a plan."
Astra §3: "The library returns **amountIn, predicted amountOut, direction, predicted final sqrt price**—not an encoded full settlement plan."

**All three agree: `getOptimalSwap` returns numbers, not an action plan.** For autonomous SE use, Hookless must call `getOptimalSwap` as a view, then execute its own swap + add via `_executePlanner.sol` (existing path). **My original was correct on this.**

### 6.8 V3/V4 amountSpecified signs

Grok replacement §2 + Kimi §3 + Context7 `/uniswap/v4-core`: **V3 `pool.swap` positive = exact input; V4 `pool.swap` negative = exact input.** Direct port inverts the sign. My original mentioned this but didn't emphasize it as a port footgun. **Will correct.**

### 6.9 Protocol fee even hookless

All three: V4 hookless pools still have `slot0.protocolFee` (separate from LP fee). The combined fee is `protocol + lp − floor(protocol·lp/1e6)`. Quadratic uses combined fee. Astra's `η = (ℓ/L)·(f − φ)` correctly excludes the protocol fraction from own-LP accrual.

### 6.10 Target range user input

All three: Aperture does **not** discover the target range. Caller supplies `tickLower`, `tickUpper`. Range selection is outside the solver.

### 6.11 Unlocked view vs forbidden nested execution

Astra §7: "When PoolManager is already unlocked, the current law permits only local sleeve settlement; Aperture cannot open a nested unlock or manufacture spendable opposite currency."

Grok replacement §6: "While the manager is unlocked, Aperture cannot open a V3-style pool swap or a V4 `unlock`. `AlreadyUnlocked` is the V4 rule."

Kimi §5: "Inside Orbital's hook callback on the same manager, the zap path is unreachable; blocked-state stays sleeve-only F1/F2."

**All three agree: view-before-unlock is fine; execution-inside-Orbital's-callback is forbidden by `AlreadyUnlocked`.** For Orbital's autonomous flow: precompute `getOptimalSwap` outside unlock; execute via Orbital's own `unlockCallback` which calls `manager.swap` + `manager.modifyLiquidity` directly. **My original was correct on this.**

### 6.12 Vendor audit / gas claims / license no-copy overstatement

Astra §8: "Pinned LICENSE remains a BUSL-1.1 document with **2026-07-01** change date and **GPL-2.0-or-later** change license. That date has passed; review applicability and combined/dependency obligations rather than declaring MIT or a perpetual production ban. Read math dependencies carry GPL-2.0-or-later headers. No source-copy permission is inferred from this research."

Grok replacement §7: "The text says the change license applies on the change date. This memo does not clear production use or a combined-work obligation. Do not copy the assembly."

Kimi §7: "GPL is copyleft: **no source porting into our tree**; the math may be reimplemented from the equations."

Vendor gas: Grok §3 and Kimi §1 both flag "NatSpec says gas is on the order of 10k... that is vendor text. It is not a measurement from this repo." **My original did not flag the vendor gas claim.** Will correct.

Vendor audit: All three agree Narya.ai audit at commit `2a8975e9` (May 8, 2023) is post-audit-commit and does not pin the current pinned commit. **My original was correct.**

## 7. Final feasibility answer (corrected)

### 7.1 (1) One V4 hookless position — port work, **conditionally yes**

The continuous math (Aperture's quadratic per constant-L segment, with optional LP+protocol fee combined via `η = (ℓ/L)·(f−φ)`) is V3/V4-identical in the relevant respects. **The port is well-defined:** V3 → V4 sign inversion (positive → negative `amountSpecified`); V3 NFT → V4 salted position; V3 LP-only fee → V4 combined LP+protocol fee; V3 callback → V4 `unlockCallback` + `BalanceDelta` settlement; V3 WETH9 → V4 native ETH; bitmap via `StateLibrary.getTickBitmap`. **Two uncapped loops in the V3 source must be explicitly capped in the V4 port** (owner-approved constant per the prior-round guard rails). Owner must approve the discovery-vs-reject policy.

### 7.2 (2) Existing fungible Hookless vault — accounting research, **conditionally yes, with corrected polynomial degree**

The whole-book alignment equation `(c-x)·B_1(x) = out_1·B_0(x)` with arbitrary `F_i`, `E_i`, vault-owned active `ℓ`, and own-LP-fee accrual (linearized as `(ℓ/L)·(f−φ)·x`) is **quadratic in x** (degree 2), not cubic as I previously claimed. All three other originals derive and verify the quadratic. **My original's polynomial-degree claim is wrong** and my Abel-Ruffini invocation was internally inconsistent. The complications are integer rounding (Q96 sqrt-price; `getAmount*Delta` floor; fee-growth flooring), segmentation at boundary crossings, placement rounding loss attribution (outside the polynomial), and frozen conventions — but **the algebraic structure is preserved as quadratic**.

**Restricted sufficient domain** (where the integer proof is required but tractable): idle; both incumbent legs positive; price strictly inside vault position and inside current initialized tick; L > 0; combined fee < 1e6; protocol fee folded into combined fee; no placement or placement loss provably inside 1 bp bound.

### 7.3 (3) Autonomous Orbital/SY nesting — **No** from Aperture alone

Aperture's `_poolSwap` calls `IUniswapV3Pool.swap` directly (V3) or `manager.swap` inside `manager.unlock` (V4 port). **Nested unlock reverts `AlreadyUnlocked`.** Orbital's hook callback cannot call Aperture's swap path inside Orbital's own unlock. Aperture exposes `getOptimalSwap` as a `view` function callable outside unlock; Orbital must execute via its own `manager.swap` + `manager.modifyLiquidity` inside Orbital's `unlockCallback`. This is "Orbital precomputing via Aperture's view function," not "Aperture discovering a V4 hookless zap."

Aperture mints NFTs; there is no fungible SE share (`S`) logic, no min-ratio mint, no share inverse. Orbital's `_faceForClaim`, `_invertBufferForEffective`, `zapSplitWad` remain — **Aperture's quadratic solves a different problem (exact-input swap sizing for one position)** from what Orbital needs (exact-share inverse for fungible shares; sphere-residual balancer).

## 8. Unresolved proof gates (must be closed before implementation)

1. **One integer counterexample** of the whole-book quadratic vs the existing 32-refinement `Planner._composition` (`TransitionPlanner.sol:73–108`) at randomized states with seeded input. Match-or-explain every divergence.
2. **Liveness measurement** of the reject policy: how often does a passing integer exist when the candidate fails? Unquantified in any of the four originals.
3. **Segment-certificate correctness** at bitmap-word boundaries and tick initializations. **Two uncapped loops** in the V3 source (`crossTicks` + `nextInitializedTick`); explicit cap required for V4.
4. **Fee-growth flooring consistency**: own LP fee `floor(lpFee·2¹²⁸/L)·l/2¹²⁸` may not equal `(ℓ/L)·(f−φ)·x` exactly; verify cumulative vs snapshot accounting matches.
5. **Multi-position/wing coefficient cases**: at a tick crossing, the active set changes; verify the new segment's quadratic is solvable with the new active set.
6. **50 bp composition-impact check** on **price, not sqrt price** (PRD §9); Aperture's algorithm uses sqrt-price limits at the pool's extreme, which is **not** a 50 bp protection. Hookless layer adds the protection.
7. **Placement rounding** attribution: `TransitionPlanner.sol:135–143` deducts placement loss from C or B. Verify it does not invalidate the quadratic root.
8. **Manipulation cycle tests**: same-tx sandwich, donation attacks, precedent saturation, all-zero-incumbent degeneracies.
9. **Preview == execution** parity at same-state equality (PRD D30). Automan's view and execution can diverge if the pool moves between them.
10. **Pinned-state gas measurement** only afterward. Aperture's vendor gas claim is unverified.
11. **License counsel** before any source porting; the math is reusable from the equations but no source-copy permission is inferred.

## 9. Confidence and gaps

**High confidence:** Aperture algorithm description; polynomial degree is quadratic (corrected from my "degree 3" claim); V3→V4 boundary mapping; protocol fee integration; nested unlock trap; outer loops not removed by Aperture.

**Medium confidence:** integer parity proof (none of the four originals have produced one); exact optimality claim of the analytic candidate (vendor "closed form" wording, not a theorem); deployment pin (Etherscan mainnet per README not verified in this round); multi-position aggregate coefficient set in fully general form.

**Lower confidence:** current deployed Automan contract (Etherscan per README only); `uni-v3-lib` license (Astra notes SPDX GPL-2.0-or-later headers; full dependency tree not audited); whether Aperture's `getOptimalSwap` returns **provably exact-optimal** swap amount under all pool shapes (vendor assertion; tests confirm parity with router within `1e6` wei tolerance, not global optimality).

**Gaps (not retried)**: `test/uniswap/UniBase.sol`, `test/uniswap/UniHandler.sol`, `src/base/Callback.sol`, `package.json`, `.gitmodules`, `foundry.toml` deep content; `@aperture_finance/uni-v3-lib v3.0.3` license text; Aperture Etherscan mainnet contract bytecode. **No local missing-file failures; no guard events; no SDK unavailability.**

**Stop for human decision; no implementation authorized.** Originals preserved unchanged. Saved: `docs/research/aperture-v4-hookless-feasibility-2026-10-03/minimax-cross-review.md`. No consensus, no measured gas claim.