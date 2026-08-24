// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
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
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";

/**
 * @title UniswapV3StandardExchangeCommon
 * @notice Shared bound-pool ops, full-range center book, D9 totals, sleeve rebalance, dual-join helpers.
 * @dev Gate is bound-pool `slot0.unlocked` (true = idle). Do not `mint`/`burn`/`swap`/`collect` while locked.
 *      Organic ticks are Crane V3 min/max usable. Imported books keep NFT ticks as the single center.
 */
abstract contract UniswapV3StandardExchangeCommon is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ISecurePullErrors
{
    using BetterSafeERC20 for IERC20;

    error UniswapV3Exchange_CallbackNotAuthorized();
    error UniswapV3Exchange_UnsupportedPair();
    error UniswapV3Exchange_InsufficientOutput();
    error UniswapV3Exchange_ZeroAmount();
    /// @notice Path requires a bound-pool op while `slot0.unlocked == false`.
    error UniswapV3Exchange_BoundPoolInteractionBlocked();
    /// @notice Blocked amount-out cannot be covered by free local inventory of `token`.
    error UniswapV3Exchange_InsufficientLocalReserve(address token, uint256 requested, uint256 available);

    /// @dev Relative deadband: 5% of target free (D22).
    uint256 internal constant LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18;
    /// @dev Sink for residual first-mint dead shares (A0). Not `address(this)` so self-balance stays 0.
    address internal constant DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD);

    function _requireNotDisabled() internal view {
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    struct ManagedTicks {
        int24 centerLower;
        int24 centerUpper;
    }

    struct ManagedLiquidityPlan {
        uint128 centerLiquidity;
        uint256 amount0Used;
        uint256 amount1Used;
    }

    struct RebalanceSnap {
        uint256 liquidPct;
        uint256 free0;
        uint256 free1;
        uint256 deployed0;
        uint256 deployed1;
        uint256 target0;
        uint256 target1;
    }

    function _pool() internal view returns (IUniswapV3Pool) {
        return UniswapV3PoolAwareRepo._uniswapV3Pool();
    }

    function _token0() internal view returns (address) {
        return _pool().token0();
    }

    function _token1() internal view returns (address) {
        return _pool().token1();
    }

    /**
     * @notice True when this vault may open bound-pool `mint` / `burn` / `swap` / `collect`.
     * @dev D1: `canOpenBoundPoolOps() := pool.slot0().unlocked`. Opposite polarity of V4 `isUnlocked`.
     */
    function canOpenBoundPoolOps() public view virtual returns (bool) {
        (,,,,,, bool unlocked) = _pool().slot0();
        return unlocked;
    }

    function _requireCanOpenBoundPoolOps() internal view {
        if (!canOpenBoundPoolOps()) {
            revert UniswapV3Exchange_BoundPoolInteractionBlocked();
        }
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

    function _freeBalances() internal view returns (uint256 free0, uint256 free1) {
        free0 = IERC20(_token0()).balanceOf(address(this));
        free1 = IERC20(_token1()).balanceOf(address(this));
    }

    function _deployedAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        return _positionAmounts(sqrtPriceX96);
    }

    function _liveLiquidReservePercentage() internal view returns (uint256) {
        return VaultFeeOracleQueryAwareRepo._feeOracle().liquidReservePercentageOfVault(address(this));
    }

    function _targetFree(uint256 total_i, uint256 liquidPct) internal pure returns (uint256) {
        return (total_i * liquidPct) / ONE_WAD;
    }

    function _absoluteFloor(address token) internal view returns (uint256) {
        uint8 decimals_;
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            decimals_ = d;
        } catch {
            decimals_ = 18;
        }
        if (decimals_ <= 6) {
            return 1;
        }
        return 10 ** uint256(decimals_ - 6);
    }

    function _shouldRebalanceToken(uint256 free_i, uint256 targetFree_i, uint256 floor_i) internal pure returns (bool) {
        if (targetFree_i == 0) {
            return free_i > floor_i;
        }
        uint256 deviation = free_i > targetFree_i ? free_i - targetFree_i : targetFree_i - free_i;
        uint256 relativeTol = (targetFree_i * LIQUID_RESERVE_RELATIVE_TOL_WAD) / ONE_WAD;
        uint256 tol = floor_i > relativeTol ? floor_i : relativeTol;
        return deviation > tol;
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

    function _getPositionLiquidityFromPool() internal view returns (uint128 liquidity_) {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return 0;
        }
        (liquidity_,,,,) = _pool().positions(UniswapV3VaultRepo._getOwnPositionKey());
    }

    function _positionAmounts(uint160 sqrtPriceX96) internal view returns (uint256 amount0, uint256 amount1) {
        uint128 liquidity = _getPositionLiquidityFromPool();
        if (liquidity == 0) {
            return (0, 0);
        }
        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidity);
    }

    /**
     * @dev Total reserves = free ERC-20 balances + deployed center amounts (D9).
     *      Do not add `tokensOwed` on top of `balanceOf` after collect has moved them to free.
     */
    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        reserve0 = free0 + deployed0;
        reserve1 = free1 + deployed1;
    }

    /**
     * @dev Share mint/burn view SoT (D9 + D24). Idle: D9 plus collectable center fees
     *      (stored `tokensOwed` plus unpoked feeGrowthInside). Matches post-`_collectManagedFees` D9.
     *      Blocked: D9 only (cannot collect).
     */
    function _totalVaultReservesForShareMath() internal view returns (uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1) = _totalVaultReserves();
        if (!canOpenBoundPoolOps()) {
            return (reserve0, reserve1);
        }
        (uint256 owed0, uint256 owed1) = _collectableCenterFees();
        reserve0 += owed0;
        reserve1 += owed1;
    }

    function _freeBalancesForShareMath() internal view returns (uint256 free0, uint256 free1) {
        (free0, free1) = _freeBalances();
        if (!canOpenBoundPoolOps()) {
            return (free0, free1);
        }
        (uint256 owed0, uint256 owed1) = _collectableCenterFees();
        free0 += owed0;
        free1 += owed1;
    }

    /// @dev Collectable center fees: stored owed plus unpoked growth (Crane PositionValue `_fees`).
    function _collectableCenterFees() internal view returns (uint256 owed0, uint256 owed1) {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return (0, 0);
        }
        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = _pool().positions(UniswapV3VaultRepo._getOwnPositionKey());
        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        (uint256 growthInside0, uint256 growthInside1) = _feeGrowthInside(tickLower, tickUpper);
        unchecked {
            owed0 = FullMath.mulDiv(
                growthInside0 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed0;
            owed1 = FullMath.mulDiv(
                growthInside1 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed1;
        }
    }

    /// @dev Uniswap V3 `Position.getFeeGrowthInside` / Crane PositionValue `_getFeeGrowthInside`.
    function _feeGrowthInside(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        IUniswapV3Pool pool = _pool();
        (, int24 tickCurrent,,,,,) = pool.slot0();
        uint256 lower0;
        uint256 lower1;
        uint256 upper0;
        uint256 upper1;
        {
            (,, lower0, lower1,,,,) = pool.ticks(tickLower);
        }
        {
            (,, upper0, upper1,,,,) = pool.ticks(tickUpper);
        }
        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lower0 - upper0;
                feeGrowthInside1X128 = lower1 - upper1;
            } else if (tickCurrent < tickUpper) {
                feeGrowthInside0X128 = pool.feeGrowthGlobal0X128() - lower0 - upper0;
                feeGrowthInside1X128 = pool.feeGrowthGlobal1X128() - lower1 - upper1;
            } else {
                feeGrowthInside0X128 = upper0 - lower0;
                feeGrowthInside1X128 = upper1 - lower1;
            }
        }
    }

    function _syncVaultReserves() internal {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token0()), reserve0);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token1()), reserve1);
        MultiAssetBasicVaultRepo._updateReserve(
            IERC20(address(this)), IERC20(address(this)).balanceOf(address(this))
        );
    }

    function _managedTicks() internal view returns (ManagedTicks memory managedTicks) {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return _deriveManagedTicks();
        }
        (managedTicks.centerLower, managedTicks.centerUpper) = UniswapV3VaultRepo._getPositionTicks();
    }

    /// @dev D30: one full-range center. `widthMultiplier` does not size ticks. Import uses stored NFT ticks.
    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        int24 tickSpacing = _pool().tickSpacing();
        managedTicks.centerLower = TickMath.minUsableTick(tickSpacing);
        managedTicks.centerUpper = TickMath.maxUsableTick(tickSpacing);
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
        _setCenterPlan(plan, managedTicks, sqrtPriceX96, available0, available1);
    }

    function _setCenterPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        uint256 budget0,
        uint256 budget1
    ) internal pure {
        plan.centerLiquidity = UniswapV3Utils._quoteLiquidityForAmounts(
            sqrtPriceX96, managedTicks.centerLower, managedTicks.centerUpper, budget0, budget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity
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
        return _quotePositionWithdrawal(sqrtPriceX96, sharesBurned, totalShares);
    }

    function _quotePositionWithdrawal(uint160 sqrtPriceX96, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint128 currentLiquidity = _getPositionLiquidityFromPool();
        if (currentLiquidity == 0 || totalShares == 0) {
            return (0, 0);
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tickLower, tickUpper, liquidityToBurn);
    }

    function _updateManagedPositionLiquidities() internal {
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }
        UniswapV3VaultRepo._updatePositionLiquidity(_getPositionLiquidityFromPool());
    }

    function _collectManagedFees() internal {
        _requireCanOpenBoundPoolOps();
        if (!UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        IUniswapV3Pool pool = _pool();
        uint128 liquidity = _getPositionLiquidityFromPool();
        if (liquidity > 0) {
            pool.burn(tickLower, tickUpper, 0);
        }
        pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
    }

    function _collectIfIdle() internal {
        if (canOpenBoundPoolOps() && UniswapV3VaultRepo._isPositionCreated()) {
            _collectManagedFees();
        }
    }

    function _swapExactOut(address tokenIn, address tokenOut, uint256 amountOut, uint256 maxAmountIn, address recipient)
        internal
        returns (uint256 amountIn)
    {
        _requireCanOpenBoundPoolOps();
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

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address recipient)
        internal
        returns (uint256 amountOut)
    {
        _requireCanOpenBoundPoolOps();
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
        _requireCanOpenBoundPoolOps();
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

    function _burnAndCollectLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidityToBurn)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        _requireCanOpenBoundPoolOps();
        IUniswapV3Pool pool = _pool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));

        pool.burn(tickLower, tickUpper, liquidityToBurn);
        pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);

        amount0 = IERC20(token0).balanceOf(address(this)) - bal0Before;
        amount1 = IERC20(token1).balanceOf(address(this)) - bal1Before;
    }

    function _mintManagedLiquidity(ManagedTicks memory managedTicks, ManagedLiquidityPlan memory plan) internal {
        if (plan.centerLiquidity > 0) {
            _mintLiquidity(address(this), managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity);
        }
    }

    function _createOrganicPositionsIfNeeded(ManagedTicks memory managedTicks) internal {
        if (UniswapV3VaultRepo._isPositionCreated()) {
            return;
        }
        UniswapV3VaultRepo._createPositionIfNeeded(managedTicks.centerLower, managedTicks.centerUpper);
    }

    function _sharesOutForDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 totalSharesBefore,
        uint256 reserve0Before,
        uint256 reserve1Before
    ) internal pure returns (uint256 sharesOut) {
        if (amount0Added == 0 && amount1Added == 0) {
            return 0;
        }
        if (totalSharesBefore == 0) {
            return amount0Added + amount1Added;
        }
        if (amount0Added > 0 && amount1Added == 0) {
            if (reserve0Before == 0) {
                return amount0Added;
            }
            return (amount0Added * totalSharesBefore) / reserve0Before;
        }
        if (amount1Added > 0 && amount0Added == 0) {
            if (reserve1Before == 0) {
                return amount1Added;
            }
            return (amount1Added * totalSharesBefore) / reserve1Before;
        }
        return
            ConstProdUtils._depositQuote(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
    }

    function _rebalanceLiquidReserveBestEffort() internal {
        if (!canOpenBoundPoolOps()) {
            return;
        }
        _rebalanceLiquidReserveInternal();
    }

    function _loadRebalanceSnap() internal view returns (RebalanceSnap memory s) {
        s.liquidPct = _liveLiquidReservePercentage();
        (s.free0, s.free1) = _freeBalances();
        (s.deployed0, s.deployed1) = _deployedAmounts();
        s.target0 = _targetFree(s.free0 + s.deployed0, s.liquidPct);
        s.target1 = _targetFree(s.free1 + s.deployed1, s.liquidPct);
    }

    function _rebalanceLiquidReserveInternal() internal returns (bool moved) {
        RebalanceSnap memory s = _loadRebalanceSnap();
        uint256 floor0 = _absoluteFloor(_token0());
        uint256 floor1 = _absoluteFloor(_token1());

        if (!_shouldRebalanceToken(s.free0, s.target0, floor0) && !_shouldRebalanceToken(s.free1, s.target1, floor1)) {
            return false;
        }

        {
            uint256 excess0 = s.free0 > s.target0 ? s.free0 - s.target0 : 0;
            uint256 excess1 = s.free1 > s.target1 ? s.free1 - s.target1 : 0;
            if ((excess0 > 0 || excess1 > 0) && _deployExcessLiquidity(excess0, excess1)) {
                moved = true;
            }
        }

        s = _loadRebalanceSnap();
        {
            uint256 needFree0 = s.free0 < s.target0 ? s.target0 - s.free0 : 0;
            uint256 needFree1 = s.free1 < s.target1 ? s.target1 - s.free1 : 0;
            if ((needFree0 > 0 || needFree1 > 0) && (s.deployed0 > 0 || s.deployed1 > 0)) {
                if (_refillDeficitLiquidity(needFree0, needFree1, s.deployed0, s.deployed1)) {
                    moved = true;
                }
            }
        }

        if (moved && canOpenBoundPoolOps()) {
            s = _loadRebalanceSnap();
            uint256 excess0 = s.free0 > s.target0 ? s.free0 - s.target0 : 0;
            uint256 excess1 = s.free1 > s.target1 ? s.free1 - s.target1 : 0;
            if (
                (_shouldRebalanceToken(s.free0, s.target0, floor0) && excess0 > 0)
                    || (_shouldRebalanceToken(s.free1, s.target1, floor1) && excess1 > 0)
            ) {
                _deployExcessLiquidity(excess0, excess1);
            }
        }

        if (moved) {
            _emitRebalanceEvent(_liveLiquidReservePercentage());
        }
    }

    function _emitRebalanceEvent(uint256 liquidPct) internal {
        _updateManagedPositionLiquidities();
        _syncVaultReserves();
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        emit IUniswapV3StandardExchangeLiquidReserve.LiquidReserveRebalanced(
            free0, free1, deployed0, deployed1, liquidPct
        );
    }

    function _deployExcessLiquidity(uint256 excess0, uint256 excess1) internal returns (bool moved) {
        if (excess0 == 0 && excess1 == 0) {
            return false;
        }
        (uint256 free0, uint256 free1) = _freeBalances();
        if (excess0 > free0) excess0 = free0;
        if (excess1 > free1) excess1 = free1;
        if (excess0 == 0 && excess1 == 0) {
            return false;
        }

        ManagedTicks memory managedTicks =
            UniswapV3VaultRepo._isPositionCreated() ? _managedTicks() : _deriveManagedTicks();
        _createOrganicPositionsIfNeeded(managedTicks);

        ManagedLiquidityPlan memory plan = _managedLiquidityPlan(managedTicks, excess0, excess1);
        if (plan.centerLiquidity == 0) {
            return false;
        }

        _mintManagedLiquidity(managedTicks, plan);
        _updateManagedPositionLiquidities();
        return true;
    }

    function _refillDeficitLiquidity(uint256 need0, uint256 need1, uint256 deployed0, uint256 deployed1)
        internal
        returns (bool moved)
    {
        uint256 fracWad;
        if (need0 > 0 && deployed0 > 0) {
            uint256 f0 = (need0 * ONE_WAD) / deployed0;
            if (f0 > fracWad) fracWad = f0;
        }
        if (need1 > 0 && deployed1 > 0) {
            uint256 f1 = (need1 * ONE_WAD) / deployed1;
            if (f1 > fracWad) fracWad = f1;
        }
        if (fracWad == 0) {
            return false;
        }
        if (fracWad > ONE_WAD) {
            fracWad = ONE_WAD;
        }

        uint256 scale = 1e18;
        uint256 burnShares = (fracWad * scale) / ONE_WAD;
        if (burnShares == 0) {
            burnShares = 1;
        }

        uint128 currentLiquidity = _getPositionLiquidityFromPool();
        if (currentLiquidity == 0) {
            return false;
        }
        uint128 liquidityToBurn = uint128((uint256(currentLiquidity) * burnShares) / scale);
        if (liquidityToBurn == 0) {
            return false;
        }
        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        _burnAndCollectLiquidity(tickLower, tickUpper, liquidityToBurn);
        _updateManagedPositionLiquidities();
        return true;
    }

    function _burnCenterLiquidityForShares(uint256 sharesBurned, uint256 totalShares) internal {
        if (sharesBurned == 0 || totalShares == 0) {
            return;
        }
        uint128 currentLiquidity = _getPositionLiquidityFromPool();
        if (currentLiquidity == 0) {
            return;
        }
        uint128 liquidityToBurn = uint128((uint256(currentLiquidity) * sharesBurned) / totalShares);
        if (liquidityToBurn == 0) {
            return;
        }
        (int24 tickLower, int24 tickUpper) = UniswapV3VaultRepo._getPositionTicks();
        _burnAndCollectLiquidity(tickLower, tickUpper, liquidityToBurn);
        _updateManagedPositionLiquidities();
    }

    /// @dev Separate frame so zap-out `_swap` does not hit stack-too-deep.
    function _swapRemovedOtherPlusFreeShare(
        address otherToken,
        address tokenOut,
        uint256 freePortionOther,
        uint256 otherBefore
    ) internal {
        uint256 removedOther = IERC20(otherToken).balanceOf(address(this)) - otherBefore;
        uint256 otherForUser = removedOther + freePortionOther;
        uint256 otherBal = IERC20(otherToken).balanceOf(address(this));
        if (otherForUser > otherBal) otherForUser = otherBal;
        if (otherForUser > 0) {
            _swap(otherToken, tokenOut, otherForUser, 0, address(this));
        }
    }

    function _actualOutPlusFreeShare(address tokenOut, uint256 outBefore, uint256 freeOutShare)
        internal
        view
        returns (uint256 actualOut)
    {
        actualOut = (IERC20(tokenOut).balanceOf(address(this)) - outBefore) + freeOutShare;
        uint256 bal = IERC20(tokenOut).balanceOf(address(this));
        if (actualOut > bal) actualOut = bal;
    }

    function _isDualPoolCurrencies(address[] calldata tokens) internal view returns (bool) {
        if (tokens.length != 2) {
            return false;
        }
        if (tokens[0] >= tokens[1]) {
            return false;
        }
        return tokens[0] == _token0() && tokens[1] == _token1();
    }

    function _dualAmountsPositive(uint256[] calldata amounts) internal pure returns (bool) {
        return amounts.length == 2 && amounts[0] > 0 && amounts[1] > 0;
    }

    function _dualExitShareBurns(
        uint256 amount0,
        uint256 amount1,
        uint256 total0,
        uint256 total1,
        uint256 supply
    ) internal pure returns (uint256 s0, uint256 s1) {
        if (total0 == 0 || total1 == 0 || supply == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }
        s0 = FullMath.mulDivRoundingUp(amount0, supply, total0);
        s1 = FullMath.mulDivRoundingUp(amount1, supply, total1);
    }

    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            return tokenIn.balanceOf(address(this)) - B0;
        }
        uint256 deployed = _deployedFaceOf(address(tokenIn));
        uint256 faceBooked = R > deployed ? R - deployed : 0;
        uint256 U = B0 > faceBooked ? B0 - faceBooked : 0;
        if (amountIn > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
        }
        return amountIn;
    }

    function _deployedFaceOf(address token_) internal view returns (uint256 deployed_) {
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        if (token_ == _token0()) return deployed0;
        if (token_ == _token1()) return deployed1;
        return 0;
    }

    function _transferCurrency(address token, address recipient, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        IERC20(token).safeTransfer(recipient, amount);
    }

    function _secureShareDelivery(uint256 amountIn, bool pretransferred) internal returns (uint256 actualIn) {
        IERC20 vaultShare = IERC20(address(this));
        uint256 b0 = vaultShare.balanceOf(address(this));
        if (!pretransferred) {
            vaultShare.safeTransferFrom(msg.sender, address(this), amountIn);
            return vaultShare.balanceOf(address(this)) - b0;
        }
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(this));
        uint256 U = b0 > R ? b0 - R : 0;
        if (amountIn > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
        }
        return amountIn;
    }

    function _refundUnusedShares(uint256 delivered, uint256 used, address recipient) internal {
        if (delivered > used) {
            IERC20(address(this)).safeTransfer(recipient, delivered - used);
        }
    }
}
