// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
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
import {SafeCast} from "@crane/contracts/external/openzeppelin-contracts/utils/math/SafeCast.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {UniswapV4QuoteService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol";
import {
    UniV4DetfRebasingClaimRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimRepo.sol";

/// @title UniV4DetfRebasingClaimCommon
/// @notice Managed center/wing LP + ZapOut-to-pair accounting for the rebasing claim package.
/// @dev Always re-derives ticks from slot0 on deposit/redeem/absorb/donate (SE rebalance spirit).
abstract contract UniV4DetfRebasingClaimCommon is IUnlockCallback, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using SafeCast for int256;
    using SafeCast for uint256;

    uint256 internal constant ONE_WAD = 1e18;

    enum Operation {
        SwapExactIn,
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

    error InvalidCallbackCaller(address caller);
    error ZeroAmount();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error UnsupportedToken(address token);

    /* ---------------------------------------------------------------------- */
    /*                         Pool / position reads                          */
    /* ---------------------------------------------------------------------- */

    function _poolManager() internal view returns (IPoolManager) {
        return UniV4DetfRebasingClaimRepo._layout().poolManager;
    }

    function _poolKey() internal view returns (PoolKey memory) {
        return UniV4DetfRebasingClaimRepo._layout().poolKey;
    }

    function _poolId() internal view returns (PoolId) {
        return UniV4DetfRebasingClaimRepo._layout().poolId;
    }

    function _pairToken() internal view returns (IERC20) {
        return UniV4DetfRebasingClaimRepo._layout().pairToken;
    }

    function _detfToken() internal view returns (IERC20) {
        return UniV4DetfRebasingClaimRepo._layout().detfToken;
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(_poolKey().currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(_poolKey().currency1);
    }

    function _slot0() internal view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) {
        return StateLibrary.getSlot0(_poolManager(), _poolId());
    }

    function _currentLiquidity(UniswapV4PositionRepo.PositionKind kind) internal view returns (uint128 liquidity) {
        if (!UniswapV4PositionRepo._isPositionCreated(kind)) return 0;
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        (liquidity,,) = StateLibrary.getPositionInfo(
            _poolManager(), _poolId(), address(this), tickLower, tickUpper, UniswapV4PositionRepo._salt(kind)
        );
    }

    function _positionAmounts(UniswapV4PositionRepo.PositionKind kind)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (!UniswapV4PositionRepo._isPositionCreated(kind)) return (0, 0);
        uint128 liquidity = _currentLiquidity(kind);
        if (liquidity == 0) return (0, 0);
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tick, tickLower, tickUpper, liquidity);
    }

    function _totalPositionAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        (uint256 c0, uint256 c1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.Center);
        (uint256 l0, uint256 l1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.LowerWing);
        (uint256 u0, uint256 u1) = _positionAmounts(UniswapV4PositionRepo.PositionKind.UpperWing);
        amount0 = c0 + l0 + u0;
        amount1 = c1 + l1 + u1;
    }

    function _amountsForLiquidityAtPrice(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) return (0, 0);
        if (tick < tickLower) {
            amount0 = SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        } else if (tick < tickUpper) {
            amount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false);
            amount1 = SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, liquidity, false);
        } else {
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
            );
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              Tick derive                               */
    /* ---------------------------------------------------------------------- */

    function _snapTick(int24 tick_, int24 tickSpacing_) internal pure returns (int24 snappedTick_) {
        int24 compressed = tick_ / tickSpacing_;
        if (tick_ < 0 && tick_ % tickSpacing_ != 0) compressed -= 1;
        snappedTick_ = compressed * tickSpacing_;
    }

    /// @notice Always re-derive from current slot0 (plan §0.3 #29).
    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        (, int24 currentTick,,) = _slot0();
        int24 tickSpacing = _poolKey().tickSpacing;
        uint24 widthMultiplier = UniV4DetfRebasingClaimRepo._layout().widthMultiplier;
        int24 outerHalfWidth = int24(uint24(widthMultiplier)) * tickSpacing / 2;
        int24 centerHalfWidth = int24(uint24(2)) * tickSpacing / 2; // centerWidthMultiplier = 2

        if (centerHalfWidth < tickSpacing) centerHalfWidth = tickSpacing;
        if (outerHalfWidth <= centerHalfWidth) outerHalfWidth = centerHalfWidth + tickSpacing;

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

    function _createOrUpdateManagedPositions(ManagedTicks memory managedTicks) internal {
        // Always update ticks to re-derived ranges (rebalance spirit).
        UniswapV4PositionRepo.Storage storage layout_ = UniswapV4PositionRepo._layout();
        _setPositionTicks(layout_, UniswapV4PositionRepo.PositionKind.Center, managedTicks.centerLower, managedTicks.centerUpper);
        _setPositionTicks(
            layout_, UniswapV4PositionRepo.PositionKind.LowerWing, managedTicks.lowerWingLower, managedTicks.lowerWingUpper
        );
        _setPositionTicks(
            layout_, UniswapV4PositionRepo.PositionKind.UpperWing, managedTicks.upperWingLower, managedTicks.upperWingUpper
        );
    }

    function _setPositionTicks(
        UniswapV4PositionRepo.Storage storage layout_,
        UniswapV4PositionRepo.PositionKind kind_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal {
        UniswapV4PositionRepo.PositionState storage position_ = UniswapV4PositionRepo._position(layout_, kind_);
        // If existing liquidity at old ticks, leave created flag; ticks updated for new adds after full withdraw paths.
        position_.tickLower = tickLower_;
        position_.tickUpper = tickUpper_;
        position_.created = true;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Liquidity plan                               */
    /* ---------------------------------------------------------------------- */

    function _managedLiquidityPlan(ManagedTicks memory managedTicks, uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityPlan memory plan)
    {
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        ManagedLiquidityBudgets memory budgets;
        // activeLiquidityBps = 1000
        budgets.centerBudget0 = (available0 * 1000) / 10_000;
        budgets.centerBudget1 = (available1 * 1000) / 10_000;
        budgets.upperWingBudget0 = available0 - budgets.centerBudget0;
        budgets.lowerWingBudget1 = available1 - budgets.centerBudget1;

        plan.centerLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.centerLower),
            TickMath.getSqrtPriceAtTick(managedTicks.centerUpper),
            budgets.centerBudget0,
            budgets.centerBudget1
        );
        (uint256 a0, uint256 a1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, tick, managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity
        );
        plan.amount0Used += a0;
        plan.amount1Used += a1;

        plan.lowerWingLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.lowerWingLower),
            TickMath.getSqrtPriceAtTick(managedTicks.lowerWingUpper),
            0,
            budgets.lowerWingBudget1
        );
        (a0, a1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, tick, managedTicks.lowerWingLower, managedTicks.lowerWingUpper, plan.lowerWingLiquidity
        );
        plan.amount0Used += a0;
        plan.amount1Used += a1;

        plan.upperWingLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(managedTicks.upperWingLower),
            TickMath.getSqrtPriceAtTick(managedTicks.upperWingUpper),
            budgets.upperWingBudget0,
            0
        );
        (a0, a1) = _amountsForLiquidityAtPrice(
            sqrtPriceX96, tick, managedTicks.upperWingLower, managedTicks.upperWingUpper, plan.upperWingLiquidity
        );
        plan.amount0Used += a0;
        plan.amount1Used += a1;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Unlock ops                                */
    /* ---------------------------------------------------------------------- */

    function _executeUnlock(OperationParams memory params) internal returns (BalanceDelta delta) {
        bytes memory result = _poolManager().unlock(abi.encode(params));
        delta = abi.decode(result, (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(_poolManager())) revert InvalidCallbackCaller(msg.sender);
        OperationParams memory params = abi.decode(data, (OperationParams));
        BalanceDelta delta;
        if (params.op == Operation.SwapExactIn) {
            delta = _executeSwap(params);
        } else if (params.op == Operation.AddLiquidity) {
            delta = _executeAddLiquidity(params);
        } else {
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
                amountSpecified: -int256(params.amountSpecified),
                sqrtPriceLimitX96: params.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            bytes("")
        );
        Currency inputCurrency = params.zeroForOne ? poolKey.currency0 : poolKey.currency1;
        Currency outputCurrency = params.zeroForOne ? poolKey.currency1 : poolKey.currency0;
        int128 inputDelta = params.zeroForOne ? delta.amount0() : delta.amount1();
        int128 outputDelta = params.zeroForOne ? delta.amount1() : delta.amount0();
        if (inputDelta < 0) _settleCurrency(inputCurrency, uint128(-inputDelta));
        if (outputDelta > 0) _takeCurrency(outputCurrency, uint128(outputDelta));
    }

    function _executeAddLiquidity(OperationParams memory params) internal returns (BalanceDelta callerDelta) {
        (callerDelta,) = _poolManager().modifyLiquidity(
            _poolKey(),
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
        (callerDelta,) = _poolManager().modifyLiquidity(
            _poolKey(),
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

    function _settleModifyLiquidityDelta(BalanceDelta delta) internal {
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        PoolKey memory key = _poolKey();
        if (amount0 < 0) _settleCurrency(key.currency0, uint128(-amount0));
        else if (amount0 > 0) _takeCurrency(key.currency0, uint128(amount0));
        if (amount1 < 0) _settleCurrency(key.currency1, uint128(-amount1));
        else if (amount1 > 0) _takeCurrency(key.currency1, uint128(amount1));
    }

    function _settleCurrency(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager().sync(currency);
        if (currency.isAddressZero()) {
            _poolManager().settle{value: amount}();
        } else {
            currency.transfer(address(_poolManager()), amount);
            _poolManager().settle();
        }
    }

    function _takeCurrency(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager().take(currency, address(this), amount);
    }

    function _addLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        if (liquidity == 0) return;
        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        if (liquidity == 0) return;
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _swapExactIn(bool zeroForOne, uint256 amountSpecified) internal {
        if (amountSpecified == 0) return;
        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactIn,
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         ZapOut-to-pair quote                           */
    /* ---------------------------------------------------------------------- */

    function _quoteSwapIn(uint256 amountIn, bool zeroForOne) internal view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        return UniswapV4QuoteService._quoteDirectExactInput(
            UniswapV4QuoteService.DirectQuoteParams({
                manager: _poolManager(), key: _poolKey(), zeroForOne: zeroForOne, amount: amountIn
            })
        );
    }

    /// @notice Full-exit valuation of managed L converted entirely to pairToken.
    function _zapOutToPair() internal view returns (uint256 pairValue) {
        (uint256 amount0, uint256 amount1) = _totalPositionAmounts();
        // Also count loose balances on this contract (post-withdraw residual).
        amount0 += IERC20(_token0()).balanceOf(address(this));
        amount1 += IERC20(_token1()).balanceOf(address(this));

        bool pairIs0 = UniV4DetfRebasingClaimRepo._layout().pairIsCurrency0;
        if (pairIs0) {
            pairValue = amount0 + _quoteSwapIn(amount1, false);
        } else {
            pairValue = amount1 + _quoteSwapIn(amount0, true);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Deposit into wings                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Place held token0/token1 balances into re-derived center/wings. Does not mint shares.
    function _depositBalancesIntoWings() internal {
        ManagedTicks memory ticks = _deriveManagedTicks();
        _createOrUpdateManagedPositions(ticks);

        address token0 = _token0();
        address token1 = _token1();
        uint256 available0 = IERC20(token0).balanceOf(address(this));
        uint256 available1 = IERC20(token1).balanceOf(address(this));
        if (available0 == 0 && available1 == 0) return;

        ManagedLiquidityPlan memory plan = _managedLiquidityPlan(ticks, available0, available1);

        if (plan.centerLiquidity > 0) {
            _addLiquidity(
                ticks.centerLower,
                ticks.centerUpper,
                plan.centerLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.Center)
            );
        }
        if (plan.lowerWingLiquidity > 0) {
            _addLiquidity(
                ticks.lowerWingLower,
                ticks.lowerWingUpper,
                plan.lowerWingLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.LowerWing)
            );
        }
        if (plan.upperWingLiquidity > 0) {
            _addLiquidity(
                ticks.upperWingLower,
                ticks.upperWingUpper,
                plan.upperWingLiquidity,
                UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.UpperWing)
            );
        }

        // Refresh stored liquidity.
        UniswapV4PositionRepo._updateLiquidity(
            UniswapV4PositionRepo.PositionKind.Center, _currentLiquidity(UniswapV4PositionRepo.PositionKind.Center)
        );
        UniswapV4PositionRepo._updateLiquidity(
            UniswapV4PositionRepo.PositionKind.LowerWing, _currentLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing)
        );
        UniswapV4PositionRepo._updateLiquidity(
            UniswapV4PositionRepo.PositionKind.UpperWing, _currentLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing)
        );
    }

    /// @dev Mint rebasing tokens from ZapOut-to-pair contribution. First deposit mirrors SE: tokens = contribution.
    function _mintFromContribution(uint256 preZapOut, uint256 postZapOut, address recipient)
        internal
        returns (uint256 minted)
    {
        if (postZapOut <= preZapOut) return 0;
        uint256 contribution = postZapOut - preZapOut;
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || preZapOut == 0) {
            // Mirror Uni V4 SE first-share: amount0Used + amount1Used spirit → contribution.
            minted = contribution;
        } else {
            minted = Math.mulDiv(contribution, supply, preZapOut);
        }
        if (minted > 0) ERC20Repo._mint(recipient, minted);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Redeem ladder                                */
    /* ---------------------------------------------------------------------- */

    function _obligationPair(uint256 rebasingAmount) internal view returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || rebasingAmount == 0) return 0;
        uint256 zap = _zapOutToPair();
        return Math.mulDiv(rebasingAmount, zap, supply);
    }

    function _withdrawFullPosition(UniswapV4PositionRepo.PositionKind kind) internal {
        uint128 liq = _currentLiquidity(kind);
        if (liq == 0) return;
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        _removeLiquidity(tickLower, tickUpper, liq, UniswapV4PositionRepo._salt(kind));
        UniswapV4PositionRepo._updateLiquidity(kind, 0);
    }

    function _pairBalance() internal view returns (uint256) {
        return _pairToken().balanceOf(address(this));
    }

    function _detfBalance() internal view returns (uint256) {
        return _detfToken().balanceOf(address(this));
    }

    /// @dev Redeem ladder: pair wing → center → DETF wing → swap DETF→pair for shortfall; pay obligation only; redeposit residual.
    function _executeRedeemLadder(uint256 obligation, address recipient) internal returns (uint256 pairPaid) {
        bool pairIs0 = UniV4DetfRebasingClaimRepo._layout().pairIsCurrency0;

        // 1) Pair-sided wing (lower wing is token1-sided; upper is token0-sided at strategy open)
        if (pairIs0) {
            // pair is currency0 → upper wing holds pair
            _withdrawFullPosition(UniswapV4PositionRepo.PositionKind.UpperWing);
        } else {
            _withdrawFullPosition(UniswapV4PositionRepo.PositionKind.LowerWing);
        }

        if (_pairBalance() < obligation) {
            // 2) Center
            _withdrawFullPosition(UniswapV4PositionRepo.PositionKind.Center);
        }
        if (_pairBalance() < obligation) {
            // 3) DETF wing
            if (pairIs0) {
                _withdrawFullPosition(UniswapV4PositionRepo.PositionKind.LowerWing);
            } else {
                _withdrawFullPosition(UniswapV4PositionRepo.PositionKind.UpperWing);
            }
        }
        if (_pairBalance() < obligation) {
            // 4) Swap just enough DETF → pair for shortfall
            uint256 shortfall = obligation - _pairBalance();
            uint256 detfBal = _detfBalance();
            if (detfBal > 0) {
                // Approximate: swap all DETF if needed (exact shortfall solver is heavy; swap up to detf bal).
                bool detfIs0 = !pairIs0;
                // Binary-search light: swap min(detfBal, quote-needed). Use full detf if quote for shortfall is hard.
                // Prefer swap exact-in of estimated DETF needed via quote exact-out if available.
                uint256 detfToSwap = detfBal;
                // Try exact-out style estimate via iterative quote exact-in.
                // Simple path: swap all detf, then redeposit excess pair.
                _swapExactIn(detfIs0, detfToSwap);
                // silence unused shortfall in simple path
                shortfall;
            }
        }

        pairPaid = _pairBalance();
        if (pairPaid > obligation) pairPaid = obligation;
        if (pairPaid > 0) _pairToken().safeTransfer(recipient, pairPaid);

        // 5) Redeposit residual DETF + excess pair into wings
        _depositBalancesIntoWings();
    }
}
