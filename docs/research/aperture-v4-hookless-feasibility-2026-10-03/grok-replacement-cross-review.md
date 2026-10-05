# Grok replacement cross-review — Aperture feasibility

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Review of the three other Aperture originals. Not continuity with the replaced Grok, not consensus, and not a gas claim. Pin remains `c40aaa98cf49baf454fbb7a8ee6709862e27038e`.

## 1. Corrections to my original

I described `crossTicks` and missed a second loop. Aperture's `TickBitmap.nextInitializedTick` (`uni-v3-lib` v3.0.3, GPL-2.0-or-later header) does `while (masked == 0) tickBitmap(++wordPos)`. It jumps empty bitmap words and returns the next initialized tick. Core swap execution uses within-one-word steps and stops at an uninitialized word edge. Fee gross-up is per step. A port that must match V4 `SwapMath` cannot treat Aperture's walk as the same partition. Astra flagged this. I had not.

I also treated the whole-book quadratic as only my derivation. Astra and Kimi reach the same degree. Their coefficient sets differ. The degree claim is the shared result. The exact own-fee coefficient is not.

## 2. Polynomial degree

**MiniMax is wrong that `F>0` makes the alignment cubic, and wrong that a cubic has no radical solution.**

Within one constant-`L` segment, net input and output are fractional-linear in gross input `x`. Incumbent `D` is fractional-linear in the next sqrt price, hence fractional-linear in `x`. A sleeve `F` and a pre-swap `E` are constants. Own LP fee, if proportional to gross input, is linear in `x` and folds into `B_in' = B_in + η x`. Alignment `(c-x)*B_out'(x) = y(x)*B_in'(x)` has one linear denominator. Clearing it leaves a quadratic. I re-expanded this. Astra's cleared forms and Kimi's `{t, 1/t, const}` basis say the same thing.

MiniMax's "x³ after clearing" counts an uncleared `1/p_T` as an extra degree. Abel-Ruffini does not apply to degree 3 or 4. Those have radical solutions. The theorem starts at the general quintic. It is not a reason this equation lacks a closed form.

`E(x)` does not become degree 4 in the continuous one-segment model. Fee growth on the input token is linear in the fee amount. Protocol fee changes `η`. It does not add a new power of `x` while `L` and `ρ=l/L` are fixed.

**Protocol fee, hookless included.** Crane `ProtocolFeeLibrary.sol:35-46` sets the swap fee to `protocol + lp - floor(protocol*lp/1e6)`. The NatSpec says "rounded up"; the assembly floors the product term. MiniMax's `(1e6-lp)*(1e6-proto)/1e6` is not that integer formula. Zero hooks do not zero the protocol fee. V3 "protocol fee is zero on mainnet" is not a source finding and is irrelevant to V4.

**Own-fee coefficient.** Astra's `η=(ℓ/L)*(f-φ)` times gross input has the right shape if `φ` is the protocol portion of the fee. Kimi's `f*l*(1/t-1/s)` equals `f*(l/L)*net`, but if `l=L` and protocol fee is zero the position receives `gross-net = net*f/(1-f)`. That coefficient is short by `1/(1-f)`. Degree is unchanged. Integer fee growth is two floors: `floor(lpFee * 2^128 / L)` then `floor(growth * l / 2^128)`. `η*x` is not that predicate.

**Multi-position.** Inside a segment that crosses no position boundary, in-range liquidities add to one `ℓ`. Out-of-range wings are constant until their boundary. That stays quadratic per piece. MiniMax's "degree 5+ for one core and one wing" is not shown. A wing boundary starts a new piece. It does not raise the degree of the piece.

**Degenerate coefficients.** If the `t²` term is zero, the equation is linear. If every coefficient vanishes, do not divide. Astra states this. A solver that always does `(B+sqrt(B²+4AC))/(2A)` is unsafe at those points.

**Monotonicity.** Continuously, spending more input moves `C_in*B_out - C_out*B_in` toward zero on a positive book. That supports stopping a walk when the sign would flip, and not committing the overshooting step. `crossTicks` does break before applying that step. Integer fee floors can flatten a step. Monotonicity of the integer predicate is not proved. A sign bracket is a reason to solve the segment, not a proof every integer root is unique.

## 3. What the code actually executes

**Agree with Astra and Kimi.** `mintOptimal` with one desired amount zero and empty `swapData` is the single-pool-token path. `_optimalSwapWithPool` calls `getOptimalSwap`, then `_poolSwap` with positive V3 `amountSpecified`, then the NFT manager mints and refunds surplus. The view returns numbers. The money path executes them. Ticks are caller input.

