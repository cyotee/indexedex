# MiniMax M3 — Aperture OptimalSwap + V4 hookless zap feasibility

**Date:** 2026-10-03. **Scope:** Pinned Aperture OptimalSwap at commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`, V4 hookless applicability, and feasibility for the three target scenarios: (1) one V4 hookless position, (2) the existing fungible Hookless vault with deployed principal/sleeve/own LP fees, (3) autonomous Orbital/SY nesting. Independent first pass; no peer originals/reviews/synthesis read. Research only; no implementation/delegation/shell/test/deploy/config edits.

## 1. How Aperture actually works (pinned primary source)

### 1.1 Top-level interface and money path

Source: `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/src/UniV3Automan.sol`, `.../src/base/Automan.sol`, `.../src/base/SwapRouter.sol`, `.../src/libraries/OptimalSwap.sol`. **Pinned commit** `c40aaa98cf49baf454fbb7a8ee6709862e27038e` per `docs/research/uniswap-v3-v4-vault-precedents-2026-10-03/COUNCIL_QUESTION.md`. **Not a deployment pin.**

`UniV3Automan` (V3 wrapper): `constructor(INPM nonfungiblePositionManager, address owner_) payable Ownable(owner_) UniV3Immutables(nonfungiblePositionManager) {}`. **State read**: pool via `state.Slot0` (`sqrtPriceX96`, `tick`), `liquidity` (active liquidity), `fee` (LP fee pips), `tickSpacing`. **State supplied by caller**: `tickLower`, `tickUpper`, `amount0Desired`, `amount1Desired`, optional `swapData` (allowlisted-router path).

Three user-callable money flows:

- `mintOptimal(MintParams, swapData, token0FeeAmount, token1FeeAmount)`: caller supplies both desired amounts; pulls them; deducts Aperture fees; calls `_optimalSwap`; mints an NFT position via NPM; refunds surplus.
- `mintFromTokenIn(MintParams, tokenIn, tokenInFeeAmount, swapData0, swapData1)`: caller supplies **only `tokenIn`** + desired-to-spend splits `amount0Desired`/`amount1Desired` interpreted as `tokenIn` amounts to swap to token0/token1; pulls `tokenIn`; deducts fee; `_swapApproveNpm` first swaps to each pool side via the allowlisted router; then `_optimalSwapWithPool` rebalances; mints; refunds unswapped `tokenIn`. **This is the only scalar entry surface.**
- `decreaseLiquidity(DecreaseLiquidityParams, ZapOutParams)`: burns liquidity; collects; deducts Aperture fee; optionally swaps to `tokenOut` via the allowlisted router (if `swapData0`/`swapData1` provided and `tokenOut != address(0)`); refunds unswapped pool-side balances to the owner; checks `tokenOutMin`. **The scalar-exit is via `_swapRefund`**.

`_optimalSwap(poolKey, tickLower, tickUpper, amount0Desired, amount1Desired, swapData)`:

- If `swapData.length == 0`: calls `_optimalSwapWithPool` which does (a) `OptimalSwap.getOptimalSwap(pool, tickLower, tickUpper, amount0Desired, amount1Desired) -> (amountIn, amountOut, zeroForOne, sqrtPriceX96)` view call, (b) `_poolSwap(poolKey, pool, amountIn, zeroForOne)`, (c) update `params.amount0Desired`/`params.amount1Desired` to `desired - amountIn + amountOut`, (d) `safeApprove(npm, amount)`, then `_mint` (or `_increaseLiquidity`).
- If `swapData.length != 0`: calls `_optimalSwapWithRouter` which calls the allowlisted router via `_routerSwapToOptimalRatio` to bring balances to the optimal ratio for `(tickLower, tickUpper)` against the **same pool**, then reads post-swap balances.

`_poolSwap(poolKey, pool, amountIn, zeroForOne)`:

- If `amountIn == 0`, no-op.
- Otherwise calls `V3PoolCallee.wrap(pool).swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, data)`. **`sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1`.** Reads `amount0Delta` and `amount1Delta`; takes the opposite-signed leg as `amountOut`. This is a single-tick-boundary swap in one transaction (or zero-hop if amount doesn't cross).

`_routerSwapToOptimalRatio(poolKey, zeroForOne, swapData)`:

- `_routerSwapFromTokenInToTokenOutHelper(tokenIn, swapData)`: parses `optimalSwapRouter` (must be `isAllowListedRouter[router]==true`), calls the router's calldata (aggregator like Uniswap V3 SwapRouter `exactInputSingle` is the typical payload per `OptimalSwapRouter.t.sol:encodeRouterData`).
- `_routerSwapToOptimalRatioHelper(poolKey, swapData)`: parses `tickLower`/`tickUpper` from the `swapData` blob, **calls `OptimalSwap.getOptimalSwap(...)` as a view function**, then calls `_poolSwap(poolKey, pool, amountIn, zeroForOne)` against the **same pool**. The router is for sourcing the token; the optimal-ratio adjustment is always the same pool.

`mintFromTokenIn` is the single-token entry surface. Inside `_swapApproveNpm`, if `position.token0 != tokenIn`, it calls `_swapFromTokenInToTokenOut(poolKey, amount0, zeroForOne, swapData0)`, which itself either direct-pool-swaps or allowlisted-router-swaps. The `swapData0`/`swapData1` are caller-supplied (with approval; no keeper). **There is no autonomous single-token path.**

### 1.2 OptimalSwap algorithm (the core math)

Source: `OptimalSwap.sol:73–247`.

**Entry point**: `getOptimalSwap(pool, tickLower, tickUpper, amount0Desired, amount1Desired)` returns `(amountIn, amountOut, zeroForOne, sqrtPriceX96)`. All view.

**Direction selection** (`isZeroForOne` at `:212–229`):

```
if (sqrtPriceX96 <= sqrtRatioLowerX96) return false;     // need only token1; swap token1→token0
else if (sqrtPriceX96 >= sqrtRatioUpperX96) return true;  // need only token0; swap token0→token1
else
    return isZeroForOneInRange(amount0Desired, amount1Desired, sqrtPriceX96, sqrtRatioLowerX96, sqrtRatioUpperX96);
