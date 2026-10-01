# Grok — Implementation plan: Uniswap V4 FullSpread proportional zap-in

**Date:** 2026-09-27. **Author:** Grok (xai/grok-4.7), independent first pass. **PRD:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (updated 2026-09-27, D1–D19 and §6.4). **Target only:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/`. **Not authorized:** edits, deletion, registry deprecation, or migration of `contracts/protocols/dexes/uniswap/v4/`. This document does not authorize implementation.

No peer artifacts were read. Context7 `/uniswap/v4-core` had no SqrtPriceMath snippet for this query. Swap formulas below are taken from the vendored library the vault already calls: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol`.

## 0. Locked selections

These are decisions. An implementer does not choose among them.

1. **Package.** Change only the FullSpread V4 vault, its V4-only math library, its quote service, and the buffer-leg consumer that reads its quotes. Do not edit `StandardExchangeConstantProduct.sol` (V3 shares it). Do not add vault storage or an owner.
2. **Protection constants** live in bytecode, not storage and not the fee oracle:

   | Name | Value | Applies to |
   |---|---:|---|
   | `REPAIR_PRICE_IMPACT_WAD` | `0.0025e18` (25 bp) | Each holder-funded repair leg, from that leg's start price |
   | `CALLER_PRICE_IMPACT_WAD` | `0.0050e18` (50 bp) | Each caller-funded pool swap, from that leg's start price |
   | `SHORTFALL_WAD` | `0.0010e18` (10 bp) | Actual fill versus the fee-inclusive plan, only when a modeled quote exists |
   | `ALIGNMENT_WAD` | `0.0001e18` (1 bp) | Share-flooring loss, including flooring |

   No cumulative cap across legs or calls (D11). A zero `minSharesOut` does not disable these checks.
3. **Price impact is on price, not sqrt price.** `P ∝ sqrtPriceX96²`. A leg passes if `max(sqrtA, sqrtB)² * 1e18 <= min(sqrtA, sqrtB)² * (1e18 + limitWad)` using `FullMath.mulDiv`. Overflow means the leg fails its cap.
4. **Holder-funded repair is required** where a route trades while idle and off-target. One repair step per user operation or public call, not a search until convergence. Later public calls continue immediately (D10).
5. **Exact-output combined routes** use the algebraic plan in §4. They do not call `_sharesForSingleExit`'s bisection (`StandardExchangeConstantProduct.sol` 113–128) or `_previewZapOutWithdrawal`'s search (`OutBase.sol` 104–116), and they do not quote the user leg and then run `_rebalanceLiquidReserveInternal`.
6. **Sleeve target** replaces percent-of-total. `targetFree(T, p) = floor(T * p / (1e18 + p))` with live oracle `p`. Effective `p = 0` targets zero sleeve. `p = 1e18` targets equal free and deployed.
7. **Blocked off-target exact-output is `InvalidRoute`.** Required maintenance needs PoolManager, and §4 forbids nested unlock. Do not omit maintenance to keep the route. Blocked on-target exact-output stays sleeve-only and closed-form.
8. **Unmodeled hooks have no closed form.** Combined exact-output preview and execution both revert `InvalidRoute`. This is a limit of arbitrary hook code, not an unproven algebra claim.

## 1. Support matrix

`Idle` means `canOpenPoolManagerUnlock()` (`Common.sol` 328–329). `On-target` means §3.4 stop rule. `Modeled` means `hooks == address(0)` or the existing Pons constant-bps hook (`QuoteService.sol` 21–47) and `protocolFee == 0` is not required: fee pips must be the pool's static `lpFee` from `_slot0` (`Common.sol` 432). A hook that can return `BeforeSwapDelta` or an lp-fee override other than the Pons model is unmodeled.

