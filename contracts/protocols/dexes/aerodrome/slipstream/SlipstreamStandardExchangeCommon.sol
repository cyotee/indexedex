// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SlipstreamUtils} from "@crane/contracts/utils/math/SlipstreamUtils.sol";
import {SlipstreamQuoter} from "@crane/contracts/utils/math/SlipstreamQuoter.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";

contract SlipstreamStandardExchangeCommon is ISecurePullErrors {
    using BetterSafeERC20 for IERC20;
    struct ManagedTicks {
        int24 centerLower;
        int24 centerUpper;
        int24 lowerWingLower;
        int24 lowerWingUpper;
        int24 upperWingLower;
        int24 upperWingUpper;
    }

    struct ManagedLiquidityPlan {
        uint128 centerLiquidity;
        uint128 lowerWingLiquidity;
        uint128 upperWingLiquidity;
        uint256 amount0Used;
        uint256 amount1Used;
    }

    struct ManagedLiquidityBudgets {
        uint256 centerBudget0;
        uint256 centerBudget1;
        uint256 upperWingBudget0;
        uint256 lowerWingBudget1;
    }

    function _pool() internal view returns (ICLPool) {
        return SlipstreamPoolAwareRepo._slipstreamPool();
    }

    function _loadPoolState()
        internal
        view
        returns (address token0, address token1, uint160 sqrtPriceX96, int24 tick, uint24 fee, uint24 unstakedFee)
    {
        ICLPool pool = _pool();
        token0 = pool.token0();
        token1 = pool.token1();
        (sqrtPriceX96, tick, , , , ) = pool.slot0();
        fee = pool.fee();
        unstakedFee = pool.unstakedFee();
    }

    function _quoteSwap(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }

        ICLPool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if ((zeroForOne && tokenOut != pool.token1()) || (!zeroForOne && tokenOut != pool.token0())) {
            return 0;
        }

        SlipstreamQuoter.SwapQuoteResult memory quote = SlipstreamQuoter.quoteExactInput(
            SlipstreamQuoter.SwapQuoteParams({
                pool: pool,
                zeroForOne: zeroForOne,
                amount: amountIn,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                maxSteps: 0,
                includeUnstakedFee: true
            })
        );

        return quote.amountOut;
    }

    function _quoteSwapOut(address tokenIn, address tokenOut, uint256 amountOut) internal view virtual returns (uint256 amountIn) {
        if (amountOut == 0) {
            return 0;
        }

        ICLPool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if ((zeroForOne && tokenOut != pool.token1()) || (!zeroForOne && tokenOut != pool.token0())) {
            return 0;
        }

        SlipstreamQuoter.SwapQuoteResult memory quote = SlipstreamQuoter.quoteExactOutput(
            SlipstreamQuoter.SwapQuoteParams({
                pool: pool,
                zeroForOne: zeroForOne,
                amount: amountOut,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                maxSteps: 0,
                includeUnstakedFee: true
            })
        );

        return quote.amountIn;
    }

    function _amountsForLiquidityAtPrice(uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity == 0) {
            return (0, 0);
        }
        return SlipstreamUtils._quoteAmountsForLiquidity(sqrtPriceX96, tickLower, tickUpper, liquidity);
    }

    function _getPositionLiquidityFromPool(SlipstreamVaultRepo.PositionKind kind_) internal view returns (uint128 liquidity_) {
        if (!SlipstreamVaultRepo._isPositionCreated(kind_)) {
            return 0;
        }
        (liquidity_, , , , ) = _pool().positions(SlipstreamVaultRepo._getOwnPositionKey(kind_));
    }

    function _positionAmounts(SlipstreamVaultRepo.PositionKind kind_, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint128 liquidity = _getPositionLiquidityFromPool(kind_);
        if (liquidity == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks(kind_);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidity);
    }

    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        if (!SlipstreamVaultRepo._isPositionCreated()) {
            return (0, 0);
        }

        (, , uint160 sqrtPriceX96, , , ) = _loadPoolState();
        (uint256 center0, uint256 center1) = _positionAmounts(SlipstreamVaultRepo.PositionKind.Center, sqrtPriceX96);
        (uint256 lower0, uint256 lower1) = _positionAmounts(SlipstreamVaultRepo.PositionKind.LowerWing, sqrtPriceX96);
        (uint256 upper0, uint256 upper1) = _positionAmounts(SlipstreamVaultRepo.PositionKind.UpperWing, sqrtPriceX96);

        reserve0 = center0 + lower0 + upper0;
        reserve1 = center1 + lower1 + upper1;
    }

    function _managedTicks() internal view returns (ManagedTicks memory managedTicks) {
        if (!SlipstreamVaultRepo._isPositionCreated()) {
            return _deriveManagedTicks();
        }

        (managedTicks.centerLower, managedTicks.centerUpper) =
            SlipstreamVaultRepo._getPositionTicks(SlipstreamVaultRepo.PositionKind.Center);
        (managedTicks.lowerWingLower, managedTicks.lowerWingUpper) =
            SlipstreamVaultRepo._getPositionTicks(SlipstreamVaultRepo.PositionKind.LowerWing);
        (managedTicks.upperWingLower, managedTicks.upperWingUpper) =
            SlipstreamVaultRepo._getPositionTicks(SlipstreamVaultRepo.PositionKind.UpperWing);
    }

    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        ICLPool pool = _pool();
        (, int24 currentTick, , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();
        int24 outerHalfWidth = int24(uint24(SlipstreamVaultRepo._widthMultiplier())) * tickSpacing / 2;
        int24 centerHalfWidth = int24(uint24(SlipstreamVaultRepo._centerWidthMultiplier())) * tickSpacing / 2;

        if (centerHalfWidth < tickSpacing) {
            centerHalfWidth = tickSpacing;
        }
        if (outerHalfWidth <= centerHalfWidth) {
            outerHalfWidth = centerHalfWidth + tickSpacing;
        }

        managedTicks.centerLower = _snapTick(currentTick - centerHalfWidth, tickSpacing);
        managedTicks.centerUpper = _snapTick(currentTick + centerHalfWidth, tickSpacing);

        if (managedTicks.centerLower < TickMath.MIN_TICK) {
            managedTicks.centerLower = _snapTick(TickMath.MIN_TICK, tickSpacing);
        }
        if (managedTicks.centerUpper > TickMath.MAX_TICK) {
            managedTicks.centerUpper = _snapTick(TickMath.MAX_TICK, tickSpacing);
        }
        if (managedTicks.centerLower == managedTicks.centerUpper) {
            managedTicks.centerUpper = managedTicks.centerLower + tickSpacing;
        }

        managedTicks.lowerWingLower = _snapTick(currentTick - outerHalfWidth, tickSpacing);
        managedTicks.lowerWingUpper = managedTicks.centerLower;
        managedTicks.upperWingLower = managedTicks.centerUpper;
        managedTicks.upperWingUpper = _snapTick(currentTick + outerHalfWidth, tickSpacing);

        if (managedTicks.lowerWingLower < TickMath.MIN_TICK) {
            managedTicks.lowerWingLower = _snapTick(TickMath.MIN_TICK, tickSpacing);
        }
        if (managedTicks.upperWingUpper > TickMath.MAX_TICK) {
            managedTicks.upperWingUpper = _snapTick(TickMath.MAX_TICK, tickSpacing);
        }
        if (managedTicks.lowerWingLower >= managedTicks.lowerWingUpper) {
            managedTicks.lowerWingLower = managedTicks.lowerWingUpper - tickSpacing;
        }
        if (managedTicks.upperWingUpper <= managedTicks.upperWingLower) {
            managedTicks.upperWingUpper = managedTicks.upperWingLower + tickSpacing;
        }
    }

    function _managedLiquidityPlan(ManagedTicks memory managedTicks, uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityPlan memory plan)
    {
        (, , uint160 sqrtPriceX96, , , ) = _loadPoolState();
        return _managedLiquidityPlanAtState(managedTicks, available0, available1, sqrtPriceX96);
    }

    function _managedLiquidityPlanAtState(
        ManagedTicks memory managedTicks,
        uint256 available0,
        uint256 available1,
        uint160 sqrtPriceX96
    ) internal view returns (ManagedLiquidityPlan memory plan) {
        ManagedLiquidityBudgets memory budgets = _managedLiquidityBudgets(available0, available1);
        _setCenterPlan(plan, managedTicks, sqrtPriceX96, budgets);
        _setLowerWingPlan(plan, managedTicks, sqrtPriceX96, budgets);
        _setUpperWingPlan(plan, managedTicks, sqrtPriceX96, budgets);
    }

    function _managedLiquidityBudgets(uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityBudgets memory budgets)
    {
        budgets.centerBudget0 = (available0 * SlipstreamVaultRepo._activeLiquidityBps()) / 10_000;
        budgets.centerBudget1 = (available1 * SlipstreamVaultRepo._activeLiquidityBps()) / 10_000;
        budgets.upperWingBudget0 = available0 - budgets.centerBudget0;
        budgets.lowerWingBudget1 = available1 - budgets.centerBudget1;
    }

    function _setCenterPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.centerLiquidity = SlipstreamUtils._quoteLiquidityForAmounts(
            sqrtPriceX96,
            managedTicks.centerLower,
            managedTicks.centerUpper,
            budgets.centerBudget0,
            budgets.centerBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            managedTicks.centerLower,
            managedTicks.centerUpper,
            plan.centerLiquidity
        );
        plan.amount0Used += amount0;
        plan.amount1Used += amount1;
    }

    function _setLowerWingPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.lowerWingLiquidity = SlipstreamUtils._quoteLiquidityForAmounts(
            sqrtPriceX96,
            managedTicks.lowerWingLower,
            managedTicks.lowerWingUpper,
            0,
            budgets.lowerWingBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            managedTicks.lowerWingLower,
            managedTicks.lowerWingUpper,
            plan.lowerWingLiquidity
        );
        plan.amount0Used += amount0;
        plan.amount1Used += amount1;
    }

    function _setUpperWingPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.upperWingLiquidity = SlipstreamUtils._quoteLiquidityForAmounts(
            sqrtPriceX96,
            managedTicks.upperWingLower,
            managedTicks.upperWingUpper,
            budgets.upperWingBudget0,
            0
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            managedTicks.upperWingLower,
            managedTicks.upperWingUpper,
            plan.upperWingLiquidity
        );
        plan.amount0Used += amount0;
        plan.amount1Used += amount1;
    }

    function _quoteManagedWithdrawal(uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (, , uint160 sqrtPriceX96, , , ) = _loadPoolState();
        (uint256 center0, uint256 center1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            SlipstreamVaultRepo.PositionKind.Center,
            sharesBurned,
            totalShares
        );
        (uint256 lower0, uint256 lower1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            SlipstreamVaultRepo.PositionKind.LowerWing,
            sharesBurned,
            totalShares
        );
        (uint256 upper0, uint256 upper1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            SlipstreamVaultRepo.PositionKind.UpperWing,
            sharesBurned,
            totalShares
        );

        amount0 = center0 + lower0 + upper0;
        amount1 = center1 + lower1 + upper1;
    }

    function _quotePositionWithdrawal(
        uint160 sqrtPriceX96,
        SlipstreamVaultRepo.PositionKind kind_,
        uint256 sharesBurned,
        uint256 totalShares
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint128 currentLiquidity = _getPositionLiquidityFromPool(kind_);
        if (currentLiquidity == 0 || totalShares == 0) {
            return (0, 0);
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks(kind_);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidityToBurn);
    }

    function _updateManagedPositionLiquidities() internal {
        _updatePositionLiquidityFromPool(SlipstreamVaultRepo.PositionKind.Center);
        _updatePositionLiquidityFromPool(SlipstreamVaultRepo.PositionKind.LowerWing);
        _updatePositionLiquidityFromPool(SlipstreamVaultRepo.PositionKind.UpperWing);
    }

    function _updatePositionLiquidityFromPool(SlipstreamVaultRepo.PositionKind kind_) internal {
        SlipstreamVaultRepo._updatePositionLiquidity(kind_, _getPositionLiquidityFromPool(kind_));
    }

    function _collectManagedFees() internal {
        _collectPositionFees(SlipstreamVaultRepo.PositionKind.Center);
        _collectPositionFees(SlipstreamVaultRepo.PositionKind.LowerWing);
        _collectPositionFees(SlipstreamVaultRepo.PositionKind.UpperWing);
    }

    function _collectPositionFees(SlipstreamVaultRepo.PositionKind kind_) internal {
        if (!SlipstreamVaultRepo._isPositionCreated(kind_)) {
            return;
        }

        ICLPool pool = _pool();
        bytes32 positionKey = SlipstreamVaultRepo._getOwnPositionKey(kind_);
        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(positionKey);
        if (tokensOwed0 == 0 && tokensOwed1 == 0) {
            return;
        }

        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks(kind_);
        pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
    }

    function _snapTick(int24 tick_, int24 tickSpacing_) internal pure returns (int24 snappedTick_) {
        int24 compressed = tick_ / tickSpacing_;
        if (tick_ < 0 && tick_ % tickSpacing_ != 0) {
            compressed -= 1;
        }
        snappedTick_ = compressed * tickSpacing_;
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address recipient)
        internal
        returns (uint256 amountOut)
    {
        ICLPool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        require((zeroForOne && tokenOut == pool.token1()) || (!zeroForOne && tokenOut == pool.token0()), "unsupported pair");

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            bytes("")
        );

        amountOut = zeroForOne ? uint256(-amount1Delta) : uint256(-amount0Delta);
        require(amountOut >= minAmountOut, "SlipstreamCommon: insufficient output");
    }

    /**
     * @notice Securely pulls tokens using balance-delta accounting (L-GAPS-9/10 / ISecurePullErrors).
     * @dev Measures `observedDelta = balanceAfter - balanceBefore` over the pull window.
     *      - `!pretransferred`: transferFrom, return observedDelta (FoT-safe).
     *      - `pretransferred`: no in-call transfer; credit exactly `amountIn` only when
     *        `amountIn <= observedDelta`; otherwise revert
     *        `TransferDeltaInsufficient(claimed, observedDelta)`.
     *        Absolute `balanceOf >= claimed` without a positive in-window delta is forbidden
     *        (blocks free inventory credit / I1).
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 balBefore = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        }
        uint256 observedDelta = tokenIn.balanceOf(address(this)) - balBefore;
        if (pretransferred) {
            if (amountIn > observedDelta) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, observedDelta);
            }
            // Credit exactly claimed; surplus delta is not credited (no exact-delta grief).
            return amountIn;
        }
        // !pretransferred: FoT-safe — return actual inbound delta (may be < claimed).
        return observedDelta;
    }
}