**MiniMax is wrong** that `mintFromTokenIn` is the only scalar entry and that empty `swapData` cannot size a one-token mint. `mintFromTokenIn` is a third-token flow. The caller still splits `tokenIn` into two desired amounts. Empty `swapData` there uses `_poolSwap`, but the split is not discovered. Do not conflate the two functions.

`getOptimalSwap` is `view`, not `pure`. V4 exact input is negative `amountSpecified` (Context7 `/uniswap/v4-core`, accessed 2026-10-03). Aperture passes a positive amount. MiniMax's port table omits that sign flip.

Below the range, only token0 is required and `isZeroForOne` returns false. MiniMax's comment that this case "needs only token1" reverses the source.

The pool swap limit is the global min or max sqrt price, not a 50 bp bound. Vendor gas text and the Narya report at commit `2a8975e9` are not measurements of pin `c40aaa98`. Upstream fuzz tolerances are not the 1 bp share test.

## 4. Bitmap and fee floors

`nextInitializedTick` assumes a next initialized tick exists and skips empty words. Core and Crane quoters step to the word boundary even when that boundary is uninitialized. Aperture's simulated fee can therefore differ from execution of the same input. A V4 port that checks `SwapMath` must either reproduce word-boundary steps or accept a quote/execution gap. Bounding only initialized crossings does not close it. Negative ticks are compressed toward negative infinity in `compress`, which matches Uniswap's rule. That part of Astra's reading is confirmed.

## 5. Agreement and dissent

**Astra.** Agree on the three loop types, the uncommitted terminal segment, the quadratic degree with `F`/`E`/`η`, placement loss outside the polynomial, and no drop-in V4 executor. The bitmap caution is now source-checked. I do not treat the continuous quadratic as an integer certificate. Astra's proposed 64-step walk is a product choice, not a proved bound.

**Kimi.** Agree that `mintOptimal` with a zero leg is the scalar case, that the whole-book basis stays degree 2, and that a failing 1 bp check is a reject rather than a search. The own-fee coefficient needs the `1/(1-f)` correction above. GPL does not mean "no port." After the stated change date the license text points to GPL-2.0-or-later, which is copyleft, not a ban. Counsel still required. Do not copy the assembly.

**MiniMax.** Agree that Aperture does not remove the three Orbital loops, that nested `unlock` reverts, and that the V3 contract does not call V4. Dissent on degree 3, Abel-Ruffini, `E` raising degree to 4, multi-position degree 5, MIT/`OptimalSwap` licensing, `mintFromTokenIn` as the only scalar path, and precomputing the V3 view before an unlock as same-state V4 parity. That view reads a V3 pool. A stale preview is not D30 equality.

## 6. Final feasibility

**One V4 hookless position.** Conditional port, not existing code. Ticks must be supplied. Empty swap data can size and execute only after V4 settlement, negative exact-input, protocol-fee pips, salt, and either a core-compatible step walk or a single-segment reject. No official hookless V4 OptimalSwap was verified. Absence of evidence is not nonexistence.

**Whole-book vault.** Aperture's equation does not apply. A different one-segment equation is quadratic in the continuous model, including sleeve, prior fees, finite-range offsets, and a proportional own-LP fee. Integer fee floors, word-boundary steps, placement loss, and the 1 bp test are outside that polynomial. Candidate plus one exact forward check is a reject policy. It does not prove a nearby integer would fail, and it does not prove one would pass. Multi-position stays piecewise quadratic until a boundary. No general integer certificate is established.

**Orbital.** No. Wrong interface, NFT custody, no share inverse, and no nested unlock. Analytic deposit sizing does not replace `_faceForClaim`, `_invertBufferForEffective`, or `zapSplitWad`. Unlocked calls stay on local cover.

## 7. Proof gates still open

1. Expand both directions with Crane's exact swap-fee formula and the two fee-growth floors. Show the integer residual, or a counterexample, against `SwapMath`.
2. Compare Aperture's initialized-tick walk with a word-boundary walk on the same input. Record any amount difference.
3. One-segment certificate: root inside the segment, no sign flip, 50 bp on price, 10 bp shortfall, 1 bp after placement. Failure reverts once.
4. Degenerate `A=0` and `L=0` cases classified, not divided.
5. Same-state preview equals execution. A view taken before `unlock` is not that test.
6. License review of the pinned BUSL text, the 2026-07-01 change date, and GPL-2.0-or-later headers in `uni-v3-lib`. No copy from this review.

**Stop. No implementation is authorized.**