| Route | Selector today | Supported combined behavior | Reject |
|---|---|---|---|
| Idle single-token `exchangeIn` | `InTarget.sol` 40–72 | Caller-funded composition, sleeve placement, `min()` mint. Bounded 4-step solver allowed (§5). Not exact-output. | Alignment, 50 bp, or unsettled delta: revert the deposit. Unmodeled hook: execute on actual fills; preview does not return a number (§8 escalation). |
| Blocked single-token `exchangeIn` | `InBase.sol` 309–313 | Preserve invariant-growth mint, no unlock, `LocalDepositWhileBlocked`. | Nested unlock. |
| Dual `exchangeInManyToOne` | `InMultiTarget.sol` 11–31 | Preserve `min()` mint, no composition swap. Idle tail becomes the one algebraic placement step, not a swap. | Do not apply the 1 bp zap gate. |
| Idle `exchangeOut` token→exact token | `OutExecuteTarget.sol` 49–82; preview `OutQueryTarget.sol` 34–41 | §4 plan: one holder repair step, then caller exact-out swap against the post-repair price. | `InvalidRoute` if the combined plan leaves the §4 domain. |
| Idle `exchangeOut` shares→exact token | `OutQueryTarget.sol` 44–45; `OutBase.sol` 64–118 | §4 plan, then algebraic share burn (§4.4), not bisection. | Same. |
| Idle `exchangeOut` token→exact shares | `OutExecuteTarget.sol` 94–137; `OutBase.sol` 49–61 | §4 plan, then algebraic inverse of composition+`min()` mint. Current `_amountInForShares` alone is not compliance. | Same. Do not keep the invariant-growth inverse as the quote. |
| Idle dual `exchangeOutOneToMany` | `OutMultiTarget.sol` 23–55, 101–120 | Repair step, then proportional burn. Share count stays the current equal-burn rule (`_quoteDualExit` 72–76). Placement is algebraic. No swap in the user leg. | `InvalidRoute` if repair is required and outside §4 domain. `ExchangeOutNotAvailable` remains the unequal-burn reject. |
| Blocked exact-output, on-target, sleeve covers | `OutBase.sol` 78–83; `OutMultiTarget.sol` 83–98 | No repair trade. Existing sleeve closed forms. Dual pay stays local-cover. | `InsufficientLocalReserve` if cover is short. Not `InvalidRoute`. |
| Blocked exact-output, off-target | same | `InvalidRoute(BLOCKED_MAINTENANCE)`. | Do not pay a sleeve-only amount and skip repair. |
| Blocked exact-in deposit | `InBase.sol` 309–313 | Unchanged sleeve mint. | Not an exact-output route. |
| Public `rebalanceLiquidReserve` | `LiquidReserveTarget.sol` 92–96 | One holder repair step. Revert if blocked. No-op success if on-target or no useful step. | No cooldown. No share mint. |
| Activation, import | existing | Unchanged. Zap does not bootstrap. Import does not composition-swap. | Single-token activation still yields 0 shares. |
| Direct token swap `exchangeIn` | `InBase.sol` 74–88 | Preserve user swap. Replace the tail with one algebraic placement if on the idle path; do not add a holder swap to this tail. | User swap still reverts if blocked. |

`InvalidRoute` is only for combined exact-output-plus-maintenance failure. Other failures keep existing errors (`SlippageExceeded`, `InsufficientInput`, `InsufficientLocalReserve`, `TransferDeltaInsufficient`, `EOAPretransferNotAllowed`, `PoolManagerInteractionBlocked`).

## 2. Accounting and attribution

Measure, in order, on every idle money path:

1. Credit the caller before fee collection (`Common.sol` 1219–1240). Pull credit is the balance delta and must equal `amountIn`. Pretransfer credit is `declared` only if `declared <= balanceOf - reserveOfToken` and `LocalCreditLib.requirePretransferCaller` passes. Do not use `_deployedFaceOf` (1242–1247, currently uncalled).
2. If idle, collect fees once (`_collectManagedFeesIfIdle`). That moves `E → F` for incumbents. It is not caller principal and not a second fee in the share price.
3. Snapshot incumbent book `B = D + F + E` after collection and after subtracting the caller's still-unspent credit from `F`. `D` is `_deployedAmounts()`. `E` is `_collectablePositionFees()` (`Common.sol` 637–647). `F` is raw `balanceOf` of the two pool ERC-20s, never position math.
4. Caller composition may spend only that credit (D2). After the caller swap, `C_inRemainder` is unspent credit and `C_out` is the increase in the other token's free balance caused by the take. Position amount changes and fee-growth earned on `L_v` during the swap stay in incumbent `B`. **Do not collect fees between the caller swap and the mint.** A second collect would move swap-earned `E` into `F` and could be misread as caller output.
5. Own-LP fee is not a rebate to the caller. The vault pays the swap as taker. The position earns `feeGrowth` on `L_v`, which increases incumbent `E`. Net holder cost of a holder-funded repair is the taker fee minus that earned `E`, and it accrues to the book. No share mint on repair.
6. Mint uses post-swap `B` and `C`, including sleeve residuals (D7): `sharesOut = min(floor(S * C0 / B0), floor(S * C1 / B1))` for positive `B`. Then place liquidity. Placement does not change the already measured `C` and `B`.
7. End sync writes `balanceOf` for token0, token1, and the self-share (`Common.sol` 610–616). Keep the self-share booking. It is the package exception that stops leftover shares from becoming pretransfer credit. Do not sync economic totals into `R`.