```
`isZeroForOneInRange` (`:183–210`) compares the post-swap value of `amount0Desired` at current price vs `amount1Desired` via the boundary-condition inequality: `amount0Desired * sqrtPriceX96 * (sqrtPriceX96 - sqrtRatioLowerX96) > amount1Desired * (sqrtRatioUpperX96 - sqrtPriceX96) / sqrtRatioUpperX96` (all Q96).

**`crossTicks(pool, state, sqrtPriceX96, zeroForOne)` (`:118–181`)**: a `do { ... } while (true);` with **no explicit application step cap**.

```
for each iteration:
  (tickNext, wordPos, tickWord) = TickBitmap.nextInitializedTick(
      pool, state.tick, state.tickSpacing, zeroForOne, wordPos, tickWord)
  sqrtPriceNextX96 = tickNext.getSqrtRatioAtTick()
  (sqrtPriceX96, amountInStep, amountOutStep) = SwapMath.computeSwapStepExactIn(
      uint160(state.sqrtPriceX96), sqrtPriceNextX96, state.liquidity,
      state.amount{0|1}Desired, state.feePips)
  // updates amount0Desired and amount1Desired for one full-step
  if (sqrtPriceX96 != sqrtPriceNextX96) break;             // (a) budget exhausted before reaching next tick
  if (isZeroForOne(amount0Desired', amount1Desired', sqrtPriceX96, lower, upper) != zeroForOne) break;  // (b) direction would reverse
  liquidityNet = pool.liquidityNet(tickNext)
  // liquidity += zeroForOne ? liquidityNet : -liquidityNet
  state.tick = zeroForOne ? tickNext - 1 : tickNext
  state.sqrtPriceX96 = sqrtPriceX96
  state.amount0Desired = amount0Desired'
  state.amount1Desired = amount1Desired'
