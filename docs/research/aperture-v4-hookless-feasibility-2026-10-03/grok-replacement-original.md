# Grok replacement original: Aperture OptimalSwap and V4 hookless zap feasibility

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Independent first pass. No peer artifacts read. Not consensus. No implementation and no local gas claim. Pin: `Aperture-Finance/uniswap-v3-automan` commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`. `main` is not a deployment pin.

## 1. Plain answer

Aperture sizes and then executes a zap for **one Uniswap V3 NFT position** whose ticks the caller already chose. Empty `swapData` does that on-chain: it reads the live pool, walks ticks until the optimal direction would reverse, solves a quadratic on the last segment, swaps that exact input, and mints or increases the NFT. It does not discover the range.

It does **not** discover or execute a Uniswap V4 hookless zap. No verified official V4 OptimalSwap was found. `Aperture-Finance/uniswap-v4-hooks` is a design note, not this solver. `Aperture-Finance/v4-core` is a Uniswap core fork, not Automan.

| Question | Answer |
|---|---|
| One V4 hookless position, ticks already chosen, manager idle, one certified segment | Conditional port. The continuous last-segment idea can be reimplemented. The V3 contract does not call V4. Tick discovery remains unless the owner accepts a single-segment reject. |
| This fungible vault's whole book | No, not by using Aperture's equation. A different one-segment quadratic can be written. It is not an integer proof and does not cover wings, other LPs' ticks, or placement loss. |
| Autonomous Orbital / SY | No. Wrong surface, no fungible shares, cannot run inside an existing unlock, and it does not remove `_faceForClaim`, `_invertBufferForEffective`, or `zapSplitWad`. |

## 2. How the V3 money path works

Pinned files, fetched 2026-10-03: `src/libraries/OptimalSwap.sol`, `src/base/SwapRouter.sol`, `src/base/Automan.sol`. All three headers are `BUSL-1.1`. Automan and SwapRouter are `pragma ^0.8.18`. OptimalSwap is `>=0.8.8`.

`mintOptimal` pulls `amount0Desired` and `amount1Desired` from the caller. Either may be zero, so a one-token mint is a call with one desired amount set to zero and ticks supplied. It deducts caller-supplied Aperture fee amounts, capped by `feeConfig.feeLimitPips`. It then calls `_optimalSwap`. If `swapData` is empty, `_optimalSwapWithPool` calls `OptimalSwap.getOptimalSwap` and `_poolSwap`. If `swapData` is nonempty, an allowlisted router executes caller calldata, and the helper still runs `getOptimalSwap` on the post-router balances and swaps the pool again. The view `getOptimalSwap` returns numbers only. The money path both computes and executes. It does not hand Orbital a plan.

`_poolSwap` calls V3 `pool.swap` with **positive** `int256(amountIn)` and a sqrt limit of `MIN_SQRT_RATIO+1` or `MAX_SQRT_RATIO-1`. In V3 that positive value is exact input. Context7 `/uniswap/v4-core`, accessed 2026-10-03: V4 `amountSpecified` is **negative** for exact input. A literal port inverts the swap.

After the swap, Automan approves the V3 position manager and mints. Surplus desired amounts are refunded to the recipient. The NFT owner receives the position. There is no vault share, no sleeve, and no incumbent book.

`increaseLiquidityOptimal` is the same pattern for an existing NFT. `mintFromTokenIn` is different and not a pure scalar: the caller must already split `tokenIn` into `amount0Desired` and `amount1Desired` before `_swapApproveNpm` converts those pieces and then runs the optimal pool swap. That split is caller-supplied.

Zap-out `decreaseLiquidity` collects the position and, if `tokenOut` is set and `swapData` is empty, exact-input swaps the **entire** collected other balance. It checks `tokenOutMin` and refunds leftovers. That is a sized full conversion, not an exact-output inverse and not a search for a share amount.

Range selection is outside the solver. `rebalance` takes new ticks from the caller. Controllers may be set by the owner. Empty swap data does not mean an off-chain keeper chose `x`. It does mean someone chose the ticks.

## 3. The algorithm, and what kind of loop it is

`getOptimalSwap` reads pool code size, current sqrt price and tick, in-range liquidity, fee, and tick spacing. It does not receive active liquidity as an argument. `isZeroForOne` handles the out-of-range cases: price at or below the lower bound needs only token0, so the swap direction that buys token0 is false; price at or above the upper bound needs only token1. Inside the range it compares the desired amounts with the position's marginal token ratio.

`crossTicks` is `do { ... } while (true)`. Each pass asks the tick bitmap for the next initialized tick, simulates an exact-input step to that tick, and stops if the input is exhausted before the tick or if `isZeroForOne` would flip. Otherwise it applies `liquidityNet` and continues. There is no application-level step cap in this function. That is monotone discovery of the terminal segment. It is not binary search over candidate amounts. It is also not execution traversal of an already-sized swap: the amount is not known until the walk ends and the quadratic runs.

On the last segment, `solveOptimalZeroForOne` or `solveOptimalOneForZero` computes a sqrt price from a quadratic in Q96 assembly, then clamps it so the price does not move the wrong way. `amountIn` rebuilds the input from the crossed steps plus `getAmount*Delta` on the last gap, with fee complement `1e6 - feePips`. If the simulated price never re-enters the position, it consumes the entire input. Zero desired amounts return immediately. A zero-code pool reverts `Invalid_Pool`. The assembly reverts `Math_Overflow` if a coefficient has the wrong sign. I did not find a zero-liquidity special case that solves the quadratic; a zero `liquidity` in the coefficient divisions is an untested edge here.

The NatSpec says gas is on the order of 10k and much less than binary search. That is vendor text. It is not a measurement from this repo.

This is an analytic candidate plus rounding, not an exact optimality theorem for integer V3. The last-step price is clamped. Fee and amount deltas are rounded in the pool's favor. The function returns the amount the approximation implies. The subsequent real swap can differ if liquidity or price moves, or if the walk's simulated liquidityNet does not match execution.

## 4. One V4 hookless position

**Conditional, after a port. Not a yes for the existing bytecode.**

Zero hooks remove hook-returned deltas and dynamic fee overrides. They do not remove protocol fee, the live LP fee, the singleton manager, delta settlement, native currency, or salt. V4 `modifyLiquidity` returns `callerDelta` that already includes fees, and a separate `feesAccrued` (Context7, same access). Aperture collects V3 tokens owed through the NFT manager. Those are different settlement paths.

A port of the last-segment math is plausible when all of the following hold: hooks are `address(0)`; the caller has already chosen ticks; the manager is idle so one `unlock` is legal; fee pips are `calculateSwapFee(protocolFee, lpFee)` and below `1e6`; the computed next price stays strictly inside the current initialized tick and inside the position; active liquidity is nonzero; the swap uses negative `amountSpecified`. Then one `SwapMath.computeSwapStep` can check the candidate. If the price would hit the next initialized tick, the V3 code walks. A hookless port that wants strict no-discovery must reject that case instead of looping. The human has not approved unlimited traversal. A bounded walk with an explicit step cap would be a named product choice, not a silent copy of `while (true)`.

Position identity must include salt. Crane's current Hookless vault stores one center salt (`PositionRepo.sol:130-135`). A second position needs another salt. Native currency must be wrapped or settled as the native face. None of that is in Automan.

## 5. Whole-book alignment is a different quadratic

Aperture's target is: after the swap, the tokens in hand match the ratio required to add liquidity to **this** range at the new price. Incumbent free inventory, uncollected fees, and an existing position's principal are not variables. Refunding the leftover is correct for an NFT zap. It is the wrong residual law for this vault, which must book the whole contribution.

Hookless wants, for credit `c` of token0:

```text
C = (c - x, y(x))
B'i = D_i(t) + F_i + E_i(t)     // credit excluded
(c - x) / B'0 = y / B'1
m = min_i floor(S * C_i / B'i)
```

Own LP fee and the position's repricing stay in `B'`, not in `C`.

**Continuous derivation, one segment, not an integer proof.** Let `s` be the current sqrt price, `L` active liquidity, `l` the vault's in-range liquidity, `ρ = l/L`, `g = 1 - φ` the fee complement, protocol fee zero, and `F` and pre-swap `E` constant. For token0 in:

```text
y = L * g * x * s^2 / (L + g * x * s)
B'0 = B0 + ρ * x
B'1 = B1 - ρ * y
```

The second line holds only if principal taken by the position plus own LP fee equals `ρ` times gross input. That is true in the continuous model with no protocol fee. It is false once protocol fee takes a cut, fee growth is floored twice, or `getAmount*Delta(l)` is not exactly `ρ` times the swap net.

Clear `(c-x)*(B1-ρ y) = y*(B0+ρ x)` with `y = β x / (L + γ x)`, `β = L*g*s^2`, `γ = g*s`. Multiply through by the denominator. The result is quadratic in `x`:

```text
(Q + ρ β) x^2 + (β B0 - c Q + P) x - c P = 0
P = B1 * L
Q = B1 * γ - ρ β
```

Token1-in is the same degree: sqrt price moves linearly with net input, and token0 out is hyperbolic. This is **not** Aperture's coefficient set. Aperture's `a`, `b`, `c` are built from `amount0Desired`, `amount1Desired`, `liquidity`, and the position's sqrt bounds (`solveOptimalZeroForOne`). They do not contain `S`, `F`, `E`, or `ρ`.

**Where the quadratic stops.** Another LP's initialized tick changes `L`. The vault's own range boundary changes `l` and whether `ρ` applies. A wing that is out of range does not move until price enters it; `D` is then a sum of piecewise positions, not one `ρ`. Placement after the swap subtracts rounding from `C` or `B` (`TransitionPlanner.sol:135-143`). That loss is outside the polynomial. The accepted test is the 1 bp inequality `10000*m*B_i >= 9999*S*C_i`, not a continuous root. A root that fails that integer test is a reject, not a nearby search, unless the owner later allows one.

Sufficient domain, if a later proof is written: idle; both incumbent legs positive; price and next price strictly inside the vault position and inside the current initialized tick; `L>0`; fee below `1e6`; protocol fee either zero or folded into the coefficients with an explicit formula; no placement, or placement loss proved inside the 1 bp bound. I have not produced that integer proof. `getLiquidityForAmounts` and a known-output `computeSwapStep` do not choose this `x`.

## 6. Orbital and the unlocked case

Orbital calls `exchangeIn(token, amount, shares, minShares, ...)` and `quoteTransition(DepositExactIn)` (`Common.sol:518-534`). Automan's entry points are `mintOptimal` and `increaseLiquidityOptimal` with ticks, two desired amounts, and an NFT id. Empty swap data is autonomous only for that NFT surface. It is not a scalar SE call.

While the manager is unlocked, Aperture cannot open a V3-style pool swap or a V4 `unlock`. `AlreadyUnlocked` is the V4 rule. The existing alternative remains local cover and the blocked formulas. Wings are not spendable in that state.

Outer searches stay even if an inner zap becomes analytic. `_faceForClaim` and `_invertBufferForEffective` search a face or buffer amount. They need `quoteInputForExactShares`, which is a share inverse, not `getOptimalSwap`. `zapSplitWad` searches a three-leg residual. Aperture has no third leg. Exact-output share redemption remains the bisection in `StandardExchangeConstantProduct.sol:113-128`. Aperture's zap-out does not invert it.

Preview parity would require the vault to return the same `x` the execution swap uses, including fee and liquidity at that state. Automan's view and execution can diverge if the pool moves between them. Hookless requires same-state equality (`D30`).

## 7. License and product amendments

Pinned `LICENSE`: Business Source License 1.1, licensor Mirrorless Foundation, licensed work Aperture Protocol, copyright 2023, Change Date "the earlier of 2026-07-01", Change License GPL-2.0-or-later. The session date is after that change date. The text says the change license applies on the change date. This memo does not clear production use or a combined-work obligation. Do not copy the assembly. A clean-room port of the published idea still needs counsel if any of this tree is reused. Dependencies include `uni-v3-lib`, OpenZeppelin, and Solady; their licenses were not read.

No Hookless amendment is justified by Aperture alone. Using it for a one-position zap would still amend D5 if the vault stopped aligning to the post-swap book, and D20 if the sqrt limit at the global min or max replaced the 50 bp check. Aperture's pool swap uses that global limit. The 50 bp check would have to be added around the result. Pons stays separate. `minOut = 0` is not implied; Automan checks `tokenOutMin` on zap-out and refunds mint surplus, which is the opposite of booking it.

## 8. Ranked feasibility

1. **Ready as an explanation, not as code.** V3 NFT, ticks supplied, empty swap data, idle pool. Discovers the segment, then executes.
2. **Port work.** One V4 hookless position, idle, ticks supplied, fee and sign conventions rewritten, salt and settlement added, segment walk either capped by an owner decision or rejected outside one segment.
3. **Accounting research.** Whole-book one-segment quadratic above. Do not drop Aperture's coefficients into `TransitionPlanner`.
4. **Human decision.** Whether segment discovery is acceptable. Whether fungible shares stay on incumbent alignment. Orbital nesting is not solved by this library.

Later gates, not run here: integer identity or a documented counterexample against `SwapMath` for both directions; protocol fee on and off; `l=L` and `l<L`; quote equals execution; out-of-segment revert with no second candidate; 50 bp and 1 bp checked on price, not sqrt price; unlocked path does not call `unlock`; Orbital traces still show the three outer loops unless a separate change removes them. No gas number is predicted.

**Stop. This memo does not authorize a port.**