Native currency stays the existing wrap path (`Common.sol` 1072–1075): PoolManager native is wrapped to WETH before it is a sleeve balance. One currency, no double count.

## 3. Stop rule, progress, and the repair step

### 3.1 Definitions

- `p` = `liquidReservePercentageOfVault(this)` at the call. Stored 0 already falls through (`VaultFeeOracleQueryFacet.sol` 322–330).
- `T_i = D_i + F_i`. `targetFree_i = floor(T_i * p / (1e18 + p))`.
- Deadband `tol_i = max(absoluteFloor(token_i), floor(targetFree_i * 0.05e18 / 1e18))`. Absolute floor stays `1` if `decimals <= 6`, else `10^(decimals-6)` (`Common.sol` 362–369).
- Liquidity ratio `R_liq = (a0, a1)` from `LiquidityAmounts.getAmountsForLiquidity` at the current `sqrtPriceX96` and the position ticks, using liquidity `1e6` as the probe (both sides scale). If either probe amount is 0, proportionality uses the non-zero side only and the zero side must have `T = 0` or the route is not proportional.
- Proportionality holds when both probe amounts are positive and `abs(T0 * a1 - T1 * a0) * 1e18 <= ALIGNMENT_WAD * max(T0 * a1, T1 * a0)`, or the analogous one-sided check. Use `mulDiv`; overflow means not proportional.
- Sleeve holds when `targetFree_i == 0 ? F_i <= tol_i : abs(F_i - targetFree_i) <= tol_i`.

### 3.2 Stop

No repair trade if sleeve holds **and** proportionality holds (D12). Alignment loss for deposits is a separate check. Do not treat the 5% sleeve band as the 1 bp share check.

### 3.3 One repair step (public and interleaved)

This is the only holder-funded swap algorithm.

1. If stopped, swap amount is 0. Return a no-op. Public `rebalanceLiquidReserve` still succeeds and syncs.
2. Otherwise sell the token that is heavy versus `R_liq`. Input is only that token's free balance, never `D`, never `E`, never the other token.
3. Ideal price is the current tick's price moved toward balance, capped by `REPAIR_PRICE_IMPACT_WAD` and by the nearest initialized tick in that direction. If the uncapped ideal would cross that tick, the step stops at the tick boundary minus one sqrt unit. It does not walk further ticks.
4. Swap amount is `SqrtPriceMath.getAmount0Delta` or `getAmount1Delta` between current and capped sqrt price, grossed up by the static lp fee: `amountIn = ceil(net * 1e6 / (1e6 - lpFee))` with `lpFee < 1e6`. Then cap by free balance. If the capped input is `<= absoluteFloor`, swap amount is 0.
5. Predicted progress: the post-step proportionality error is strictly smaller, or a sleeve deviation falls, and the other token's sleeve deviation does not newly exceed `tol`. If neither, swap amount is 0 (no churn).
6. After the swap (or immediately if no swap), one liquidity change: `getLiquidityForAmounts` on excess free above target, or the minimum removal that refills a deficit without crossing the other token's target. Mixed excess/deficit after the capped swap: move only the side that reduces the larger deviation and does not push the other token out of band. If no such liquidity delta exists, skip placement.
7. Public call ends. It does not loop. The next call may run in the same transaction.

Holder repair never mints shares. Its price impact is not a promise about repeated calls.

## 4. Exact-output combined closed form

### 4.1 What “closed form” means here