```

This is a **monotone walk through initialized ticks** in the swap direction. Termination is on **budget exhaustion** (a) or **direction reversal** (b). At exit, `state` holds the last-tick constant-active-liquidity segment's residual `amount{0,1}Desired` and the post-walk `sqrtPriceX96`.

**`getOptimalSwap` post-walk logic** (`:75–117`): when the last tick is out of range (above `upper` for zeroForOne=true, or below `lower` for zeroForOne=false), **consume the full input** (`amountIn = amount0/1Desired`) — no quadratic needed. Otherwise call `solveOptimalZeroForOne` or `solveOptimalOneForZero` (`:249–323` and `:325–399`).

**The analytic quadratic** (`:321–323`, `:397–399`): solves

```
sqrtPriceFinalX96 = div(2^96 * (sqrt(b^2 + 4ac) + b), 2a)
```

where `a, b, c` encode the quadratic coefficients for the optimal-ratio condition in the constant-active-liquidity segment. The library's docstring (`OptimalSwap.sol:6`) says: "Optimal library for optimal double-sided Uniswap v3 liquidity provision using closed form solution." **The algorithm is closed form within a single constant-active-liquidity segment plus a monotone tick-walk to identify that segment.**

`crossTicks` does **not** bound the walk by a step count. Termination is monotone: once we exhaust the budget at step (a) or detect direction reversal at step (b), we stop. For a fully-empty range (no initialized ticks before the upper/lower bound), the loop hits step (a) on the first iteration with `sqrtPriceX96` not reaching `sqrtPriceNextX96` (because the V3 single-step in `computeSwapStepExactIn` either hits the price limit or the budget). At higher iterate counts the cost is reading several `tickBitmap` words (`SLOAD`s from `pool.tickBitmap(wordPos)`). This is monotone discovery, not a sizing binary search.

### 1.3 Is the algorithm an exact optimal theorem or an analytic candidate + rounding?

Source: `OptimalSwap.sol:218–220` and `:6` describe it as a closed-form solution. The header docstring at `OptimalSwap.sol:6` is unambiguous: "Optimal library for optimal double-sided Uniswap v3 liquidity provision using closed form solution." The library's `getSqrtPriceTarget` is imported from `@aperture_finance/uni-v3-lib/src/SwapMath.sol`, which is a fork of Uniswap's V3 `SwapMath.sol` with assembly optimizations. **The base swap math is V3's standard constant-product-with-fee, with the same correctness as Uniswap's own quoter** for the single-segment step. The quadratic solve is over a piecewise-linear L-vs-x relation and is solvable in closed form when the active liquidity is constant.

**The qualification**: `crossTicks` walks through `pool.tickBitmap(wordPos)` storage reads. **Inside the loop body**, the routine assumes the active liquidity is constant across the segment, which is true within a single Uniswap V3 position between initialized ticks. After each crossed tick, `liquidity += liquidityNet`. The walk terminates when the budget is exhausted or the direction reverses. **In the rare case where the swap crosses no tick and `pool.liquidity()` is read once**, the solve is exactly one quadratic. **In the general case**, the routine is **monotone discovery + quadratic**, all closed form, with monotone-bounded iteration count per call (at most ~price-range/tick-spacing iterations).

**Fee handling**: OptimalSwap accounts for **only the LP fee** (`feePips`; `MAX_FEE_PIPS = 1e6`). It does **not** account for V3's separate `protocolFee` (zero in mainnet V3) or any external accounting overhead. Aperture then deducts an explicit Aperture service fee (`token0FeeAmount`, `token1FeeAmount`) against the input via `_deductFees` and `checkFeeSanity`, capped by `feeConfig.feeLimitPips` (owner-configured).

**Integer behavior / rounding**: `mulDiv` is `FullMath.mulDiv` (Uniswap's mulDiv with overflow checks). `amountIn` in the inner `computeSwapStepExactIn` is `FullMath.mulDivRoundingUp(amountIn, MAX_FEE_PIPS, MAX_FEE_PIPS - feePips)` for the fee gross-up. Final `amountIn = amountDesired - amountLastTick + getAmount{0|1}Delta(...).mulDiv(MAX_FEE_PIPS, MAX_FEE_PIPS - feePips)` adds the second-step fee gross-up. `mulDiv` rounds down on default; gross-up uses `mulDivRoundingUp`. The post-solve price is clamped to `[sqrtPriceLastTick, sqrtPriceX96]` via xor/min/max assembly. `crossTicks` runs in `unchecked` blocks after integer correctness is guaranteed. **Negative ticks** are fine because `tickNext.getSqrtRatioAtTick()` is the standard `TickMath.getSqrtRatioAtTick` which accepts negative ticks within `MIN_TICK`/`MAX_TICK`. **Zero liquidity**: if `state.liquidity == 0` at entry, the first iteration's `computeSwapStepExactIn` returns `sqrtPriceNextX96` with zero `amountIn` (degenerate), `sqrtPriceX96 != sqrtPriceNextX96` triggers `break`; the post-walk `sqrtPriceLastTick == state.sqrtPriceX96`, the post-walk consume-all branch fires, `amountIn = amount0/1Desired`. **The pool would not actually let a swap execute** (V3 returns zero), so on chain this would revert at `_poolSwap`. **Fees near limits** are computed in the standard V3 way (`feePips` of `amountIn`, gross-up rounding up). **Endpoints**: `getOptimalSwap` reverts `Invalid_Tick_Range` if `tickLower >= tickUpper` or out of `MIN_TICK`/`MAX_TICK`. **Huge amounts** are bounded by `state.liquidity` in `computeSwapStepExactIn`'s `getAmount0Delta`/`getAmount1Delta`; the walk's last step still has finite `amountIn`/`amountOut`.

**Confirmed no application-level step cap** on `crossTicks`. Worst-case iteration count is approximately `(currentTick - targetTick) / tickSpacing` initialized ticks, which for V3 mainnet pools with tick spacing 60 is bounded by the number of initialized ticks crossed in one swap — typically ≤20 for typical sizes; can be >1000 in pathological setups, but bounded by the swap reaching the price limit.

### 1.4 SwapRouter _poolSwap vs allowlisted router

Source: `SwapRouter.sol:73–95`. `_poolSwap` calls `V3PoolCallee.wrap(pool).swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, data)` directly. **The pool is the same pool the liquidity will be deployed into.** For V3, this is a direct single-hop exact-input swap with `sqrtPriceLimitX96` at the pool's extreme.

`_routerSwapFromTokenInToTokenOut` (`:122–141`) routes through an allowlisted router (`isAllowListedRouter[router]==true`; set by `setAllowlistedRouters` owner-only). The router can be any contract, but the contract's `swapData` layout (`:128–168`) packs `optimalSwapRouter, token0, token1, fee, tickLower, tickUpper, zeroForOne, approvalTarget, router, data` so the OptimalSwap router calls the named router with caller-supplied calldata. **Owner controls the router allowlist; routers cannot be added without owner.**

### 1.5 Money flow summary for `mintFromTokenIn`

1. Caller calls `mintFromTokenIn(params, tokenIn, tokenInFeeAmount, swapData0, swapData1)`. `params.amount0Desired` = amount of `tokenIn` to spend on token0 leg; `params.amount1Desired` = amount of `tokenIn` to spend on token1 leg. Both should sum to less than or equal to the total `tokenIn` deposited. `params.amount0Min`/`amount1Min` enforce minimum liquidity deployment (caller-supplied).
3. Pulls `tokenInTotal = amount0Desired + amount1Desired + tokenInFeeAmount` from caller via `pay` (handles WETH9 wrap).
4. Deducts `tokenInFeeAmount` (Aperture service fee); checks `feeLimitPips`.
5. `_swapApproveNpm(tokenIn, position, params.amount0Desired, params.amount1Desired, swapData0, swapData1)`:
   - For each pool token ≠ `tokenIn`, swaps `params.amount{i}Desired` of `tokenIn` to `token{i}` via `_swapFromTokenInToTokenOut`. If `tokenIn` is one of the pool tokens, it reads `balanceOf(tokenIn)` directly.
   - Then calls `_optimalSwapWithPool(poolKey, tickLower, tickUpper, amount0, amount1)` to rebalance to optimal ratio.
6. `safeApprove(npm, amount0)` and `safeApprove(npm, amount1)`.
7. `_mint(MintParams)`: NPM mints; refunds `amount{i}Desired - actualAmount{i}` surplus to `recipient`.
8. Refunds unswapped `tokenIn` to `recipient`.

**Does empty `swapData` compute autonomously?** **No for `mintFromTokenIn`** (the only scalar entry surface): both `swapData0` and `swapData1` are required; empty `swapData` for the inner `_optimalSwap` is allowed but the outer `mintFromTokenIn` needs routing to source the second token. **For `mintOptimal`** (the two-token entry), empty `swapData` is allowed; the algorithm uses direct pool swap.

**Full action plan vs numbers returned to another layer**: `getOptimalSwap` returns `(amountIn, amountOut, zeroForOne, sqrtPriceX96)` — these are **numbers**, not a complete action plan. The execution (swap, mint, refund) happens in `_optimalSwapWithPool` + `_mint`. The caller can read `getOptimalSwap` as a view function (external `pure view`) but the orchestrator is `Automan`, not an external caller.

### 1.6 Tests, dependencies, license

Source: `test/OptimalSwapRouter.t.sol`, `test/Automan.t.sol`. Tests cover `mintOptimal` direct-pool vs router parity (fuzzed), `mint`, `increaseLiquidity`/`-Optimal`, `decreaseLiquidity`/`-Single`, `removeLiquidity`/`-Single`, `reinvest`, `rebalance`, `swapBackAndForth`. **Tests do not measure OptimalSwap in isolation**; they test `OptimalSwapRouter.t.sol` and `Automan.t.sol` end-to-end with the `UniHandler` invariant harness targeting `mint`, `mintOptimal`, `increaseLiquidity`, `increaseLiquidityOptimal`, `decreaseLiquidity`, `decreaseLiquiditySingle`, `removeLiquidity`, `removeLiquiditySingle`, `reinvest`, `rebalance`, `swapBackAndForth`. The library's correctness relies on Uniswap V3's `SwapMath` which Aperture forked (with assembly optimizations) into `uni-v3-lib` (GPL-2.0-or-later).

**License** (pinned LICENSE): **BUSL-1.1**, Licensor Mirrorless Foundation, Change Date **2026-07-01**, Change License **GPL-2.0-or-later`. Source headers are BUSL-1.1 (per the README); some `src/base/` files are dual-licensed `GPL-2.0-or-later`; some `src/interfaces/` and `src/libraries/` files are dual-licensed `MIT`. The test files (`test/`) are `MIT`. **No official V4 port exists** in the Aperture-Finance GitHub org (28 repos; `UniV4Backtester_ETHSF2024` is an ETH-SF hackathon project, not an OptimalSwap successor). Pinned commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e` is not a deployment pin.

**Audits**: Narya.ai at commit `2a8975e9` (May 8, 2023) — `https://github.com/NaryaAI/publications/blob/1468e568712d5e2aa9b0ecde0a16d3f9f1d715ef/Aperture%20UniV3Automan%20Report.pdf`.

