// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {UniswapV3Utils} from "@crane/contracts/utils/math/UniswapV3Utils.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";

/**
 * @title UniswapV3StandardExchangeCommon
 * @notice Shared pool ops, callbacks, liquidity strategy, and valuation for Uni V3 SE.
 */
abstract contract UniswapV3StandardExchangeCommon is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using BetterSafeERC20 for IERC20;

    error UniswapV3Exchange_CallbackNotAuthorized();
    error UniswapV3Exchange_UnsupportedPair();
    error UniswapV3Exchange_InsufficientOutput();
    error UniswapV3Exchange_ZeroAmount();

    function _requireNotDisabled() internal view {
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

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

    function _pool() internal view returns (IUniswapV3Pool) {
        return UniswapV3PoolAwareRepo._uniswapV3Pool();
    }

    function _requireBoundPoolCaller() internal view {
        if (msg.sender != address(_pool())) {
            revert UniswapV3Exchange_CallbackNotAuthorized();
        }
    }

    /// @inheritdoc IUniswapV3MintCallback
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external override {
        _requireBoundPoolCaller();
        IUniswapV3Pool pool = _pool();
        if (amount0Owed > 0) {
            IERC20(pool.token0()).safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(pool.token1()).safeTransfer(msg.sender, amount1Owed);
        }
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        _requireBoundPoolCaller();
        IUniswapV3Pool pool = _pool();
        if (amount0Delta > 0) {
            IERC20(pool.token0()).safeTransfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(pool.token1()).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    function _loadPoolState()
        internal
        view
        returns (address token0, address token1, uint160 sqrtPriceX96, int24 tick, uint24 fee)
    {
        IUniswapV3Pool pool = _pool();
        token0 = pool.token0();
        token1 = pool.token1();
        (sqrtPriceX96, tick,,,,,) = pool.slot0();
        fee = pool.fee();
    }

    function _quoteSwap(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }

        IUniswapV3Pool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if ((zeroForOne && tokenOut != pool.token1()) || (!zeroForOne && tokenOut != pool.token0())) {
            return 0;
        }

        UniswapV3Quoter.SwapQuoteResult memory quote = UniswapV3Quoter.quoteExactInput(
            UniswapV3Quoter.SwapQuoteParams({
                pool: pool,
                zeroForOne: zeroForOne,
                amount: amountIn,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                maxSteps: 0
            })
        );

        return quote.amountOut;
    }

    function _quoteSwapOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        virtual
        returns (uint256 amountIn)
    {
        if (amountOut == 0) {
            return 0;
        }

        IUniswapV3Pool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if ((zeroForOne && tokenOut != pool.token1()) || (!zeroForOne && tokenOut != pool.token0())) {
            return 0;
        }

        UniswapV3Quoter.SwapQuoteResult memory quote = UniswapV3Quoter.quoteExactOutput(
            UniswapV3Quoter.SwapQuoteParams({
                pool: pool,
                zeroForOne: zeroForOne,
                amount: amountOut,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                maxSteps: 0
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
        return UniswapV3Utils._quoteAmountsForLiquidity(sqrtPriceX96, tickLower, tickUpper, liquidity);
    }

    function _getPositionLiquidityFromPool(UniswapV3VaultRepo.PositionKind kind_)
        internal
        view
        returns (uint128 liquidity_)
    {
        if (!UniswapV3VaultRepo._isPositionCreated(kind_)) {
            return 0;
        }
        (liquidity_,,,,) = _pool().positions(UniswapV3VaultRepo._getOwnPositionKey(kind_));
    }

    function _positionAmounts(UniswapV3VaultRepo.PositionKind kind_, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint128 liquidity = _getPositionLiquidityFromPool(kind_);
        if (liquidity == 0) {
            return (0, 0);
        }
        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks(kind_);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidity);
    }

    function _tokensOwed(UniswapV3VaultRepo.PositionKind kind_)
        internal
        view
        returns (uint128 tokensOwed0, uint128 tokensOwed1)
    {
        if (!UniswapV3VaultRepo._isPositionCreated(kind_)) {
            return (0, 0);
        }
        (,,, tokensOwed0, tokensOwed1) = _pool().positions(UniswapV3VaultRepo._getOwnPositionKey(kind_));
    }

    /// @notice Managed liquidity + collectable fees (does not double-count free inventory).
    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return (0, 0);
        }

        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        (reserve0, reserve1) = _positionAmounts(UniswapV3VaultRepo.PositionKind.Center, sqrtPriceX96);
        {
            (uint256 a0, uint256 a1) = _positionAmounts(UniswapV3VaultRepo.PositionKind.LowerWing, sqrtPriceX96);
            reserve0 += a0;
            reserve1 += a1;
        }
        {
            (uint256 a0, uint256 a1) = _positionAmounts(UniswapV3VaultRepo.PositionKind.UpperWing, sqrtPriceX96);
            reserve0 += a0;
            reserve1 += a1;
        }
        reserve0 += _tokensOwed0Sum();
        reserve1 += _tokensOwed1Sum();
    }

    function _tokensOwed0Sum() internal view returns (uint256 sum) {
        (uint128 c0,) = _tokensOwed(UniswapV3VaultRepo.PositionKind.Center);
        (uint128 l0,) = _tokensOwed(UniswapV3VaultRepo.PositionKind.LowerWing);
        (uint128 u0,) = _tokensOwed(UniswapV3VaultRepo.PositionKind.UpperWing);
        sum = uint256(c0) + uint256(l0) + uint256(u0);
    }

    function _tokensOwed1Sum() internal view returns (uint256 sum) {
        (, uint128 c1) = _tokensOwed(UniswapV3VaultRepo.PositionKind.Center);
        (, uint128 l1) = _tokensOwed(UniswapV3VaultRepo.PositionKind.LowerWing);
        (, uint128 u1) = _tokensOwed(UniswapV3VaultRepo.PositionKind.UpperWing);
        sum = uint256(c1) + uint256(l1) + uint256(u1);
    }

    /// @notice Full vault value including free working inventory (post-collect free tokens).
    function _totalVaultValue() internal view returns (uint256 value0, uint256 value1) {
        (value0, value1) = _totalVaultReserves();
        IUniswapV3Pool pool = _pool();
        value0 += IERC20(pool.token0()).balanceOf(address(this));
        value1 += IERC20(pool.token1()).balanceOf(address(this));
    }

    function _managedTicks() internal view returns (ManagedTicks memory managedTicks) {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return _deriveManagedTicks();
        }

        (managedTicks.centerLower, managedTicks.centerUpper) =
            UniswapV3VaultRepo._getPositionTicks(UniswapV3VaultRepo.PositionKind.Center);
        (managedTicks.lowerWingLower, managedTicks.lowerWingUpper) =
            UniswapV3VaultRepo._getPositionTicks(UniswapV3VaultRepo.PositionKind.LowerWing);
        (managedTicks.upperWingLower, managedTicks.upperWingUpper) =
            UniswapV3VaultRepo._getPositionTicks(UniswapV3VaultRepo.PositionKind.UpperWing);
    }

    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        IUniswapV3Pool pool = _pool();
        (, int24 currentTick,,,,,) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();
        int24 outerHalfWidth = int24(uint24(UniswapV3VaultRepo._widthMultiplier())) * tickSpacing / 2;
        int24 centerHalfWidth = int24(uint24(UniswapV3VaultRepo._centerWidthMultiplier())) * tickSpacing / 2;

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
        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        return _managedLiquidityPlanAtState(managedTicks, available0, available1, sqrtPriceX96);
    }

    function _managedLiquidityPlanAtState(
        ManagedTicks memory managedTicks,
        uint256 available0,
        uint256 available1,
        uint160 sqrtPriceX96
    ) internal view returns (ManagedLiquidityPlan memory plan) {
        ManagedLiquidityBudgets memory budgets = _managedLiquidityBudgets(available0, available1);
        // After import, only center is created — never plan wings that are not created.
        bool wingsLive = UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.LowerWing)
            || UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.UpperWing);
        bool firstOrganic = !UniswapV3VaultRepo._isPositionCreated();

        if (firstOrganic || UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.Center)) {
            _setCenterPlan(plan, managedTicks, sqrtPriceX96, budgets);
        }
        if (firstOrganic || wingsLive) {
            if (firstOrganic || UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.LowerWing)) {
                _setLowerWingPlan(plan, managedTicks, sqrtPriceX96, budgets);
            }
            if (firstOrganic || UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.UpperWing)) {
                _setUpperWingPlan(plan, managedTicks, sqrtPriceX96, budgets);
            }
        }
    }

    function _managedLiquidityBudgets(uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityBudgets memory budgets)
    {
        // Center-only (post-import): allocate full budgets to center.
        bool wingsLive = UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.LowerWing)
            || UniswapV3VaultRepo._isPositionCreated(UniswapV3VaultRepo.PositionKind.UpperWing);
        bool firstOrganic = !UniswapV3VaultRepo._isPositionCreated();
        if (!firstOrganic && !wingsLive) {
            budgets.centerBudget0 = available0;
            budgets.centerBudget1 = available1;
            return budgets;
        }

        budgets.centerBudget0 = (available0 * UniswapV3VaultRepo._activeLiquidityBps()) / 10_000;
        budgets.centerBudget1 = (available1 * UniswapV3VaultRepo._activeLiquidityBps()) / 10_000;
        budgets.upperWingBudget0 = available0 - budgets.centerBudget0;
        budgets.lowerWingBudget1 = available1 - budgets.centerBudget1;
    }

    function _setCenterPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.centerLiquidity = UniswapV3Utils._quoteLiquidityForAmounts(
            sqrtPriceX96, managedTicks.centerLower, managedTicks.centerUpper, budgets.centerBudget0, budgets.centerBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity
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
        plan.lowerWingLiquidity = UniswapV3Utils._quoteLiquidityForAmounts(
            sqrtPriceX96, managedTicks.lowerWingLower, managedTicks.lowerWingUpper, 0, budgets.lowerWingBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, managedTicks.lowerWingLower, managedTicks.lowerWingUpper, plan.lowerWingLiquidity
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
        plan.upperWingLiquidity = UniswapV3Utils._quoteLiquidityForAmounts(
            sqrtPriceX96, managedTicks.upperWingLower, managedTicks.upperWingUpper, budgets.upperWingBudget0, 0
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, managedTicks.upperWingLower, managedTicks.upperWingUpper, plan.upperWingLiquidity
        );
        plan.amount0Used += amount0;
        plan.amount1Used += amount1;
    }

    function _quoteManagedWithdrawal(uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        (uint256 center0, uint256 center1) =
            _quotePositionWithdrawal(sqrtPriceX96, UniswapV3VaultRepo.PositionKind.Center, sharesBurned, totalShares);
        (uint256 lower0, uint256 lower1) = _quotePositionWithdrawal(
            sqrtPriceX96, UniswapV3VaultRepo.PositionKind.LowerWing, sharesBurned, totalShares
        );
        (uint256 upper0, uint256 upper1) = _quotePositionWithdrawal(
            sqrtPriceX96, UniswapV3VaultRepo.PositionKind.UpperWing, sharesBurned, totalShares
        );

        amount0 = center0 + lower0 + upper0;
        amount1 = center1 + lower1 + upper1;
    }

    function _quotePositionWithdrawal(
        uint160 sqrtPriceX96,
        UniswapV3VaultRepo.PositionKind kind_,
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

        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks(kind_);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidityToBurn);
    }

    function _updateManagedPositionLiquidities() internal {
        _updatePositionLiquidityFromPool(UniswapV3VaultRepo.PositionKind.Center);
        _updatePositionLiquidityFromPool(UniswapV3VaultRepo.PositionKind.LowerWing);
        _updatePositionLiquidityFromPool(UniswapV3VaultRepo.PositionKind.UpperWing);
    }

    function _updatePositionLiquidityFromPool(UniswapV3VaultRepo.PositionKind kind_) internal {
        if (!UniswapV3VaultRepo._isPositionCreated(kind_)) {
            return;
        }
        UniswapV3VaultRepo._updatePositionLiquidity(kind_, _getPositionLiquidityFromPool(kind_));
    }

    function _collectManagedFees() internal {
        _collectPositionFees(UniswapV3VaultRepo.PositionKind.Center);
        _collectPositionFees(UniswapV3VaultRepo.PositionKind.LowerWing);
        _collectPositionFees(UniswapV3VaultRepo.PositionKind.UpperWing);
    }

    function _collectPositionFees(UniswapV3VaultRepo.PositionKind kind_) internal {
        if (!UniswapV3VaultRepo._isPositionCreated(kind_)) {
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks(kind_);
        IUniswapV3Pool pool = _pool();
        // Uni V3 reverts `NP` on burn(0) when the pool position has never held liquidity.
        uint128 liquidity = _getPositionLiquidityFromPool(kind_);
        if (liquidity > 0) {
            pool.burn(tickLower, tickUpper, 0);
        }
        pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
    }

    /// @dev Exact-out pool swap: amountSpecified is negative (output amount).
    function _swapExactOut(address tokenIn, address tokenOut, uint256 amountOut, uint256 maxAmountIn, address recipient)
        internal
        returns (uint256 amountIn)
    {
        IUniswapV3Pool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if (!((zeroForOne && tokenOut == pool.token1()) || (!zeroForOne && tokenOut == pool.token0()))) {
            revert UniswapV3Exchange_UnsupportedPair();
        }
        if (amountOut == 0) {
            return 0;
        }

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            recipient,
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            bytes("")
        );

        amountIn = zeroForOne ? uint256(amount0Delta) : uint256(amount1Delta);
        if (amountIn > maxAmountIn) {
            revert UniswapV3Exchange_InsufficientOutput();
        }
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
        IUniswapV3Pool pool = _pool();
        bool zeroForOne = tokenIn == pool.token0();
        if (!((zeroForOne && tokenOut == pool.token1()) || (!zeroForOne && tokenOut == pool.token0()))) {
            revert UniswapV3Exchange_UnsupportedPair();
        }
        if (amountIn == 0) {
            return 0;
        }

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            bytes("")
        );

        amountOut = zeroForOne ? uint256(-amount1Delta) : uint256(-amount0Delta);
        if (amountOut < minAmountOut) {
            revert UniswapV3Exchange_InsufficientOutput();
        }
    }

    function _mintLiquidity(address recipient, int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        returns (uint256 amount0Used, uint256 amount1Used)
    {
        if (liquidity == 0) {
            return (0, 0);
        }
        IUniswapV3Pool pool = _pool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));

        pool.mint(recipient, tickLower, tickUpper, liquidity, bytes(""));

        amount0Used = bal0Before - IERC20(token0).balanceOf(address(this));
        amount1Used = bal1Before - IERC20(token1).balanceOf(address(this));
    }

    function _mintManagedLiquidity(ManagedTicks memory managedTicks, ManagedLiquidityPlan memory plan) internal {
        if (plan.centerLiquidity > 0) {
            _mintLiquidity(address(this), managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity);
        }
        if (plan.lowerWingLiquidity > 0) {
            _mintLiquidity(
                address(this), managedTicks.lowerWingLower, managedTicks.lowerWingUpper, plan.lowerWingLiquidity
            );
        }
        if (plan.upperWingLiquidity > 0) {
            _mintLiquidity(
                address(this), managedTicks.upperWingLower, managedTicks.upperWingUpper, plan.upperWingLiquidity
            );
        }
    }

    function _createOrganicPositionsIfNeeded(ManagedTicks memory managedTicks) internal {
        if (UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }
        UniswapV3VaultRepo._createPositionIfNeeded(
            UniswapV3VaultRepo.PositionKind.Center, managedTicks.centerLower, managedTicks.centerUpper
        );
        UniswapV3VaultRepo._createPositionIfNeeded(
            UniswapV3VaultRepo.PositionKind.LowerWing, managedTicks.lowerWingLower, managedTicks.lowerWingUpper
        );
        UniswapV3VaultRepo._createPositionIfNeeded(
            UniswapV3VaultRepo.PositionKind.UpperWing, managedTicks.upperWingLower, managedTicks.upperWingUpper
        );
    }

    /// @notice Phase A: collect fees and compound free inventory into managed liquidity (no share mint).
    function _feeFirstCompound() internal {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }
        _collectManagedFees();

        IUniswapV3Pool pool = _pool();
        uint256 available0 = IERC20(pool.token0()).balanceOf(address(this));
        uint256 available1 = IERC20(pool.token1()).balanceOf(address(this));
        if (available0 == 0 && available1 == 0) {
            return;
        }

        ManagedTicks memory managedTicks = _managedTicks();
        ManagedLiquidityPlan memory plan = _managedLiquidityPlan(managedTicks, available0, available1);
        _mintManagedLiquidity(managedTicks, plan);
        _updateManagedPositionLiquidities();
    }
}