A plan is closed form when every amount is a fixed expression of slot0, position liquidity, tick bounds, the next initialized tick, `lpFee`, free balances, and the requested output, using `SqrtPriceMath`, `LiquidityAmounts`, `FullMath.mulDiv`, and at most **two** forward evaluations to fix rounding. A `while` search over shares, swap size, or price is forbidden on these routes.

Evaluating `getNextSqrtPriceFromOutput` once is closed form. The current bisection is not.

**Domain, not nonexistence.** Outside the domain the route reverts `InvalidRoute`. That does not mean no formula could exist for a larger tick list. The piecewise sum over initialized ticks is the same algebra. This plan evaluates at most one active-tick segment plus its boundary. Crossing that boundary is `InvalidRoute(TICK_DOMAIN)`. Raising the cap later does not require a new proof; it is a gas change this plan does not make.

**Gap, stated plainly.** Equality of this integer plan with `PoolManager.swap` for every fee and rounding path is not proved in this document. The plan therefore: compute with the same pure libraries the manager uses; execute the manager swap; revert the whole transaction if the actual output is short of the request or the actual input exceeds the plan by more than `SHORTFALL_WAD`. That guard does not replace the closed form and does not search for a better input.

### 4.2 Virtual state

`plan(state, request)`:

1. If blocked and not on-target: `InvalidRoute(BLOCKED_MAINTENANCE)`.
2. If unmodeled hook: `InvalidRoute(UNMODELLED_HOOK)`.
3. If on-target, `repairIn = 0` and post-repair state is the current state.
4. Else compute §3.3. If the repair input is non-zero and the capped price would cross the next initialized tick, `InvalidRoute(TICK_DOMAIN)` for exact-output. Public rebalance may stop at the boundary; exact-output may not take a partial repair and still promise the combined quote, because the user leg was solved against a price the partial step does not reach. **Selection:** exact-output repair is all-or-nothing against the computed capped price inside the tick. If 25 bp or the tick forbids the ideal repair, and the zero-repair user leg would itself be a different quote, the combined route is `InvalidRoute(PROTECTION)` rather than a quote that ignores maintenance.
5. Apply the repair to a memory state: new sqrt price from `getNextSqrtPriceFromInput`, new free balances from the gross input and `getAmount*Delta` output, new `D` from `LiquidityAmounts` at the new price and unchanged `L_v`, new `E` increased by `floor(lpFee/1e6 * amountIn * L_v / L_active)`. This `E` formula is the static-fee model. If `L_active == 0`, `InvalidRoute(NO_CLOSED_FORM)`.
6. Solve the user leg on that memory state (§4.3–§4.5).
7. If the user leg's sqrt target crosses the next tick or its caller price impact from the post-repair price exceeds 50 bp, `InvalidRoute`.
8. Only then execute, in that order, inside as few unlocks as the current one-op callback allows. If two unlocks are required, both must be computed before the first unlock. A failed second leg reverts the transaction; it must not be repaired by a third search.

### 4.3 Token exact-out swap

On the post-repair sqrt price, with constant in-range liquidity:

- `sqrtNext = SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtP, L_active, amountOut, zeroForOne)` (`SqrtPriceMath.sol` 156–175).
- Input before fee is the matching `getAmount0Delta` / `getAmount1Delta` between `sqrtP` and `sqrtNext`, rounded up.
- Gross input `ceil(net * 1e6 / (1e6 - lpFee))`.
- Pons, if supported: add the QuoteService bps charge on the unspecified leg (`QuoteService.sol` 50–57) inside this expression. Do not add it again as shortfall.
- Caller pays `grossIn`. Exact `amountOut` is taken. Refund only the exact-out unused pretransfer credit, after settlement, before sync. Exact-in still refunds nothing.

### 4.4 Shares in, exact token out

Real-number inverse of the current forward `_singleExit` (`StandardExchangeConstantProduct.sol` 98–110):

```text
q = amountOut / reserveOut
f = 1 - sqrt(1 - q)
shares = ceil(supply * f)
```

Integer rule, and the only rounding procedure:

1. If `amountOut > reserveOut` or `supply == 0`, revert `InsufficientBacking` (existing), not `InvalidRoute`.
2. If `reserveOther == 0`, `shares = ceil(amountOut * supply / reserveOut)`.
3. Else compute `f` with `FixedPointMathLib` sqrt, rounding the sqrt up so `f` does not understate shares. `shares = ceil(supply * f)`.
4. Evaluate `_singleExit` at `shares` and, if output is still short, at `shares + 1` only. If neither delivers `amountOut` with `shares <= supply - 1`, `InvalidRoute(NO_CLOSED_FORM)`. Do not bisect.
5. Reserves in this inverse are the post-repair complete book, not the pre-repair book.

The forward `_singleExit` may stay. Combined routes must not call `_sharesForSingleExit`.

### 4.5 Token in, exact shares out

This is the inverse of idle composition, not `_amountInForShares`.

On the post-repair incumbent book `B0, B1` and supply `S`:

```text
C0 = ceil(sharesOut * B0 / S)
C1 = ceil(sharesOut * B1 / S)
```

Require the §5.2 epsilon check on these `C` values. If it fails, `InvalidRoute(ALIGNMENT)`.

The caller holds one token. The other leg of `C` is the exact-out swap output from §4.3. `amountIn = grossSwapIn + retainedInput`, where `retainedInput` is the same-token component of `C`. If that swap is zero because the caller already holds the scarce mix, `amountIn = C_token`. First mint (`S == 0`) has no single-token closed form: `InvalidRoute(NO_CLOSED_FORM)`. Activation remains dual-token.

Execute: repair, caller swap, measure actual `C` and `B`, mint exactly `sharesOut` if actual epsilon passes, else revert. Do not mint a different share count. Surplus input rounding stays in the book (existing exact-out rule). Unused pretransfer above `amountIn` refunds to `msg.sender` before sync.

### 4.6 Dual exact-out

No user swap. After the repair virtual state, `s0 = ceil(amount0 * S / T0)`, `s1 = ceil(amount1 * S / T1)`. If `s0 != s1`, keep `ExchangeOutNotAvailable`. If equal, that share count is the closed form. Idle execution removes that share of liquidity, pays the exact amounts, then one algebraic placement. It does not call `_rebalanceLiquidReserveBestEffort`.

## 5. Idle exact-in composition solver

Allowed to be iterative because §6.4's ban is exact-output-only. Locked algorithm, 4 steps, no fifth:

1. After credit and the single fee collect, incumbent ratio is `B0:B1`.
2. Let `x` be the amount of the input token to swap, `0 <= x <= credit`. Output `y(x)` comes from one `getNextSqrtPriceFromInput` plus fee gross-up, same tick domain. If `x` would cross the next tick, clamp `x` to the tick-boundary input. Do not walk ticks in the solver.
3. Post-swap incumbent `B'` includes position amount change and predicted `E` increase. Caller basket is `(credit - x, y)`.
4. Four Newton steps on `x` to drive `y / (credit - x)` toward `B1' / B0'`. Each step uses the analytic derivative of the single-tick `getAmount*Delta` ratio. If a step leaves the tick, clamp.
5. After four steps, simulate the integer mint. If epsilon > 1 bp, price impact > 50 bp, or `y` shortfall versus the step's own fee-inclusive output > 10 bp, revert `UniswapV4ExchangeIn_AlignmentExceeded`. Do not fall back to invariant growth.
6. On success, execute that one swap, measure actual `C` and `B`, mint, then one algebraic placement. The placement is not a second solver.

Unmodeled-hook exact-in does not use this quote. See §8.

## 6. Quotes and hooks

| Surface | Required behavior |
|---|---|
| `previewExchangeIn` | Idle modeled: §5 plan's `sharesOut`. Blocked: current invariant-growth preview. Unmodeled: revert `QuoteNotExact`, never a vanilla share count. |
| `previewExchangeOut` | The §4 `amountIn` or share burn. Same revert as execution, including `InvalidRoute`. |
| `quoteExternalDeposit` / `InQueryTarget._inventoryDeposit` (112–132) | Must apply the same plan, then the new `targetFree`. Today it mints one-sided and rebalances with percent-of-total. |
| `QuoteService._quoteZapInShares` (138–145) | Stop using pool-position zap plus `ConstProdUtils` as the deposit quote. Call the same plan. |
| `_adjustHookSwap` (50–55) | Pons bps stay inside the plan. The `return amount` branch for other hooks must not be used as an exact-output number. |
| Buffer leg | `UniswapV4SeBufferHookLegLib.sol` 77–84 treats `previewExchangeIn == 0` as no quote. Catch `InvalidRoute` and `QuoteNotExact` and take that same empty path. Do not assume a zero return. |