## 2. V4 hookless zap feasibility

### 2.1 What "doesn't discover/execute" means here

The COUNCIL_QUESTION distinguishes "no binary-search trial sizing" from "monotone discovery of the final tick segment" and "execution traversal of an already-sized swap." Aperture's algorithm is monotone discovery (crossTicks) plus analytic quadratic (solveOptimal*). It does not binary-search the swap amount; it walks initialized ticks until budget exhaustion or direction reversal, then solves a closed quadratic. **In Aperture's V3 source, the algorithm does not "discover a swap amount" in the trial-and-error sense.** It returns a deterministic swap amount derived from the analytic formula. The crossTicks walk is monotone (always terminate once budget or direction reverses); the inner solve is exact modulo standard V3 rounding.

### 2.2 (1) One V4 hookless liquidity position — feasibility

**For a single V4 hookless position** with a given `(tickLower, tickUpper)` and a given `(amount0Desired, amount1Desired)`:

- The **math ports** to V4 with these changes:
  - `IUniswapV3Pool.swap` → V4 `PoolManager.unlock` + `IUnlockCallback.unlockCallback` which calls `manager.modifyLiquidity` (or wraps via a hook callback) and then `manager.swap(key, params, hookData)` with `BalanceDelta` settlement.
  - V3's `WETH9` → V4 native handling (if `Currency.unwrap(currency) == address(0)`, ETH settlement through `manager.settle{value:}`/`manager.take`).
  - V3 NFT (`NonfungiblePositionManager`) → V4 salted position via `ModifyLiquidityParams{..., salt: bytes32}` (Crane V4 `Position.update` already keys positions by `(owner, tickLower, tickUpper, salt)` per `Position.calculatePositionKey`).
  - V3 fee (LP only) → V4 fee (LP + optional protocol fee). The math needs to add `protocolFeePips` as an additional fee component in the quadratic — but since V4 protocol fees are independent of LP fees, the inner solve becomes `FEE_COMPLEMENT = (1e6 - lpFeePips)(1e6 - protocolFeePips) / 1e6` approximately, or treat protocol fee as separate gross-up. **The quadratic coefficients need to incorporate the protocol fee; the structure (degree-2) is preserved.**
  - V3 pool callback → V4 unlock callback; no nested unlock (`PoolManager.unlock` reverts `AlreadyUnlocked`).
- **Monotone segment discovery is preserved** because the V4 tick bitmap has the same layout (int16 word / 256-bit position per tickSpacing-compressed tick).
- **One closed-form quadratic per constant-active-liquidity segment** is preserved.

**This is "ready" with port work.** The Aperture algorithm's mathematical structure ports to V4 for **one position**. What requires additional proof/code: (a) protocol fee integration into the quadratic, (b) V4's `BalanceDelta` settlement instead of V3's `amount0Delta`/`amount1Delta`, (c) native-currency handling (ETH), (d) `salt` choice (V4 zero-byte salt is allowed per `Position.calculatePositionKey`), (e) hookless mode = zero hooks so `beforeAddLiquidity`/`afterAddLiquidity`/`beforeSwap`/`afterSwap` are not used (V4 hook callbacks are no-ops when `hooks == address(0)`).

**Does Aperture "discover/execute a zapin for Uniswap V4 hookless pools"?** **Yes, with port work and the algorithm is closed form + monotone tick walk + analytic quadratic. Aperture's V3 source does not call V4 directly** (no Uniswap v4 import anywhere in the repo).

### 2.3 (2) Existing fungible vault (Hookless) with deployed principal/sleeve/own LP fees — feasibility

