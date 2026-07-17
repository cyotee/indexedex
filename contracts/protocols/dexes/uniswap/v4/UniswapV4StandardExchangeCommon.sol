// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {SafeCast} from "@crane/contracts/external/openzeppelin-contracts/utils/math/SafeCast.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {UniswapV4PoolManagerAwareRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol";
import {UniswapV4PoolKeyAwareRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {UniswapV4QuoteService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol";

abstract contract UniswapV4StandardExchangeCommon is IUnlockCallback {
    using BetterSafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;

    /// @dev Separate frame to avoid stack-too-deep in exchangeIn/Out dispatchers.
    function _requireNotDisabled() internal view {
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }
    using SafeCast for int256;
    using SafeCast for uint256;

    enum Operation {
        SwapExactIn,
        SwapExactOut,
        AddLiquidity,
        RemoveLiquidity
    }

    struct OperationParams {
        Operation op;
        bool zeroForOne;
        uint256 amountSpecified;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        bytes32 salt;
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

    error UniswapV4Exchange_InvalidCallbackCaller(address caller);
    error UniswapV4Exchange_UnsupportedRoute();
    error UniswapV4Exchange_InsufficientOutput();
    error UniswapV4Exchange_TooMuchInput();
    error UniswapV4Exchange_ZeroAmount();

    function _poolManager() internal view returns (IPoolManager) {
        return UniswapV4PoolManagerAwareRepo._poolManager();
    }

    function _poolKey() internal view returns (PoolKey memory) {
        return UniswapV4PoolKeyAwareRepo._poolKey();
    }

    function _poolId() internal view returns (PoolId) {
        return UniswapV4PoolKeyAwareRepo._poolId();
    }

    function _currency0() internal view returns (Currency) {
        return UniswapV4PoolKeyAwareRepo._currency0();
    }

    function _currency1() internal view returns (Currency) {
        return UniswapV4PoolKeyAwareRepo._currency1();
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(_currency0());
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(_currency1());
    }

    function _slot0() internal view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) {
        return StateLibrary.getSlot0(_poolManager(), _poolId());
    }

    function _positionInfo(UniswapV4PositionRepo.PositionKind kind)
        internal
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
    {
        if (UniswapV4PositionRepo._isImportedPosition()) {
            if (kind != UniswapV4PositionRepo.PositionKind.Center) {
                return (0, 0, 0);
            }
            return (UniswapV4PositionRepo._importedPositionManager().getPositionLiquidity(UniswapV4PositionRepo._importedPositionTokenId()), 0, 0);
        }

        if (!UniswapV4PositionRepo._isPositionCreated(kind)) {
            return (0, 0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        return StateLibrary.getPositionInfo(
            _poolManager(),
            _poolId(),
            address(this),
            tickLower,
            tickUpper,
            UniswapV4PositionRepo._salt(kind)
        );
    }

    function _currentLiquidity() internal view returns (uint128 liquidity) {
        liquidity = _currentLiquidity(UniswapV4PositionRepo.PositionKind.Center)
            + _currentLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing)
            + _currentLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing);
    }

    function _currentLiquidity(UniswapV4PositionRepo.PositionKind kind) internal view returns (uint128 liquidity) {
        (liquidity,,) = _positionInfo(kind);
    }

    function _refreshStoredLiquidity() internal returns (uint128 liquidity) {
        uint128 centerLiquidity = _currentLiquidity(UniswapV4PositionRepo.PositionKind.Center);
        uint128 lowerWingLiquidity = _currentLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing);
        uint128 upperWingLiquidity = _currentLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing);

        UniswapV4PositionRepo._updateLiquidity(UniswapV4PositionRepo.PositionKind.Center, centerLiquidity);
        UniswapV4PositionRepo._updateLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing, lowerWingLiquidity);
        UniswapV4PositionRepo._updateLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing, upperWingLiquidity);

        liquidity = centerLiquidity + lowerWingLiquidity + upperWingLiquidity;
    }

    function _positionAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        (uint256 centerAmount0, uint256 centerAmount1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.Center);
        (uint256 lowerWingAmount0, uint256 lowerWingAmount1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.LowerWing);
        (uint256 upperWingAmount0, uint256 upperWingAmount1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.UpperWing);

        amount0 = centerAmount0 + lowerWingAmount0 + upperWingAmount0;
        amount1 = centerAmount1 + lowerWingAmount1 + upperWingAmount1;
    }

    function _positionAmounts(UniswapV4PositionRepo.PositionKind kind) internal view returns (uint256 amount0, uint256 amount1) {
        if (!UniswapV4PositionRepo._isPositionCreated(kind)) {
            return (0, 0);
        }

        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        uint128 liquidity = _currentLiquidity(kind);
        if (liquidity == 0) {
            return (0, 0);
        }

        return _amountsForLiquidityAtPrice(sqrtPriceX96, tick, tickLower, tickUpper, liquidity);
    }

    function _amountsForLiquidityAtPrice(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) {
            return (0, 0);
        }

        amount0 = SqrtPriceMath.getAmount0Delta(
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidity,
            false
        );
        amount1 = SqrtPriceMath.getAmount1Delta(
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidity,
            false
        );

        if (tick <= tickLower) {
            amount1 = 0;
        } else if (tick >= tickUpper) {
            amount0 = 0;
        } else {
            amount0 = SqrtPriceMath.getAmount0Delta(
                sqrtPriceX96,
                TickMath.getSqrtPriceAtTick(tickUpper),
                liquidity,
                false
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower),
                sqrtPriceX96,
                liquidity,
                false
            );
        }
    }

    function _managedTicks() internal view returns (ManagedTicks memory managedTicks) {
        if (UniswapV4PositionRepo._isImportedPosition()) {
            (managedTicks.centerLower, managedTicks.centerUpper) =
                UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);
            managedTicks.lowerWingLower = managedTicks.centerLower;
            managedTicks.lowerWingUpper = managedTicks.centerLower;
            managedTicks.upperWingLower = managedTicks.centerUpper;
            managedTicks.upperWingUpper = managedTicks.centerUpper;
            return managedTicks;
        }

        if (!UniswapV4PositionRepo._isPositionCreated()) {
            return _deriveManagedTicks();
        }

        (managedTicks.centerLower, managedTicks.centerUpper) =
            UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);
        (managedTicks.lowerWingLower, managedTicks.lowerWingUpper) =
            UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.LowerWing);
        (managedTicks.upperWingLower, managedTicks.upperWingUpper) =
            UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.UpperWing);
    }

    function _managedLiquidityPlan(ManagedTicks memory managedTicks, uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityPlan memory plan)
    {
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        return _managedLiquidityPlanAtState(managedTicks, available0, available1, sqrtPriceX96, tick);
    }

    function _managedLiquidityPlanAtState(
        ManagedTicks memory managedTicks,
        uint256 available0,
        uint256 available1,
        uint160 sqrtPriceX96,
        int24 tick
    ) internal view returns (ManagedLiquidityPlan memory plan) {
        ManagedLiquidityBudgets memory budgets = _managedLiquidityBudgets(available0, available1);

        _setCenterPlan(plan, managedTicks, sqrtPriceX96, tick, budgets);
        _setLowerWingPlan(plan, managedTicks, sqrtPriceX96, tick, budgets);
        _setUpperWingPlan(plan, managedTicks, sqrtPriceX96, tick, budgets);
    }

    function _managedLiquidityBudgets(uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityBudgets memory budgets)
    {
        budgets.centerBudget0 = (available0 * UniswapV4PositionRepo._activeLiquidityBps()) / 10_000;
        budgets.centerBudget1 = (available1 * UniswapV4PositionRepo._activeLiquidityBps()) / 10_000;
        budgets.upperWingBudget0 = available0 - budgets.centerBudget0;
        budgets.lowerWingBudget1 = available1 - budgets.centerBudget1;
    }

    function _setCenterPlan(
        ManagedLiquidityPlan memory plan,
        ManagedTicks memory managedTicks,
        uint160 sqrtPriceX96,
        int24 tick,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.centerLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.centerLower),
            TickMath.getSqrtPriceAtTick(managedTicks.centerUpper),
            budgets.centerBudget0,
            budgets.centerBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            tick,
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
        int24 tick,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.lowerWingLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.lowerWingLower),
            TickMath.getSqrtPriceAtTick(managedTicks.lowerWingUpper),
            0,
            budgets.lowerWingBudget1
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            tick,
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
        int24 tick,
        ManagedLiquidityBudgets memory budgets
    ) internal pure {
        plan.upperWingLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.upperWingLower),
            TickMath.getSqrtPriceAtTick(managedTicks.upperWingUpper),
            budgets.upperWingBudget0,
            0
        );
        (uint256 amount0, uint256 amount1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96,
            tick,
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
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        (uint256 centerAmount0, uint256 centerAmount1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            tick,
            UniswapV4PositionRepo.PositionKind.Center,
            sharesBurned,
            totalShares
        );
        (uint256 lowerWingAmount0, uint256 lowerWingAmount1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            tick,
            UniswapV4PositionRepo.PositionKind.LowerWing,
            sharesBurned,
            totalShares
        );
        (uint256 upperWingAmount0, uint256 upperWingAmount1) = _quotePositionWithdrawal(
            sqrtPriceX96,
            tick,
            UniswapV4PositionRepo.PositionKind.UpperWing,
            sharesBurned,
            totalShares
        );

        amount0 = centerAmount0 + lowerWingAmount0 + upperWingAmount0;
        amount1 = centerAmount1 + lowerWingAmount1 + upperWingAmount1;
    }

    function _quotePositionWithdrawal(
        uint160 sqrtPriceX96,
        int24 tick,
        UniswapV4PositionRepo.PositionKind kind,
        uint256 sharesBurned,
        uint256 totalShares
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint128 currentLiquidity = _currentLiquidity(kind);
        if (currentLiquidity == 0 || totalShares == 0) {
            return (0, 0);
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tick, tickLower, tickUpper, liquidityToBurn);
    }

    function _syncVaultReserves() internal {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token0()), reserve0);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token1()), reserve1);
    }

    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        return _positionAmounts();
    }

    function _sqrtPriceLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _executeUnlock(OperationParams memory params) internal returns (BalanceDelta delta) {
        bytes memory result = _poolManager().unlock(abi.encode(params));
        delta = abi.decode(result, (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(_poolManager())) {
            revert UniswapV4Exchange_InvalidCallbackCaller(msg.sender);
        }

        OperationParams memory params = abi.decode(data, (OperationParams));
        BalanceDelta delta;

        if (params.op == Operation.SwapExactIn || params.op == Operation.SwapExactOut) {
            delta = _executeSwap(params);
        } else if (params.op == Operation.AddLiquidity) {
            delta = _executeAddLiquidity(params);
        } else if (params.op == Operation.RemoveLiquidity) {
            delta = _executeRemoveLiquidity(params);
        }

        return abi.encode(delta);
    }

    function _executeSwap(OperationParams memory params) internal returns (BalanceDelta delta) {
        PoolKey memory poolKey = _poolKey();
        delta = _poolManager().swap(
            poolKey,
            SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: params.op == Operation.SwapExactIn
                    ? -int256(params.amountSpecified)
                    : int256(params.amountSpecified),
                sqrtPriceLimitX96: _sqrtPriceLimit(params.zeroForOne)
            }),
            bytes("")
        );

        _settleSwapDelta(params.zeroForOne, delta);
    }

    function _executeAddLiquidity(OperationParams memory params) internal returns (BalanceDelta callerDelta) {
        PoolKey memory poolKey = _poolKey();
        (callerDelta,) = _poolManager().modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: int256(uint256(params.liquidity)),
                salt: params.salt
            }),
            bytes("")
        );
        _settleModifyLiquidityDelta(callerDelta);
    }

    function _executeRemoveLiquidity(OperationParams memory params) internal returns (BalanceDelta callerDelta) {
        PoolKey memory poolKey = _poolKey();
        (callerDelta,) = _poolManager().modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: -int256(uint256(params.liquidity)),
                salt: params.salt
            }),
            bytes("")
        );
        _settleModifyLiquidityDelta(callerDelta);
    }

    function _settleSwapDelta(bool zeroForOne, BalanceDelta delta) internal {
        Currency inputCurrency = zeroForOne ? _currency0() : _currency1();
        Currency outputCurrency = zeroForOne ? _currency1() : _currency0();
        int128 inputDelta = zeroForOne ? delta.amount0() : delta.amount1();
        int128 outputDelta = zeroForOne ? delta.amount1() : delta.amount0();

        if (inputDelta < 0) {
            _settleCurrency(inputCurrency, uint128(-inputDelta));
        }
        if (outputDelta > 0) {
            _takeCurrency(outputCurrency, uint128(outputDelta));
        }
    }

    function _settleModifyLiquidityDelta(BalanceDelta delta) internal {
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        if (amount0 < 0) {
            _settleCurrency(_currency0(), uint128(-amount0));
        } else if (amount0 > 0) {
            _takeCurrency(_currency0(), uint128(amount0));
        }

        if (amount1 < 0) {
            _settleCurrency(_currency1(), uint128(-amount1));
        } else if (amount1 > 0) {
            _takeCurrency(_currency1(), uint128(amount1));
        }
    }

    function _settleCurrency(Currency currency, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        _poolManager().sync(currency);
        if (currency.isAddressZero()) {
            _poolManager().settle{value: amount}();
        } else {
            currency.transfer(address(_poolManager()), amount);
            _poolManager().settle();
        }
    }

    function _takeCurrency(Currency currency, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        _poolManager().take(currency, address(this), amount);
    }

    function _quoteSwapOut(uint256 amountOut, bool zeroForOne) internal view returns (uint256 amountIn) {
        return UniswapV4QuoteService._quoteDirectExactOutput(
            UniswapV4QuoteService.DirectQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                zeroForOne: zeroForOne,
                amount: amountOut
            })
        );
    }

    function _quoteSwapIn(uint256 amountIn, bool zeroForOne) internal view returns (uint256 amountOut) {
        return UniswapV4QuoteService._quoteDirectExactInput(
            UniswapV4QuoteService.DirectQuoteParams({
                manager: _poolManager(),
                key: _poolKey(),
                zeroForOne: zeroForOne,
                amount: amountIn
            })
        );
    }

    function _quoteSharesOut(uint256 amount0Added, uint256 amount1Added, uint256 totalSharesBefore)
        internal
        view
        returns (uint256 sharesOut)
    {
        if (totalSharesBefore == 0) {
            return amount0Added + amount1Added;
        }

        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return ConstProdUtils._depositQuote(amount0Added, amount1Added, totalSharesBefore, reserve0, reserve1);
    }

    function _quoteSharesIn(uint256 amount0Out, uint256 amount1Out, uint256 totalShares)
        internal
        view
        returns (uint256 sharesIn)
    {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        uint256 shares0 = reserve0 == 0 ? 0 : (amount0Out * totalShares) / reserve0;
        uint256 shares1 = reserve1 == 0 ? 0 : (amount1Out * totalShares) / reserve1;
        sharesIn = shares0 > shares1 ? shares0 : shares1;
    }

    function _snapTick(int24 tick_, int24 tickSpacing_) internal pure returns (int24 snappedTick_) {
        int24 compressed = tick_ / tickSpacing_;
        if (tick_ < 0 && tick_ % tickSpacing_ != 0) {
            compressed -= 1;
        }
        snappedTick_ = compressed * tickSpacing_;
    }

    function _deriveInitialTicks() internal view returns (int24 tickLower, int24 tickUpper) {
        ManagedTicks memory managedTicks = _deriveManagedTicks();
        tickLower = managedTicks.centerLower;
        tickUpper = managedTicks.centerUpper;
    }

    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        (, int24 currentTick,,) = _slot0();
        int24 tickSpacing = UniswapV4PoolKeyAwareRepo._tickSpacing();
        int24 outerHalfWidth = int24(uint24(UniswapV4PositionRepo._widthMultiplier())) * tickSpacing / 2;
        int24 centerHalfWidth = int24(uint24(UniswapV4PositionRepo._centerWidthMultiplier())) * tickSpacing / 2;

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

    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            if (tokenIn.balanceOf(address(this)) < amountIn) {
                revert UniswapV4Exchange_TooMuchInput();
            }
            return amountIn;
        }

        uint256 balBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        actualIn = tokenIn.balanceOf(address(this)) - balBefore;
    }

    function _transferCurrency(address token, address recipient, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        IERC20(token).safeTransfer(recipient, amount);
    }

    function _symbolOrAddress(address token) internal view returns (string memory symbol_) {
        try IERC20Metadata(token).symbol() returns (string memory fetchedSymbol) {
            return fetchedSymbol;
        } catch {
            return "TOKEN";
        }
    }
}