Hook flags are not compatibility proof (D14). No whitelist. Managed positions stay direct PoolManager calls (`Common.sol` 973–986). No Universal Router migration.

## 7. Errors, ABI, storage, events

No new storage variables. No new external mutating selectors. `exchangeIn`, `exchangeOut`, `exchangeInManyToOne`, `exchangeOutOneToMany`, and `rebalanceLiquidReserve` keep their signatures.

New errors on the FullSpread common base:

```solidity
error InvalidRoute(bytes32 reason);
error QuoteNotExact(bytes32 reason);
error UniswapV4ExchangeIn_AlignmentExceeded(uint256 epsilonWad, uint256 limitWad);
```

`reason` constants: `BLOCKED_MAINTENANCE`, `TICK_DOMAIN`, `UNMODELLED_HOOK`, `NO_CLOSED_FORM`, `PROTECTION`, `ALIGNMENT`. Adding errors does not change function selectors.

New events, no new views:

```solidity
event CompositionSwap(address tokenIn, uint256 amountIn, uint256 amountOut, uint256 sqrtPriceAfterX96);
event RepairStep(bool zeroForOne, uint256 amountIn, uint256 amountOut, uint256 sqrtPriceBeforeX96, uint256 sqrtPriceAfterX96, bool traded);
event PlacementResidual(uint256 free0, uint256 free1, uint256 deployed0, uint256 deployed1, uint256 targetFree0, uint256 targetFree1);
```

Emit `RepairStep` even when `traded` is false and the call was an exact-output or public rebalance, so a no-op is visible. Emit `PlacementResidual` after every idle deposit and exact-output that places or skips placement.

`_targetFree` (`Common.sol` 358–360) and `_inventoryRebalanceSnap` (`InQueryTarget.sol` 131–132) must use the deployed-principal formula. `actualLiquidReservePercentage` may keep reporting free/total; it is a measurement, not the target. NatSpec must say so.

## 8. Escalation, not an assumption

**Exact-in preview parity versus unmodeled hooks.** §10 forbids a vanilla number. Older preview-parity law wants preview and execution to agree. This plan does **not** resolve that by disabling exact-in on unmodeled hooks, and it does **not** resolve it by returning a vanilla preview.

Selected pending owner confirmation: unmodeled exact-in **executes** with measured fills, 50 bp price impact, and 1 bp alignment, and does **not** apply the 10 bp shortfall check because no fee-inclusive quote exists. Preview reverts `QuoteNotExact`. Exact-output does not use this exception; both sides revert `InvalidRoute`.

If the owner requires numeric preview parity for exact-in, the consistent consequence is `InvalidRoute` on unmodeled exact-in as well. This plan will not silently pick that.

No other product contradiction is treated as optional. Blocked off-target exact-output is `InvalidRoute` because D19 and §4 are both explicit.

## 9. File work packages

All paths under `contracts/vaults/standard/exchange/protocols/uniswap/v4/` unless noted.