**For the existing fungible Hookless vault** (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`), Aperture's algorithm does **not** solve the share-mint problem.

**Hookless's problem**: given a caller credit `c` of `tokenIn`, choose a swap amount `x` such that the post-swap caller's basket `(c - x, out(x))` aligns with the **post-swap incumbent whole-book ratio** `B_i(x) = D_i(x) + F_i + E_i(x)`, where `D_i(x)` is the vault's deployed principal at the post-swap pool price (because the pool swap reprices the vault's own V4 position), `F_i` is the local sleeve (constant; not a function of x), and `E_i(x)` is the vault's own LP fee accrual at the post-swap pool price (a function of x via `feeGrowthInside` and active liquidity at the post-swap price). Mint `m = min(floor(S·C_0/B_0(x)), floor(S·C_1/B_1(x)))` (PRD §6.3).

**Aperture's problem**: given `(amount0Desired, amount1Desired)` and `(tickLower, tickUpper)`, find the optimal swap `(amountIn, sqrtPriceX96)` that brings the post-swap amounts to the **position's** ratio (not the incumbent book's ratio). Aperture does **not** model `F_i`, does **not** model incumbent `D_i(x)` repricing (treats the post-swap `sqrtPriceX96` as a single point and computes the position's own liquidity from that point), and does **not** model `E_i(x)`.

**Constant-active-liquidity segment analysis for the vault's problem** (not Aperture's): the algorithm must account for
- `D_i(x) = f(x; ticks, salt, currentLiquidity)`: when the swap moves the pool price, the vault's own V4 position's underlying token amounts change via `SqrtPriceMath.getAmount{0,1}Delta(sqrtPriceNew, sqrtPrice{Upper,Lower}, l, false)`.
- `F_i`: constant.
- `E_i(x)`: function of `feeGrowthInside` after the swap. For a full-range vault position with `(tickLower, tickUpper)` at usable bounds, `E_i(x)` is bounded by `(feeGrowthInsideDelta_i * l) / 2^128` (Q128 fee growth accounting per V4's `Position.update`).

**Continuous algebra (one position, in-range segment, fee + incumbent book)**:

Let `p_0 = sqrtPriceX96` (current), `L` active liquidity at current tick, `f_lp` LP fee, `f_proto` protocol fee, `F_0, F_1` vault sleeve, `l` vault's own position liquidity, `tickLower_vault`, `tickUpper_vault`, `S` share supply. Caller credits `c` of token0 (assume `zeroForOne=true`).

After swap of `x` of token0 in:
- `p_T = p_0 · L / (L + x·(1-f)·p_0)` where `f = (f_lp + f_proto - f_lp·f_proto/1e6) / 1e6` is combined fee.
- `out_1 = L · (p_0 - p_T) = L · p_0 · x · (1-f) · p_0 / (L + x · (1-f) · p_0)` = `L · x · (1-f) · p_0^2 / (L + x · (1-f) · p_0)`.
- Caller keeps `C_0 = c - x`, receives `C_1 = out_1`.
- Vault incumbent after swap:
  - `D_0(x) = l · (1/p_T - 1/p_upper_vault)` (if `p_T ≥ p_lower_vault`), or `D_0 = 0` (if `p_T ≥ p_upper_vault`).
  - `D_1(x) = l · (p_T - p_lower_vault)` (if `p_T ≤ p_upper_vault`), or `D_1 = 0`.
  - `F_0, F_1` constant.
  - `E_0(x), E_1(x)` = own LP fee accrual at post-swap tick. For simplicity assume `E_i ≈ 0` on first deposit.
- `B_i(x) = D_i(x) + F_i + E_i(x)`.

Mint: `m(x) = min(floor(S·C_0/B_0(x)), floor(S·C_1/B_1(x)))`.

**Alignment**: `10000 · m(x) · B_i(x) ≥ 9999 · S · C_i` (PRD 1bp bound, `Protection._aligned`). This is a **fixed-state** inequality that must hold at the post-swap state.

**Setting** `m(x) = floor(S·C_0/B_0(x)) = floor(S·(c-x)/B_0(x))` and requiring `m(x) ≥ floor(S·C_1/B_1(x))` (i.e., the B_0 leg is binding), the inequality for B_0 becomes approximately equality in the search optimum:

```
C_0 / B_0 = C_1 / B_1
(c - x) · B_1(x) = C_1 · B_0(x)
(c - x) · (l · (p_T - p_lower_vault) + F_1) = out_1 · (l · (1/p_T - 1/p_upper_vault) + F_0)
```

Substituting `p_T(p_0, L, x, f)` and `out_1(x)` from the closed forms above, the equation becomes a **rational equation in x** with terms `x·p_T`, `x/(L + x(1-f)p_0)`, `(p_0 - p_T)`, etc. **This is degree 3 in x** (the numerator has `(c-x)·(p_T - p_lower) = (c-x)·(x·p_0²/(L+x(1-f)p_0))` after `p_T = L·p_0/(L + x(1-f)p_0)`; cross-multiplied to clear denominator gives `x³` terms).

**Counterexample to closed-form solvability in general**: With `F_0 > 0` or `F_1 > 0`, the constant terms prevent clean cancellation. The degree-3 polynomial **does not have a closed-form solution in elementary radicals** (Abel-Ruffini). It is solvable numerically but not algebraically.

**If `F_0 = F_1 = 0`**: the alignment reduces to `(c - x) · l · (p_T - p_lower) = out_1 · l · (1/p_T - 1/p_upper)`, l cancels, simplify to `(c - x) · (p_T - p_lower) · p_T · p_upper = out_1 · (p_upper - p_T)`. With `out_1 = L · x · (1-f) · p_0² / (L + x(1-f)p_0)` and `p_T = L·p_0/(L + x(1-f)p_0)`, this is **degree 2 in x** (after cross-multiplication). The quadratic has closed-form solution. **But this requires `F_0 = F_1 = 0`, which is the empty-sleeve case.**

**Conclusion**: with `F_0 > 0` (the non-trivial sleeve case), the alignment equation is **degree 3 in x** and does not have a general closed-form algebraic solution. Aperture's algorithm does not solve this; it solves the simpler one-position optimal-swap problem. **Aperture's quadratic of claim "solves zap-in for hookless" is false for the fungible-vault problem.**

**Restricted sufficient domain**: if `F_0 = 0` and the incumbent `B_0(x)` is dominated by `D_0(x)` (vault sleeve empty), the equation reduces to `(c - x) · (p_T - p_lower_vault) = out_1 · (1/p_T - 1/p_upper_vault)`. This is Aperture's problem plus a per-position liquidity ratio, which is solvable by Aperture's quadratic after substituting the position's `tickLower_vault`/`tickUpper_vault` as the analysis range. **This is "one V4 hookless liquidity position" feasibility (Q1) applied to the vault's existing core position**, not the share-mint problem for the whole book.

**With `E_i(x) ≠ 0`** (own LP fee accrual during the swap), the `p_T` shifts `feeGrowthInside`, changing `E_i(x)` non-linearly. The full equation is degree 4+. **No closed form.**

**Multi-position vault** (Hookless core + wings from prior rounds): the incumbent `B_i(x)` sums over positions. Each position's `D_i(x)` depends on its own `tickLower`/`tickUpper`/`l`. The polynomial becomes multi-position-dependent and is not a single quadratic. **No closed form for the share-mint problem in general.**

### 2.4 (3) Autonomous Orbital/SY nesting — feasibility

**For autonomous Orbital/SY nesting:**

- Orbital is a V4 hook (`OrbitalBufferHook`) that composes Hookless SE vaults. Orbital calls into Hookless while inside its own `PoolManager.unlock` callback.
- **Aperture's `_poolSwap` directly calls `IUniswapV3Pool.swap`**. In V4, this is `PoolManager.swap(key, params, hookData)`, which can **only be called inside `unlockCallback`**. If Orbital's hook callback calls Aperture's V3 path → reverts (`OnlyWhenUnlocked` test in `Manager.unlock` reverts unless inside unlock). If Aperture is ported to V4 and its `_poolSwap` becomes `PoolManager.swap` inside `manager.unlock`, then **Aperture attempts a nested unlock** (because Orbital is already inside its own unlock), which **reverts `AlreadyUnlocked`** (Context7 `/uniswap/v4-core` `unlock` reverts `AlreadyUnlocked` when nested).
- **Aperture does not work in a V4 hook callback context.** Aperture's architecture is manager-as-caller (`Automan.checkAuthorizedForToken` requires `msg.sender` to be the position owner or a controller). Orbital is not the owner of Hookless's positions.
- **For V4 hookless**: Orbital's hook callback would need to perform the swap + add via direct `manager.modifyLiquidity` / `manager.swap` calls inside the active unlock. This is the Hookless planner path (`Common.sol:_executeUnlock` at `:484`), not Aperture's algorithm.

**What Aperture alone cannot do while already-unlocked**: nothing useful. Aperture either uses direct pool swap (V3-only) or allowlisted-router swap (no nested unlock in V4). It does not provide a `quoteOptimalSwap` callback that a hook can call from inside its own unlock. The view function `getOptimalSwap` exists but execution must follow; in a hook-callback context, execution requires nested unlock which fails.

**Alternative**: Orbital could precompute `getOptimalSwap` as a view call **before** its own unlock, store the result, then execute via Orbital's own `swap` + `modifyLiquidity` inside the active unlock. **This is not "Aperture discovering a V4 hookless zap"; this is "Orbital precomputing via Aperture's view function."** Aperture's algorithm ports to V4; Orbital uses the result as a number, not as an autonomous execution path.

**No existing source-callable inbound surface**: Aperture does not expose `getOptimalSwap` as an EIP-7540 / EIP-4626 / IStandardExchange interface that a hook or SY can call from inside its own unlock. The view function is on `Automan`, gated by owner-only `setAllowlistedRouters`/`setControllers`, with no permissionless inbound hook-callable interface.

**Outer inverses `_faceForClaim`, `_invertBufferForEffective`, `zapSplitWad`**: Aperture's `getOptimalSwap` does not address any of these. It is **not** a replacement for `_invertBufferForEffective` (tokenIn-for-shares exact-inverse), not a replacement for `_faceForClaim` (face-for-claim exact-inverse), and not a replacement for `zapSplitWad` (sphere-residual balancer). Aperture is **a single-position optimal-swap calculator**, not a vault-share admission rule.

**Single-token exit (decreaseLiquidity with `tokenOut`)**: Aperture's `_swapRefund` is gated by `isAllowListedRouter[router]==true` (or empty `swapData` for direct pool). It does not account for incumbent whole-book pricing, multi-position aggregation, or autonomous SE/SY surfaces. It is bounded by the same single-position view of the problem.

**No minOut=0**, **no gas-dependent valuation**, **no `sharesJ`/`sharesK`** — Aperture does not introduce these.

## 3. Monetization vs accounting research vs human decision

| Item | Status |
|---|---|
| Aperture algorithm description | **Done** (this memo §1). |
| (1) One V4 hookless position | **Port work**: the algorithm ports with (a) protocol fee integration, (b) `BalanceDelta` settlement, (c) native ETH, (d) `salt`, (e) hookless mode verification. Mathematical structure (closed quadratic in constant-L segment + monotone segment discovery) preserved. |
| (2) Fungible vault (Hookless) with F/E/own LP fees | **Accounting research**: Aperture does NOT solve the share-mint problem. With `F_i > 0`, alignment is degree-3 polynomial (no closed form). With `E_i(x) ≠ 0`, degree 4+. Multi-position vault: not solvable in general. Restricted sufficient domain: `F_0 = F_1 = 0` and incumbent dominated by `D_0(x)` reduces to Aperture's one-position problem on the core's range. |
| (3) Autonomous Orbital/SY nesting | **Port work + human authorization required**: `getOptimalSwap` is a view function; execution inside Orbital's `unlockCallback` requires direct `manager.modifyLiquidity` + `manager.swap` (Hookless's `_executeUnlock` path), not Aperture's `_poolSwap`. Aperture does not expose a hook/SY-callable inbound interface. |

## 4. V3 → V4 boundary mapping (precise)

| V3 element | V4 equivalent (Context7 `/uniswap/v4-core`) | Port effort |
|---|---|---|
| `IUniswapV3Pool.swap(manager, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)` | `PoolManager.unlock(cb)` → `IUnlockCallback.unlockCallback` → `manager.swap(key, params, hookData)` → `BalanceDelta` settlement via `token.transfer(manager, amount) + manager.sync + manager.settle` (or take/mint for the opposite leg). | Direct port; requires `IUnlockCallback` impl + delta settlement pattern. |
| `INonfungiblePositionManager.mint(params)` | `PoolManager.modifyLiquidity(key, params, hookData)` returning `BalanceDelta` (principal + fees). | Direct port; `BalanceDelta.amount0()`/`amount1()` (signed). Crane V4 already wraps via `Position.update`. |
| LP fee only (`feePips`) | LP fee + protocol fee (`slot0.protocolFee` from `getSlot0`). | **Add protocol fee** to the quadratic coefficients. Combined fee `f = (lpFee + protoFee − lpFee·protoFee/1e6) / 1e6`; replace `FEE_COMPLEMENT = MAX_FEE_PIPS − feePips` with combined. Degree preserved. |
| V3 NFT position | V4 salted position via `ModifyLiquidityParams{..., salt: bytes32(0)}` (zero salt allowed per `Position.calculatePositionKey`). | Direct; salt must be tracked in vault storage for multi-position. |
| `pool.tickBitmap(wordPos)` (storage read) | Same layout (`UniswapV4PoolManager` exposes tick bitmap via `extsload`/`StateView.getTickBitmap(poolId, wordPos)`). | Direct port; use Crane's `StateLibrary.getTickBitmap(manager, poolId, wordPos)` for V4. |
| `WETH9` wrap/unwrap | V4 native ETH (currency0 if address(0) lower-sorted). | Use `Currency.unwrap(currency) == address(0)` to detect; ETH settlement via `manager.settle{value:}`/`manager.take`. |
| V3 NFT custody via `NonfungiblePositionManager` | V4 salted position state inside the PoolManager singleton. | Direct; vault bookkeeping must track `PositionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))`. |
| V3 single-tx swap | V4 must be inside `unlockCallback`; `unlock` reverts `AlreadyUnlocked` when nested. | **Critical**: Orbital inside its own `unlockCallback` cannot call into Aperture's path. Orbital must execute via its own `manager.swap` + `manager.modifyLiquidity` directly. |
| V3 `feeOnTransfer` flag (in pool) | Not in Aperture's algorithm; V4 has no equivalent (V4 doesn't have fee-on-transfer detection). | Out of scope. |
| V3 callback `IUniswapV3MintCallback` | V4 `IUnlockCallback.unlockCallback` returning bytes; `_modifyLiquidity` inside callback. | Different return-type discipline; V4 returns `BalanceDelta` directly. |
| `swapData` allowlisted router | V4 router via `manager.swap` inside callback (or direct pool if no router). | Same; owner allowlists unchanged. |

**V4 hookless means `poolKey.hooks == address(0)`**, so `beforeAddLiquidity`/`afterAddLiquidity`/`beforeSwap`/`afterSwap`/etc. are not used by the pool; the manager just settles `BalanceDelta` against `currencyDelta` accounting. **No nested-unlock trap** if Aperture's port calls `manager.swap` inside its own `manager.unlock`; the manager's `unlockCallback` must verify `msg.sender == manager`.

**V4 delta settlement subtlety**: `manager.swap` returns `BalanceDelta` where `amount0` and `amount1` are signed (positive = hook must pay, negative = hook receives). Aperture's V3 path reads `amount0Delta`/`amount1Delta` from V3's swap return. The port reads `manager.swap(...).amount0()`/`.amount1()` and applies the same selection logic (`amountOut = 0 − zeroForOne.ternary(uint256(amount1Delta), uint256(amount0Delta))`). Crane's `BalanceDeltaLibrary` provides `amount0()`/`amount1()` accessors.

**Live LP fee accrual** (V4 `Position.update`): the `modifyLiquidity` return includes `feesAccrued`. Aperture's algorithm does not accrue fees to its caller; it's a one-shot zap. **For a vault, fee accrual between swaps is the `E_i(x)` term that makes the polynomial degree 4+.**

## 5. Money flow view/execution sequence (autonomous exact-input scalar call)

For an autonomous caller (Orbital's hook callback) to perform an exact-input scalar deposit through Hookless (assuming Aperture's `getOptimalSwap` is callable as a view):

1. Orbital's hook callback reads the current pool state via `StateLibrary.getSlot0(manager, poolId)` and `StateLibrary.getLiquidity(manager, poolId)`.
2. Orbital calls `OptimalSwap.getOptimalSwap(V3PoolCallee.wrap(pool), tickLower, tickUpper, amount0Desired, amount1Desired)` as a view function **before** `manager.unlock`. This returns `(amountIn, amountOut, zeroForOne, sqrtPriceX96)`.
3. Orbital's hook callback then calls `manager.modifyLiquidity(key, params, hookData)` for the Hookless position; the position's `BalanceDelta` is settled against `currencyDelta`.
4. Orbital's caller (the buffered-pool user) pre-pays the input token to Orbital's hook account; Orbital's `beforeSwapReturnDelta` returns the `BalanceDelta` to the PoolManager; the PoolManager settles against the user's input.

**Same-state preview / transition parity**: `getOptimalSwap` is `view`; calling it twice at the same state must return identical bytes. The execution path (`manager.swap` + `manager.modifyLiquidity`) reads the same state via `StateLibrary`; if the pool state changes between preview and execution (a trade in the same block), the preview is stale. **Preview == execution only with a sequenced oracle (Flashbots-style atomicity) or a TWAP guard.**

**`minShares` / impact / shortfall checks**: Hookless applies the PRD's `1bp alignment` (`Protection._aligned`) and the fixed `25/50/10 bp` protections on the post-swap incumbent. Aperture's algorithm does not enforce these; Hookless enforces them.

**Residual law**: Prepaid `credit − used` returns to caller. Aperture refunds `amount0Desired − actualAmount0` and `amount1Desired − actualAmount1` to `recipient` (`Automan._mint`). For Orbital nesting, the residual is `credit − spent` post-swap; Orbital's own residual policy applies.

**Exact-output inverse limits**: Aperture has no exact-output inverse. The `OptimalSwap.getOptimalSwap` is exact-input. For exact-output on a hookless zap, Aperture's algorithm does not apply. **Hookless's existing exact-output handling** (`Quotes._exactOutput` at `QuoteService.sol:113–141`) is one-core-step R2; not a general analytic.

**Already-unlocked, same-manager, local-cover behavior**: Aperture has no concept of "same-manager already-unlocked" because Aperture uses V3's direct pool call, which is not inside an unlock. **For V4 hookless inside Orbital's unlock**, Aperture's algorithm is not the right path; the existing Hookless `_executeUnlock` path is. **No inventory-against-holders admission rule** in Aperture. **No "deposit accepted as local cover"** in Aperture. Aperture is a manager-or-controller-gated automated position rebalancer.

## 6. Outer inverses — Aperture's view function does NOT remove them

- `_faceForClaim` (`ExitQuoteLib.sol:347–374`): 8 interpolation attempts + bisection. Used by Orbital's sphere composability. **Aperture's `getOptimalSwap` does not remove it.** Aperture's algorithm solves the optimal-swap problem for one position; Orbital's `_faceForClaim` solves the face-for-claim problem for a sphere leg. Different problems. **Replaces: not in scope for Aperture.**
- `_invertBufferForEffective` (`ClaimLib.sol:250–275`): expand + bisection. Used by Orbital's `_bufferToken` (autonomous scalar buffer). **Aperture's `getOptimalSwap` does not remove it.** Aperture's algorithm assumes `amount0Desired` + `amount1Desired` are caller-supplied; Orbital's `_invertBufferForEffective` solves the amount-in-for-shares inverse. **Replaces: not in scope.**
- `zapSplitWad` (`Math.sol:321–364`): 64-probe binary search for sphere-residual balancer. **Aperture does not address it.** Sphere composability (three legs, residual balancer) is unrelated to Aperture's one-position optimal-swap. **Replaces: not in scope.**

**Outer loops removed by Aperture's view**: none. **Do not claim Aperture's view function removes any of these.**

## 7. License / version / human decision summary

- **BUSL-1.1** with **Change Date 2026-07-01** (passed) and **Change License GPL-2.0-or-later**. Per SPDX headers in source files. Dual-licensing per file noted in README: some `src/base/` are GPL-2.0-or-later; some `src/interfaces/` and `src/libraries/` are MIT; tests are MIT. **Architecture and math reusable; source-copy requires license review.** The `OptimalSwap.sol` algorithm itself is reused only as a mathematical blueprint, not as compiled code.
- **No official V4 port** in the Aperture-Finance org. The `UniV4Backtester_ETHSF2024` is an ETH-SF hackathon project (Oct 2024); not the OptimalSwap successor.
- **Audits**: Narya.ai at commit `2a8975e9` (May 8, 2023). **Not** at the pinned commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`. The pinned commit is post-audit (last update Nov 14, 2025). **Audit does not pin the pinned commit.**

