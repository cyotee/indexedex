// SPDX-License-Identifier: BSL-1.1
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
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {SafeCast} from "@crane/contracts/external/openzeppelin-contracts/utils/math/SafeCast.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV4PoolManagerAwareRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol";
import {UniswapV4PoolKeyAwareRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {UniswapV4QuoteService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4TwapOracleAwareRepo
} from "contracts/oracles/uniswap/v4/twap/aware/UniswapV4TwapOracleAwareRepo.sol";

abstract contract UniswapV4StandardExchangeCommon is IUnlockCallback, ISecurePullErrors {
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
    /// @notice Path requires a new PoolManager unlock while the manager is already in-session.
    error UniswapV4Exchange_PoolManagerInteractionBlocked();
    /// @notice Blocked amount-out cannot be covered by free local inventory of `token`.
    error UniswapV4Exchange_InsufficientLocalReserve(address token, uint256 requested, uint256 available);

    event TwapOracleUpdateFailed(bytes32 poolId, bytes reason);

    /// @dev Relative deadband: 5% of target free (D22).
    uint256 internal constant LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18;
    /// @dev Sink for residual first-mint dead shares (A0). Not `address(this)` so self-balance stays 0.
    address internal constant DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD);

    /**
     * @notice True when this vault may open a new PoolManager `unlock` (manager idle).
     * @dev D1: `canOpenPoolManagerUnlock() := !TransientStateLibrary.isUnlocked(poolManager)`.
     *      Uniswap V4 uses unlocked = mid-batch; product copy prefers this positive gate.
     */
    function canOpenPoolManagerUnlock() public view virtual returns (bool) {
        return !TransientStateLibrary.isUnlocked(_poolManager());
    }

    function twapOracle() public view virtual returns (IUniswapV4MultiPoolTwapOracle) {
        return UniswapV4TwapOracleAwareRepo._twapOracle();
    }

    function _pokeBoundPoolTwap() internal {
        PoolKey memory key = _poolKey();
        try twapOracle().update(key) returns (bool) {}
        catch (bytes memory reason) {
            emit TwapOracleUpdateFailed(PoolId.unwrap(key.toId()), reason);
        }
    }

    /// @dev Free ERC-20 balances of pool currencies on this diamond (D29). Never includes position math.
    function _freeBalances() internal view returns (uint256 free0, uint256 free1) {
        free0 = IERC20(_token0()).balanceOf(address(this));
        free1 = IERC20(_token1()).balanceOf(address(this));
    }

    /// @dev Deployed amounts from managed/imported positions only.
    function _deployedAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        return _positionAmounts();
    }

    /**
     * @notice Live fee-oracle liquid reserve percentage (WAD). Always re-read; no vault cache (D20).
     */
    function _liveLiquidReservePercentage() internal view returns (uint256) {
        return VaultFeeOracleQueryAwareRepo._feeOracle().liquidReservePercentageOfVault(address(this));
    }

    function _targetFree(uint256 total_i, uint256 liquidPct) internal pure returns (uint256) {
        return (total_i * liquidPct) / ONE_WAD;
    }

    /// @dev Absolute floor: 10^max(0, decimals-6) (D22).
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

    /**
     * @dev True when free_i is outside the deadband around targetFree_i (D22).
     *      When tripped, rebalance moves free_i to targetFree_i (not merely to band edge).
     */
    function _shouldRebalanceToken(uint256 free_i, uint256 targetFree_i, uint256 floor_i) internal pure returns (bool) {
        if (targetFree_i == 0) {
            return free_i > floor_i;
        }
        uint256 deviation = free_i > targetFree_i ? free_i - targetFree_i : targetFree_i - free_i;
        uint256 relativeTol = (targetFree_i * LIQUID_RESERVE_RELATIVE_TOL_WAD) / ONE_WAD;
        uint256 tol = floor_i > relativeTol ? floor_i : relativeTol;
        return deviation > tol;
    }

    function _requireCanOpenPoolManagerUnlock() internal view {
        if (!canOpenPoolManagerUnlock()) {
            revert UniswapV4Exchange_PoolManagerInteractionBlocked();
        }
    }

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

    function _weth() internal view returns (IWETH) {
        return WETHAwareRepo._weth();
    }

    /// @dev PoolKey may use native ETH (`address(0)`). The vault face is WETH.
    function _erc20Face(address token) internal view returns (address) {
        if (token == address(0)) {
            return address(_weth());
        }
        return token;
    }

    function _token0() internal view returns (address) {
        return _erc20Face(Currency.unwrap(_currency0()));
    }

    function _token1() internal view returns (address) {
        return _erc20Face(Currency.unwrap(_currency1()));
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
            return (
                UniswapV4PositionRepo._importedPositionManager()
                    .getPositionLiquidity(UniswapV4PositionRepo._importedPositionTokenId()),
                0,
                0
            );
        }

        if (!UniswapV4PositionRepo._isPositionCreated(kind)) {
            return (0, 0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        return StateLibrary.getPositionInfo(
            _poolManager(), _poolId(), address(this), tickLower, tickUpper, UniswapV4PositionRepo._salt(kind)
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
        (uint256 lowerWingAmount0, uint256 lowerWingAmount1) =
            _positionAmounts(UniswapV4PositionRepo.PositionKind.LowerWing);
        (uint256 upperWingAmount0, uint256 upperWingAmount1) =
            _positionAmounts(UniswapV4PositionRepo.PositionKind.UpperWing);

        amount0 = centerAmount0 + lowerWingAmount0 + upperWingAmount0;
        amount1 = centerAmount1 + lowerWingAmount1 + upperWingAmount1;
    }

    function _positionAmounts(UniswapV4PositionRepo.PositionKind kind)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
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
            TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
        );
        amount1 = SqrtPriceMath.getAmount1Delta(
            TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false
        );

        if (tick <= tickLower) {
            amount1 = 0;
        } else if (tick >= tickUpper) {
            amount0 = 0;
        } else {
            amount0 =
                SqrtPriceMath.getAmount0Delta(sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), liquidity, false);
            amount1 =
                SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, liquidity, false);
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

        // D30: center only. Do not call wing plan setters (wing storage slots remain unused).
        _setCenterPlan(plan, managedTicks, sqrtPriceX96, tick, budgets);
    }

    function _managedLiquidityBudgets(uint256 available0, uint256 available1)
        internal
        view
        returns (ManagedLiquidityBudgets memory budgets)
    {
        // D30: 100% of deployable inventory to the full-range center. Wings stay unused.
        budgets.centerBudget0 = available0;
        budgets.centerBudget1 = available1;
        budgets.upperWingBudget0 = 0;
        budgets.lowerWingBudget1 = 0;
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
            sqrtPriceX96, tick, managedTicks.centerLower, managedTicks.centerUpper, plan.centerLiquidity
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
            sqrtPriceX96, tick, UniswapV4PositionRepo.PositionKind.Center, sharesBurned, totalShares
        );
        (uint256 lowerWingAmount0, uint256 lowerWingAmount1) = _quotePositionWithdrawal(
            sqrtPriceX96, tick, UniswapV4PositionRepo.PositionKind.LowerWing, sharesBurned, totalShares
        );
        (uint256 upperWingAmount0, uint256 upperWingAmount1) = _quotePositionWithdrawal(
            sqrtPriceX96, tick, UniswapV4PositionRepo.PositionKind.UpperWing, sharesBurned, totalShares
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
        // Book sitting vaultShare so leftover self-shares are R, not durable U (E6 / I1).
        MultiAssetBasicVaultRepo._updateReserve(
            IERC20(address(this)), IERC20(address(this)).balanceOf(address(this))
        );
    }

    /**
     * @dev Total reserves = free ERC-20 balances + deployed position amounts (D9/D29).
     *      Free never double-counts position inventory; deployed never includes balanceOf.
     */
    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        reserve0 = free0 + deployed0;
        reserve1 = free1 + deployed1;
    }

    function _sqrtPriceLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /**
     * @dev Every unlock entry requires interaction-free gate so a missed branch cannot nested-unlock.
     */
    function _executeUnlock(OperationParams memory params) internal returns (BalanceDelta delta) {
        _requireCanOpenPoolManagerUnlock();
        bytes memory result = _poolManager().unlock(abi.encode(params));
        delta = abi.decode(result, (BalanceDelta));
    }

    /**
     * @dev Shares minted for a deposit of `amount0Added`/`amount1Added` against pre-deposit reserves.
     *      First mint: amount0+amount1 (free-only OK). Subsequent single-sided: pro-rata that token's reserve.
     *      Dual-sided: ConstProdUtils min-ratio quote.
     */
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

    /**
     * @dev Best-effort free↔deployed rebalance when interaction is free (D10/D11/D22/D28).
     *      Never reverts the caller for soft failure: no-op when blocked; skip dust; no swaps.
     */
    function _rebalanceLiquidReserveBestEffort() internal {
        if (!canOpenPoolManagerUnlock()) {
            return;
        }
        _rebalanceLiquidReserveInternal();
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

    function _loadRebalanceSnap() internal view returns (RebalanceSnap memory s) {
        s.liquidPct = _liveLiquidReservePercentage();
        (s.free0, s.free1) = _freeBalances();
        (s.deployed0, s.deployed1) = _deployedAmounts();
        s.target0 = _targetFree(s.free0 + s.deployed0, s.liquidPct);
        s.target1 = _targetFree(s.free1 + s.deployed1, s.liquidPct);
    }

    /**
     * @dev Core rebalance: deploy excess free and/or remove to refill deficit (add/remove only).
     *      Does not move ticks. Non-imported deployed book is full-range (D30).
     * @return moved True if any liquidity was added or removed.
     */
    function _rebalanceLiquidReserveInternal() internal returns (bool moved) {
        RebalanceSnap memory s = _loadRebalanceSnap();
        uint256 floor0 = _absoluteFloor(_token0());
        uint256 floor1 = _absoluteFloor(_token1());

        if (!_shouldRebalanceToken(s.free0, s.target0, floor0) && !_shouldRebalanceToken(s.free1, s.target1, floor1)) {
            return false;
        }

        // Deploy excess first (free > target).
        {
            uint256 excess0 = s.free0 > s.target0 ? s.free0 - s.target0 : 0;
            uint256 excess1 = s.free1 > s.target1 ? s.free1 - s.target1 : 0;
            if ((excess0 > 0 || excess1 > 0) && _deployExcessLiquidity(excess0, excess1)) {
                moved = true;
            }
        }

        // Refill deficit (free < target) via remove-liquidity; dual-token overshoot accepted (D28).
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

        // Optional second deploy pass if remove overshot free on the other token.
        if (moved && canOpenPoolManagerUnlock()) {
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
        _refreshStoredLiquidity();
        _syncVaultReserves();
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        emit IUniswapV4StandardExchangeLiquidReserve.LiquidReserveRebalanced(
            free0, free1, deployed0, deployed1, liquidPct
        );
    }

    function _deployExcessLiquidity(uint256 excess0, uint256 excess1) internal returns (bool moved) {
        if (excess0 == 0 && excess1 == 0) {
            return false;
        }
        // Cap budgets to actual free (never pull from outside).
        (uint256 free0, uint256 free1) = _freeBalances();
        if (excess0 > free0) excess0 = free0;
        if (excess1 > free1) excess1 = free1;
        if (excess0 == 0 && excess1 == 0) {
            return false;
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            return _deployExcessImported(excess0, excess1);
        }

        ManagedTicks memory managedTicks =
            UniswapV4PositionRepo._isPositionCreated() ? _managedTicks() : _deriveManagedTicks();
        _createManagedPositionsIfNeededCommon(managedTicks);

        ManagedLiquidityPlan memory plan = _managedLiquidityPlan(managedTicks, excess0, excess1);
        if (plan.centerLiquidity == 0) {
            return false;
        }

        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: managedTicks.centerLower,
                tickUpper: managedTicks.centerUpper,
                liquidity: plan.centerLiquidity,
                salt: UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.Center)
            })
        );
        moved = true;
    }

    function _deployExcessImported(uint256 excess0, uint256 excess1) internal returns (bool moved) {
        (int24 tickLower, int24 tickUpper) =
            UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);
        (uint160 sqrtPriceX96,,,) = _slot0();
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            excess0,
            excess1
        );
        if (liquidity == 0) {
            return false;
        }
        // Imported growth uses PositionManager modifyLiquidities (unlock inside PM path).
        // Only callable when free; gate already checked by caller.
        _increaseImportedPositionCommon(liquidity, uint128(excess0), uint128(excess1));
        return true;
    }

    function _refillDeficitLiquidity(uint256 need0, uint256 need1, uint256 deployed0, uint256 deployed1)
        internal
        returns (bool moved)
    {
        // Estimate share of deployed inventory to remove so free of short tokens rises toward target.
        // Conservative: burn max(need0/deployed0, need1/deployed1) fraction of each position's liquidity.
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
        // Cap at 100%.
        if (fracWad > ONE_WAD) {
            fracWad = ONE_WAD;
        }

        // Use a large "shares" scale so integer liquidity burns work for small fractions.
        uint256 scale = 1e18;
        uint256 burnShares = (fracWad * scale) / ONE_WAD;
        if (burnShares == 0) {
            burnShares = 1;
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            uint128 liq = _currentLiquidity(UniswapV4PositionRepo.PositionKind.Center);
            uint128 toBurn = uint128((uint256(liq) * burnShares) / scale);
            if (toBurn == 0) {
                return false;
            }
            _burnImportedLiquidityCommon(toBurn);
            return true;
        }

        if (_burnManagedLiquidityFraction(UniswapV4PositionRepo.PositionKind.Center, burnShares, scale)) {
            moved = true;
        }
    }

    function _burnManagedLiquidityFraction(UniswapV4PositionRepo.PositionKind kind, uint256 burnShares, uint256 scale)
        internal
        returns (bool)
    {
        uint128 currentLiquidity = _currentLiquidity(kind);
        if (currentLiquidity == 0) {
            return false;
        }
        uint128 liquidityToBurn = uint128((uint256(currentLiquidity) * burnShares) / scale);
        if (liquidityToBurn == 0) {
            return false;
        }
        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidityToBurn,
                salt: UniswapV4PositionRepo._salt(kind)
            })
        );
        return true;
    }

    function _createManagedPositionsIfNeededCommon(ManagedTicks memory managedTicks) internal {
        if (UniswapV4PositionRepo._isPositionCreated()) {
            return;
        }
        // D30: center only. Wings are not created.
        UniswapV4PositionRepo._createPositionIfNeeded(
            UniswapV4PositionRepo.PositionKind.Center, managedTicks.centerLower, managedTicks.centerUpper
        );
    }

    function _increaseImportedPositionCommon(uint128 liquidity, uint128 amount0Max, uint128 amount1Max) internal {
        address pm = address(UniswapV4PositionRepo._importedPositionManager());
        Permit2AwareRepo._permit2().approve(_token0(), pm, type(uint160).max, type(uint48).max);
        Permit2AwareRepo._permit2().approve(_token1(), pm, type(uint160).max, type(uint48).max);
        IERC20(_token0()).approve(pm, amount0Max);
        IERC20(_token1()).approve(pm, amount1Max);

        bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            UniswapV4PositionRepo._importedPositionTokenId(), uint256(liquidity), amount0Max, amount1Max, bytes("")
        );
        params[1] = abi.encode(_currency0(), _currency1());
        UniswapV4PositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);

        IERC20(_token0()).approve(pm, 0);
        IERC20(_token1()).approve(pm, 0);
    }

    function _burnImportedLiquidityCommon(uint128 liquidityToBurn) internal {
        bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            UniswapV4PositionRepo._importedPositionTokenId(),
            uint256(liquidityToBurn),
            uint128(0),
            uint128(0),
            bytes("")
        );
        params[1] = abi.encode(_currency0(), _currency1(), address(this));
        UniswapV4PositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);
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
        delta = _poolManager()
            .swap(
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
        (callerDelta,) = _poolManager()
            .modifyLiquidity(
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
        (callerDelta,) = _poolManager()
            .modifyLiquidity(
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
            _weth().withdraw(amount);
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
        if (currency.isAddressZero()) {
            _weth().deposit{value: amount}();
        }
    }

    function _quoteSwapOut(uint256 amountOut, bool zeroForOne) internal view returns (uint256 amountIn) {
        return UniswapV4QuoteService._quoteDirectExactOutput(
            UniswapV4QuoteService.DirectQuoteParams({
                manager: _poolManager(), key: _poolKey(), zeroForOne: zeroForOne, amount: amountOut
            })
        );
    }

    function _quoteSwapIn(uint256 amountIn, bool zeroForOne) internal view returns (uint256 amountOut) {
        return UniswapV4QuoteService._quoteDirectExactInput(
            UniswapV4QuoteService.DirectQuoteParams({
                manager: _poolManager(), key: _poolKey(), zeroForOne: zeroForOne, amount: amountIn
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

    function _deriveInitialTicks() internal view returns (int24 tickLower, int24 tickUpper) {
        ManagedTicks memory managedTicks = _deriveManagedTicks();
        tickLower = managedTicks.centerLower;
        tickUpper = managedTicks.centerUpper;
    }

    /**
     * @dev One full-range center. Wings unused (zero-width placeholders).
     *      Rebalance never recasts ticks.
     */
    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        int24 tickSpacing = UniswapV4PoolKeyAwareRepo._tickSpacing();
        managedTicks.centerLower = TickMath.minUsableTick(tickSpacing);
        managedTicks.centerUpper = TickMath.maxUsableTick(tickSpacing);
        managedTicks.lowerWingLower = managedTicks.centerLower;
        managedTicks.lowerWingUpper = managedTicks.centerLower;
        managedTicks.upperWingLower = managedTicks.centerUpper;
        managedTicks.upperWingUpper = managedTicks.centerUpper;
    }

    /**
     * @dev D41/D42: Multi arrays must be exactly the two PoolKey currencies, unique, strictly ascending.
     */
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

    /**
     * @dev D52: implied exact-out share burns. Zero total on a listed token or empty supply reverts.
     *      Callers require `s0 == s1` for a proportional exit.
     */
    function _dualExitShareBurns(
        uint256 amount0,
        uint256 amount1,
        uint256 total0,
        uint256 total1,
        uint256 supply
    ) internal pure returns (uint256 s0, uint256 s1) {
        if (total0 == 0 || total1 == 0 || supply == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }
        s0 = FullMath.mulDivRoundingUp(amount0, supply, total0);
        s1 = FullMath.mulDivRoundingUp(amount1, supply, total1);
    }

    /**
     * @dev Remove `floor(shares * centerL / supply)` from the center (imported: decrease NFT).
     *      Wings are unused (D30). Idle Multi exit uses this even if the sleeve would cover (D3).
     */
    function _burnCenterLiquidityForShares(uint256 sharesBurned, uint256 totalShares) internal {
        if (sharesBurned == 0 || totalShares == 0) {
            return;
        }
        uint128 currentLiquidity = _currentLiquidity(UniswapV4PositionRepo.PositionKind.Center);
        if (currentLiquidity == 0) {
            return;
        }
        uint128 liquidityToBurn = uint128((uint256(currentLiquidity) * sharesBurned) / totalShares);
        if (liquidityToBurn == 0) {
            return;
        }
        if (UniswapV4PositionRepo._isImportedPosition()) {
            _burnImportedLiquidityCommon(liquidityToBurn);
            return;
        }
        (int24 tickLower, int24 tickUpper) =
            UniswapV4PositionRepo._positionTicks(UniswapV4PositionRepo.PositionKind.Center);
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidityToBurn,
                salt: UniswapV4PositionRepo._salt(UniswapV4PositionRepo.PositionKind.Center)
            })
        );
    }

    /**
     * @notice Securely pulls tokens using reserve-delta accounting (L-DETF-HOST-UPGRADE / BasicVault peer).
     * @dev MultiAsset `R` for this SE is **total** inventory = face free + deployed position amounts
     *      (`_syncVaultReserves`). Face unbooked must subtract only the **face** component of R:
     *      `faceBooked = R - deployed`, `U = B_face - faceBooked`.
     *      Using `U = B - R` under-credits free face when deployed > 0 (breaks nested push+true).
     *      - `!pretransferred`: transferFrom, return pull delta only (FoT-safe; does not add prior U).
     *      - `pretransferred`: credit `amountIn` only when `amountIn <= U`; else
     *        `TransferDeltaInsufficient(claimed, U)`. I1 when face is fully booked (`U == 0`).
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            // FoT-safe: return pull delta only — do NOT add prior unbooked U.
            return tokenIn.balanceOf(address(this)) - B0;
        }
        // Face-booked component of total R (exclude deployed position amounts).
        uint256 deployed = _deployedFaceOf(address(tokenIn));
        uint256 faceBooked = R > deployed ? R - deployed : 0;
        uint256 U = B0 > faceBooked ? B0 - faceBooked : 0;
        if (amountIn > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
        }
        return amountIn;
    }

    /// @dev Deployed (non-face) reserve component for `token_` — 0 for unknown tokens.
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

    /**
     * @notice Credit `vaultShare` delivery for zap-out. Does not use token `_secureTokenTransfer`.
     * @dev E6 / I1: `!pretransferred` returns this-call pull delta only. `pretransferred` credits
     *      `amountIn` only against unbooked self-share `U = B - R` after `_syncVaultReserves`
     *      books sitting leftover. Fat `max` against booked leftover reverts
     *      `TransferDeltaInsufficient`.
     */
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

    /// @dev E6: refund only this-call unused inbound shares (`delivered - used`), never leftover R.
    function _refundUnusedShares(uint256 delivered, uint256 used, address recipient) internal {
        if (delivered > used) {
            IERC20(address(this)).safeTransfer(recipient, delivered - used);
        }
    }

    function _symbolOrAddress(address token) internal view returns (string memory symbol_) {
        try IERC20Metadata(token).symbol() returns (string memory fetchedSymbol) {
            return fetchedSymbol;
        } catch {
            return "TOKEN";
        }
    }
}