| ID | File | Change |
|---|---|---|
| W1 | **New** `UniswapV4FullSpreadZapMath.sol` | Pure plan: sleeve target, stop test, repair step, single-tick swap inverse, share exact-out inverse, epsilon check, price-impact check. No PoolManager calls. |
| W2 | `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` | Replace `_targetFree`. Add errors. Keep sync, pretransfer, and unlock callback. Add a callback operation only if repair and user swap must share one unlock; otherwise two sequential `_executeUnlock` calls with the plan fixed first. |
| W3 | `UniswapV4FullSpreadStandardExchangeVaultInBase.sol` | Idle `_executeZapInDeposit` becomes §5 then placement. Blocked branch unchanged. Delete the post-mint `_rebalanceLiquidReserveBestEffort` on that path so it cannot swap holder inventory. |
| W4 | `UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol` | Heavy plan execution stays behind the existing delegatecall (`InTarget.sol` 86–95). |
| W5 | `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol` and `OutBase.sol` | Exact-out mint, token exact-out, and share exact-out call `plan()` before pull. Remove bisection from these routes. |
| W6 | `UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | Same delegate split for the heavy out path. |
| W7 | `UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol` | Dual exact-out uses §4.6. Remove the best-effort tail. |
| W8 | `UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` | Public rebalance calls one §3.3 step, then sync. Still reverts when blocked. |
| W9 | `UniswapV4FullSpreadStandardExchangeVaultInQueryTarget.sol`, `OutQueryTarget.sol`, `QuoteService.sol` | Quotes call W1. No second formula. |
| W10 | `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` | Catch `InvalidRoute` and `QuoteNotExact`. No change to hook economics. |
| W11 | Interface `IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol` | Events only if the facet must emit them. Do not add a zap selector. Update NatSpec that still says add/remove only. |

Do not modify `contracts/protocols/dexes/uniswap/v4/**` or `StandardExchangeConstantProduct.sol`.

Runtime limit remains 24,576 bytes. If a facet exceeds it, move code into the existing execution delegate. Do not enable `via_ir`. Compiler stays solc 0.8.35, optimizer runs 1 (`foundry.toml` 29–36).

## 10. Tests

Production-first. Registry-deployed FullSpread package. Real fee oracle and PoolManager. No mock of the vault. Hermetic profile. `forge build` before `forge test`. No old-tree fixture as the system under test.

| ID | Proves |
|---|---|
| T1 | Idle unilateral deposits: 4-step plan, actual `C` excludes position delta, shares match `min()`, sleeve uses `floor(T*p/(1e18+p))`, residual event, `R == balanceOf`. |
| T2 | 1 bp fail reverts. A dust deposit that misses 1 bp reverts. No invariant-growth fallback. |
| T3 | Blocked deposit: no `unlock`, invariant-growth mint preserved, no repair. |
| T4 | Blocked off-target `exchangeOut` reverts `InvalidRoute(BLOCKED_MAINTENANCE)` and does not transfer. |
| T5 | Blocked on-target exact-out pays sleeve cover or `InsufficientLocalReserve`. |
| T6 | Idle exact-out share mint amount equals the §4.5 plan, not `_amountInForShares`. Independent reference builds the same expression without calling the vault helper. |
| T7 | Idle shares→token exact-out uses two forward checks at most. A bisection counter is not an acceptable implementation; the test calls the math library and asserts the candidate. |
| T8 | Repair-plus-user-leg plan is computed before the first swap. A tick-crossing request reverts `InvalidRoute` with pool state unchanged. |
| T9 | Public rebalance: one step, 25 bp, immediate second call, no-op when stopped, no shares minted, holder book absorbs the fee. |
| T10 | Own-LP fee on a caller swap increases incumbent `E` and is absent from `C`. |
| T11 | Pretransfer: contract caller, EOA revert, booked inventory not re-credited, price move does not change `R`. |
| T12 | Unmodeled hook exact-output reverts on preview and execution. Pons bps match `QuoteService` and are not double-counted. |
| T13 | Native/WETH one balance. Dual join and import unchanged. Activation rejects single-token. |
| T14 | Buffer leg treats `InvalidRoute` as no quote and does not decode a vanilla amount. |
| T15 | `via_ir` is not required. Facet runtime `<= 24576`. |

## 11. Confidence and blockers

**High:** target tree, current bisection locations, pretransfer and sync on FullSpread, sleeve-formula conflict with `Common.sol` 358–360, and the D19 consequence for blocked off-target exact-output.

**Medium:** the static `E` increment `lpFee/1e6 * amountIn * L_v / L_active` matches v4 fee-growth inside a single tick with no protocol-fee split. Implementation must compare it to one hermetic swap and, on mismatch, use the manager's observed fee-growth delta in the **execution check** while keeping the pure plan as the quote. A mismatch larger than 10 bp is a revert, not a silent formula edit.

**Low / gap:** multi-tick piecewise inverse is known to be a finite sum and is intentionally outside this plan's gas cap. Arbitrary hooks have no formula. Integer identity with `PoolManager.swap` is unverified until T6–T8 exist. No tests were run for this document.

**Blocker for implementation, not for this plan's other sections:** owner confirmation of §8. Until then, do not implement unmodeled exact-in as either a vanilla preview or a hard `InvalidRoute`.

**Saved:** `docs/research/uniswap-v4-zapin-plan-2026-09-27/grok-original.md`