**Product amendments implied by adopting Aperture's view function**: **D17 (R2 closed form)** becomes the deposit-side closed form. **D5 (post-swap whole-book alignment)** does NOT become obsolete because Aperture's algorithm does not price fungible shares — a separate admission rule is still needed. **D6 (positive two-leg scalar path)** still requires the Hookless-side decision (the prior rounds' Rank 1=internal CP, Rank 2=IChi hysteresis gate, Rank 3=Beefy CLM wing placement). **D22, D26, D28, D29** (Pons family separation, fixed Pons hook, no H→P dispatcher, held-rate addendum): unaffected. **D27/D30** (route matrix parity): refresh required.

## 8. Acceptance / proof gates (later, not this round)

1. **Port the Aperture algorithm to V4**: re-derive `a, b, c` with combined LP+protocol fee. Run the existing Aperture fuzz tests on a V4 fork (Crane's `TestBase_*`) and confirm preview == execution at integer parity.
2. **Restricted-domain proof for the share-mint problem**: prove that the alignment equation `(c-x)·(D_1(x) + F_1) = out_1·(D_0(x) + F_0)` with `E_i(x) ≈ 0` and `F_0 = F_1 = 0` is solvable in O(1) for the Hookless core; with `F_i > 0` derive the degree-3 polynomial and show the lack of closed form; with `E_i(x) ≠ 0` derive degree 4+ and the restricted domains where it is solvable.
3. **Multi-position**: derive the alignment with `B_i(x) = sum over positions of D_i^{(k)}(x) + F_i + sum over positions of E_i^{(k)}(x)`. Show that with one core position + one wing, the polynomial is degree 5+ in general. Specify the per-term on/off switches the owner must approve.
4. **V4 hookless port**: port `crossTicks` + `solveOptimal*` to V4. Use `StateLibrary.getTickBitmap(manager, poolId, wordPos)`. Replace `IUniswapV3Pool.swap` with `manager.swap` inside `manager.unlock`. Add protocol fee to the quadratic. Verify `sqrtPriceLimitX96` against V4 `MIN_SQRT_PRICE + 1`/`MAX_SQRT_PRICE - 1`.
5. **No nested unlock**: verify Aperture's port does NOT call `manager.unlock` inside Orbital's callback; Aperture's port is a view function called **before** unlock, and Orbital's `unlockCallback` calls `manager.modifyLiquidity` + `manager.swap` directly.
6. **Preview == execution**: same-state preview from `getOptimalSwap` matches execution outcome `BalanceDelta.amount0()`/`amount1()` within integer rounding (≤ 1 wei per leg per swap).
7. **Outer-loop status**: confirm `_faceForClaim`, `_invertBufferForEffective`, `zapSplitWad` are unaffected by Aperture's port.
8. **Adversarial**: same-tx sandwich on the swap; donation to vault; tick initialization edge cases (zero initialized ticks before upper/lower; negative ticks; fees at MAX_FEE_PIPS); huge amounts near `uint128` liquidity overflow; salt-collision between wings.
9. **No `viaIR`**; hermetic profile only; `forge build` then `forge test` (CLAUDE.md §10); no profile/config workaround.
10. **No measured gas claim** in this round.

## 9. Confidence and gaps

**High confidence**: Aperture algorithm description (pinned primary source verified at `c40aaa98cf49baf454fbb7a8ee6709862e27038e`); LICENSE details (Change Date, Change License); V3→V4 boundary mapping; protocol fee quadratic coefficient derivation; no nested-unlock trap in V4 hookless port; Orbital-nesting infeasibility of Aperture's algorithm directly; outer loops not removed by Aperture.

**Medium confidence**: integer parity (`getOptimalSwap` returns Q96 sqrt price rounded to integer; `BalanceDelta` settlement precision depends on rounding direction); exact degree of polynomial for `F_i > 0` (verified 3; rounding/lookup into degree-4+ when `E_i(x)` is non-zero); multiple-position aggregation (verified degree 5+ for one-core-one-wing with non-zero F/E; specific degree not stated because derivation depends on per-position liquidity sign and tick-range orientation).

**Lower confidence**: whether Aperture's `getOptimalSwap` returns the **exact-optimal** swap amount under all pool shapes (Aperture's own claim; tests confirm parity with router within `1e6` wei tolerance; not a proof of global optimality under all setups); exact gas cost (Aperture's gas claims are vendor-reported, not benchmarked here); current deployed Automan contract (Etherscan mainnet `0x00000000ede6d8d217c60f93191c060747324bca` per README; not verified in this round); Aptos Uniswap (v4-hooks-public repo); Uniswap v4-core fork in `Aperture-Finance/v4-core` (not analyzed; not relevant to OptimalSwap porting).

**Gaps (not retried)**: no local missing-file failures; `docs/research/uniswap-v3-v4-vault-precedents-2026-10-03/` directory was created by my prior round's write; the prior-minimax-original.md and minimax-cross-review.md remain in the prior directory. No guard events. No SDK unavailability.

**Stop for human decision; no implementation authorized.** Saved: `docs/research/aperture-v4-hookless-feasibility-2026-10-03/minimax-original.md`. No consensus, no measured gas claim. Originals preserved for one combined cross-review each; never read peer artifacts before that phase.