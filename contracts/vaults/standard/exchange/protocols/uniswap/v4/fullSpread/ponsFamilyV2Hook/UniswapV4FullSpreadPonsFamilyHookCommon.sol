// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Address} from "@crane/contracts/utils/Address.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
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
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
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

import {IStandardExchangeTransitionQuote as ITransition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV4FullSpreadPonsFamilyHookPoolManagerAwareRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookPoolManagerAwareRepo.sol";
import {UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo.sol";
import {UniswapV4FullSpreadPonsFamilyHookPositionRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookPositionRepo.sol";
import {UniswapV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol";
import {
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4TwapOracleAwareRepo
} from "contracts/oracles/uniswap/v4/twap/aware/UniswapV4TwapOracleAwareRepo.sol";

import {NativeStandardYieldContextRepo} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "./UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "./UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";
import {UniswapV4FullSpreadPonsFamilyHookExecutionContextRepo as ExecutionContext} from "./UniswapV4FullSpreadPonsFamilyHookExecutionContextRepo.sol";
import {StandardExchangeConstantProduct} from "../../../StandardExchangeConstantProduct.sol";

abstract contract UniswapV4FullSpreadPonsFamilyHookCommon is IUnlockCallback, ISecurePullErrors {
    using BetterSafeERC20 for IERC20;

    modifier operationScope() {
        ExecutionContext._beginOperation(msg.sig,
            VaultFeeOracleQueryAwareRepo._feeOracle().liquidReservePercentageOfVault(address(this)));
        _;
        ExecutionContext._endOperation();
    }

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

    /// @dev Cache one direct position plus sleeves and earned fees for repeated quotes.
    struct InventoryQuote {
        address vault;
        bool token0;
        bool idle;
        uint256 supply;
        uint256 shares;
        uint256 free0;
        uint256 free1;
        uint256 fees0;
        uint256 fees1;
        uint128 positionLiquidity;
        int24 lower;
        int24 upper;
        int128 liquidityDelta;
        UniswapV4Quoter.PoolState pool;
        uint256 sleeveWad;
        uint256[2] absoluteFloor;
        uint128 lowerLiquidityGross;
        uint128 upperLiquidityGross;
        uint128 maxLiquidityPerTick;
    }

    function _supportsInventoryQuote() internal view returns (bool) {
        return !UniswapV4FullSpreadPonsFamilyHookPositionRepo._isImportedPosition();
    }

    function _inventorySnapshot(address asset, address holder) internal view returns (InventoryQuote memory q) {
        if (asset != _token0() && asset != _token1()) revert ITransition.UnsupportedQuoteAsset(asset);
        if (!_supportsInventoryQuote()) revert ITransition.InvalidQuoteState();
        q.vault = address(this);
        q.token0 = asset == _token0();
        q.idle = canOpenPoolManagerUnlock();
        q.supply = IERC20(address(this)).totalSupply();
        q.shares = IERC20(address(this)).balanceOf(holder);
        (q.free0, q.free1) = _freeBalances();
        (q.fees0, q.fees1) = _collectablePositionFees();
        q.positionLiquidity = _currentLiquidity();
        ManagedTicks memory ticks = _managedTicks();
        q.lower = ticks.centerLower;
        q.upper = ticks.centerUpper;
        (q.lowerLiquidityGross,) = StateLibrary.getTickLiquidity(_poolManager(), _poolId(), q.lower);
        (q.upperLiquidityGross,) = StateLibrary.getTickLiquidity(_poolManager(), _poolId(), q.upper);
        q.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(_poolKey().tickSpacing);
        (q.pool.sqrtPriceX96, q.pool.tick,,) = _slot0();
        q.pool.liquidity = StateLibrary.getLiquidity(_poolManager(), _poolId());
        q.sleeveWad = _liveLiquidReservePercentage();
        q.absoluteFloor = [_absoluteFloor(_token0()), _absoluteFloor(_token1())];
    }

    function _inventoryAssets(InventoryQuote memory q, uint256 shares) internal view returns (uint256) {
        if (shares == 0 || q.supply == 0) return 0;
        InventoryQuote memory copy = abi.decode(abi.encode(q), (InventoryQuote));
        copy.shares = shares;
        return _inventoryRedeem(copy, shares);
    }

    function _inventoryTotals(InventoryQuote memory q) internal pure returns (uint256 total0, uint256 total1) {
        (total0, total1) = _inventoryPositionAmounts(q, q.positionLiquidity, false);
        total0 += q.free0 + q.fees0;
        total1 += q.free1 + q.fees1;
    }

    function _inventoryCollect(InventoryQuote memory q) internal pure {
        q.free0 += q.fees0;
        q.free1 += q.fees1;
        q.fees0 = 0;
        q.fees1 = 0;
    }

    function _inventoryRedeem(InventoryQuote memory q, uint256 shares) internal view returns (uint256 assets) {
        if (shares > q.supply) revert ITransition.InvalidQuoteState();
        if (!q.idle) {
            (uint256 total0, uint256 total1) = _inventoryTotals(q);
            assets = q.token0
                ? StandardExchangeConstantProduct._singleExit(total0, total1, shares, q.supply)
                : StandardExchangeConstantProduct._singleExit(total1, total0, shares, q.supply);
            // quoteAssets values inventory even when the liquid sleeve cannot pay it yet.
            if (q.token0) q.free0 = assets <= q.free0 ? q.free0 - assets : 0;
            else q.free1 = assets <= q.free1 ? q.free1 - assets : 0;
        } else {
            _inventoryCollect(q);
            uint256 out0 = Math.mulDiv(q.free0, shares, q.supply);
            uint256 out1 = Math.mulDiv(q.free1, shares, q.supply);
            uint128 burned = uint128(Math.mulDiv(q.positionLiquidity, shares, q.supply));
            if (burned > uint128(type(int128).max)) revert ITransition.InvalidQuoteState();
            (uint256 principal0, uint256 principal1) = _inventoryPositionAmounts(q, burned, false);
            _inventoryChangeLiquidity(q, -int128(burned));
            out0 += principal0;
            out1 += principal1;
            q.free0 -= out0;
            q.free1 -= out1;
            assets = q.token0 ? out0 : out1;
            uint256 other = q.token0 ? out1 : out0;
            if (other != 0) assets += _inventoryRedemptionSwap(q, other);
        }
        q.supply -= shares;
        q.shares -= shares;
    }

    function _inventorySharesIn(InventoryQuote memory q, uint256 amount) internal view returns (uint256 shares) {
        if (amount == 0) return 0;
        Types.Snapshot memory state = _inventoryState(q);
        (shares,) = _linearExitPlan(state, q.token0, amount);
    }

    /// @dev Exact-out share quote clamp. The former 1% pad (`shares + max(shares / 100, 1)`) was removed under
    ///      APEX D55 (2026-09-21): the forward quote is wei-exact against execution, execution pays exactly the
    ///      requested amount, and any zap-out surplus stays in the vault, so the minimal sufficient share count
    ///      is the exact quote. A quote at or above the supply is the whole supply.


    function _inventorySwap(InventoryQuote memory q, uint256 amount) internal view returns (uint256) {
        Types.Snapshot memory state = _inventoryState(q);
        Inventory._collect(state.book);
        Types.Swap memory swap = Quotes._forward(_quoteParams(state, !q.token0, amount));
        Planner._afterSwap(state, swap);
        _storeInventory(q, state);
        return swap.amountOut;
    }

    function _inventoryRedemptionSwap(InventoryQuote memory q, uint256 amount) private view returns (uint256) {
        Types.Snapshot memory state = _inventoryState(q);
        Inventory._collect(state.book);
        Types.Swap memory swap = Quotes._redemptionForward(_quoteParams(state, !q.token0, amount));
        // _inventoryRedeem excluded the full entitlement, but core spends only the fill.
        state.book.free[q.token0 ? 1 : 0] += amount - swap.amountIn;
        Planner._afterSwap(state, swap);
        _storeInventory(q, state);
        return swap.amountOut;
    }

    function _inventoryPositionAmounts(InventoryQuote memory q, uint128 liquidity, bool roundUp)
        internal pure returns (uint256 amount0, uint256 amount1)
    {
        Types.PositionState memory position;
        position.sqrtPriceX96 = q.pool.sqrtPriceX96;
        position.lowerX96 = TickMath.getSqrtPriceAtTick(q.lower);
        position.upperX96 = TickMath.getSqrtPriceAtTick(q.upper);
        uint256[2] memory amounts = Inventory._amounts(position, liquidity, roundUp);
        return (amounts[0], amounts[1]);
    }

    function _inventoryChangeLiquidity(InventoryQuote memory q, int128 delta) internal pure {
        if (delta == 0) return;
        bool adding = delta > 0;
        (uint256 amount0, uint256 amount1) = _inventoryPositionAmounts(q, uint128(adding ? delta : -delta), adding);
        if (adding) {
            q.free0 -= amount0;
            q.free1 -= amount1;
        } else {
            _inventoryCollect(q);
            q.free0 += amount0;
            q.free1 += amount1;
        }
        q.positionLiquidity = LiquidityMath.addDelta(q.positionLiquidity, delta);
        q.lowerLiquidityGross = LiquidityMath.addDelta(q.lowerLiquidityGross, delta);
        q.upperLiquidityGross = LiquidityMath.addDelta(q.upperLiquidityGross, delta);
        if (q.pool.tick >= q.lower && q.pool.tick < q.upper) {
            q.pool.liquidity = LiquidityMath.addDelta(q.pool.liquidity, delta);
        }
        q.liquidityDelta += delta;
    }

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

    /// @dev Relative deadband: 5% of target free (D22).
    uint256 internal constant LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18;
    /// @dev Sink for residual first-mint dead shares (A0). Not `address(this)` so self-balance stays 0.
    address internal constant DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD);

    
    function canOpenPoolManagerUnlock() public view virtual returns (bool) {
        return !TransientStateLibrary.isUnlocked(_poolManager());
    }

    function twapOracle() public view virtual returns (IUniswapV4MultiPoolTwapOracle) {
        return UniswapV4TwapOracleAwareRepo._twapOracle();
    }

    function _pokeBoundPoolTwap() internal {
        twapOracle().update(_poolKey());
    }

    /// @dev Free ERC-20 balances of pool currencies on this diamond (D29). Never includes position math.
    function _freeBalances() internal view returns (uint256 free0, uint256 free1) {
        free0 = _localBalance(_token0());
        free1 = _localBalance(_token1());
    }

    /// @dev Deployed amounts from managed/imported positions only.
    function _deployedAmounts() internal view returns (uint256 amount0, uint256 amount1) {
        return _positionAmounts();
    }

    
    function _liveLiquidReservePercentage() internal view returns (uint256) {
        (bool active, uint256 sampled) = ExecutionContext._sleeve();
        return active ? sampled : VaultFeeOracleQueryAwareRepo._feeOracle().liquidReservePercentageOfVault(address(this));
    }

    function _targetFree(uint256 total_i, uint256 liquidPct) internal pure returns (uint256) {
        return Inventory._target(total_i, liquidPct);
    }

    /// @dev Absolute floor: 10^max(0, decimals-6) (D22).
    function _absoluteFloor(address token) internal view returns (uint256) {
        // D34: direct metadata call; a token without decimals() reverts here.
        uint8 decimals_ = IERC20Metadata(token).decimals();
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
        uint256 relativeTol = targetFree_i / 20;
        uint256 tol = floor_i > relativeTol ? floor_i : relativeTol;
        return deviation > tol;
    }

    function _requireCanOpenPoolManagerUnlock() internal view {
        if (!canOpenPoolManagerUnlock()) {
            revert UniswapV4Exchange_PoolManagerInteractionBlocked();
        }
    }

    function _poolManager() internal view returns (IPoolManager) {
        return UniswapV4FullSpreadPonsFamilyHookPoolManagerAwareRepo._poolManager();
    }

    function _poolKey() internal view returns (PoolKey memory) {
        return UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo._poolKey();
    }

    function _poolId() internal view returns (PoolId) {
        return UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo._poolId();
    }

    function _currency0() internal view returns (Currency) {
        return UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo._currency0();
    }

    function _currency1() internal view returns (Currency) {
        return UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo._currency1();
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

    function _positionInfo()
        internal
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
    {
        if (UniswapV4FullSpreadPonsFamilyHookPositionRepo._isImportedPosition()) {
            (int24 lower, int24 upper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
            (, feeGrowthInside0LastX128, feeGrowthInside1LastX128) = StateLibrary.getPositionInfo(
                _poolManager(), _poolId(), address(UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionManager()),
                lower, upper, bytes32(UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionTokenId())
            );
            liquidity = UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionManager()
                .getPositionLiquidity(UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionTokenId());
            return (liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128);
        }

        if (!UniswapV4FullSpreadPonsFamilyHookPositionRepo._isPositionCreated()) {
            return (0, 0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
        return StateLibrary.getPositionInfo(
            _poolManager(), _poolId(), address(this), tickLower, tickUpper, UniswapV4FullSpreadPonsFamilyHookPositionRepo._salt()
        );
    }

    function _currentLiquidity() internal view returns (uint128 liquidity) {
        (liquidity,,) = _positionInfo();
    }

    function _positionAmounts()
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (!UniswapV4FullSpreadPonsFamilyHookPositionRepo._isPositionCreated()) {
            return (0, 0);
        }

        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        (int24 tickLower, int24 tickUpper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
        uint128 liquidity = _currentLiquidity();
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

        Types.PositionState memory position;
        position.sqrtPriceX96 = sqrtPriceX96;
        position.lowerX96 = TickMath.getSqrtPriceAtTick(tickLower);
        position.upperX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        uint256[2] memory amounts = Inventory._amounts(position, liquidity, false);
        return (amounts[0], amounts[1]);
    }

    function _managedTicks() internal view returns (ManagedTicks memory managedTicks) {
        if (UniswapV4FullSpreadPonsFamilyHookPositionRepo._isImportedPosition()) {
            (managedTicks.centerLower, managedTicks.centerUpper) =
                UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
            return managedTicks;
        }

        if (!UniswapV4FullSpreadPonsFamilyHookPositionRepo._isPositionCreated()) {
            return _deriveManagedTicks();
        }

        (managedTicks.centerLower, managedTicks.centerUpper) =
            UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
    }

    function _quoteManagedWithdrawal(uint256 sharesBurned, uint256 totalShares)
        internal view returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtPriceX96, int24 tick,,) = _slot0();
        return _quotePositionWithdrawal(sqrtPriceX96, tick, sharesBurned, totalShares);
    }

    function _quotePositionWithdrawal(
        uint160 sqrtPriceX96,
        int24 tick,
        uint256 sharesBurned,
        uint256 totalShares
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint128 currentLiquidity = _currentLiquidity();
        if (currentLiquidity == 0 || totalShares == 0) {
            return (0, 0);
        }

        uint128 liquidityToBurn = uint128(Math.mulDiv(sharesBurned, currentLiquidity, totalShares));
        if (liquidityToBurn == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
        return _amountsForLiquidityAtPrice(sqrtPriceX96, tick, tickLower, tickUpper, liquidityToBurn);
    }

    function _syncVaultReserves() internal {
        if ((_currency0().isAddressZero() || _currency1().isAddressZero()) && address(this).balance != 0) {
            _weth().deposit{value: address(this).balance}();
        }
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token0()), IERC20(_token0()).balanceOf(address(this)));
        MultiAssetBasicVaultRepo._updateReserve(IERC20(_token1()), IERC20(_token1()).balanceOf(address(this)));
        // Book sitting vaultShare so leftover self-shares are R, not durable U (E6 / I1).
        MultiAssetBasicVaultRepo._updateReserve(
            IERC20(address(this)), IERC20(address(this)).balanceOf(address(this))
        );
    }

    
    function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        reserve0 = free0 + deployed0;
        reserve1 = free1 + deployed1;
    }

    function _freeBalancesForShareMath() internal view returns (uint256 free0, uint256 free1) {
        (free0, free1) = _freeBalances();
        (uint256 fee0, uint256 fee1) = _collectablePositionFees();
        free0 += fee0;
        free1 += fee1;
    }

    function _collectablePositionFees()
        internal view returns (uint256 fee0, uint256 fee1)
    {
        (uint128 liquidity, uint256 last0, uint256 last1) = _positionInfo();
        if (liquidity == 0) return (0, 0);
        (int24 lower, int24 upper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(_poolManager(), _poolId(), lower, upper);
        unchecked {
            fee0 = FullMath.mulDiv(growth0 - last0, liquidity, uint256(1) << 128);
            fee1 = FullMath.mulDiv(growth1 - last1, liquidity, uint256(1) << 128);
        }
    }

    /// @dev Fees belong to all outstanding shares before the next mint or burn.
    /// Views include uncollected fees even while the PoolManager is locked.
    function _collectManagedFeesIfIdle() internal {
        if (!canOpenPoolManagerUnlock()) return;
        // Advance checkpoints even when earned amounts floor to zero. Otherwise
        // old fractional growth leaks into the next independently projected swap.
        if (_currentLiquidity() == 0) return;
        if (UniswapV4FullSpreadPonsFamilyHookPositionRepo._isImportedPosition()) {
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionTokenId(), uint256(0), uint128(0), uint128(0), bytes(""));
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionManager().modifyLiquidities(
                abi.encode(abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR)), params),
                block.timestamp
            );
        } else {
            (int24 lower, int24 upper) = UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
            _executeUnlock(OperationParams({
                op: Operation.RemoveLiquidity, zeroForOne: false, amountSpecified: 0,
                tickLower: lower, tickUpper: upper, liquidity: 0, salt: UniswapV4FullSpreadPonsFamilyHookPositionRepo._salt()
            }));
        }
    }

    function _sqrtPriceLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    
    function _executeUnlock(OperationParams memory params) internal returns (BalanceDelta delta) {
        _requireCanOpenPoolManagerUnlock();
        bytes memory data = abi.encode(params);
        (uint256 budget0, uint256 budget1) = _freeBalances();
        if (params.op == Operation.SwapExactIn) {
            if (params.zeroForOne) { budget0 = params.amountSpecified; budget1 = 0; }
            else { budget0 = 0; budget1 = params.amountSpecified; }
        }
        ExecutionContext._begin(address(_poolManager()), keccak256(data), budget0, budget1);
        bytes memory result = _poolManager().unlock(data);
        ExecutionContext._finish();
        delta = abi.decode(result, (BalanceDelta));
    }

    /// @dev A single-token contribution buys growth in sqrt(x*y). A book with
    /// only one asset accepts more of that asset; adding its missing asset also
    /// requires a contribution to the existing reserve, establishing a ratio.
    function _sharesOutForDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 totalSharesBefore,
        uint256 reserve0Before,
        uint256 reserve1Before
    ) internal view returns (uint256 sharesOut) {
        return Inventory._depositShares(amount0Added, amount1Added, totalSharesBefore,
            reserve0Before, reserve1Before, totalSharesBefore == 0 ? _minimumLiquidity() : 0);
    }

    function _minimumLiquidity() internal view returns (uint256) {
        return StandardExchangeConstantProduct._minimumLiquidity(_token0(), _token1());
    }

    /// @dev Empty-supply inventory stays with the sink. Its share weight covers
    /// each contributed asset separately, without assigning unlike tokens a price.
    function _initialResidualShares(uint256 added0, uint256 added1, uint256 reserve0, uint256 reserve1, uint256 shares)
        internal pure returns (uint256)
    {
        uint256 weight0 = reserve0 == 0 ? 0 : Math.mulDiv(reserve0, shares, added0, Math.Rounding.Ceil);
        uint256 weight1 = reserve1 == 0 ? 0 : Math.mulDiv(reserve1, shares, added1, Math.Rounding.Ceil);
        return Math.max(weight0, weight1);
    }

    
    function _rebalanceLiquidReserveBestEffort() internal {
        if (!canOpenPoolManagerUnlock()) {
            return;
        }
        _rebalanceLiquidReserveInternal();
    }

    
    function _rebalanceLiquidReserveInternal() internal returns (bool moved) {
        Types.Snapshot memory state = _snapshot(0, 0);
        Types.Plan memory plan = Planner._maintenance(state, _quoteParams(state, true, 0));
        _commitExecutionPlan(keccak256(abi.encode(plan)), 0, 0);
        _collectManagedFeesIfIdle();
        if (plan.fundingRemoval.liquidityDelta != 0) _executePlacement(plan.fundingRemoval);
        if (plan.swap.amountIn != 0) _executePlannedSwap(plan.swap, false, REBALANCE_IMPACT_BPS);
        _collectManagedFeesIfIdle();
        _executePlacement(plan.placement);
        _verifyState(plan.placement.afterState);
        moved = plan.swap.amountIn != 0 || plan.fundingRemoval.liquidityDelta != 0 || plan.placement.liquidityDelta != 0;
        emit MaintenanceEvaluated(plan.maintenance, plan.swap.amountIn, plan.fundingRemoval.liquidityDelta, plan.placement.liquidityDelta);
        if (moved) _emitRebalanceEvent(state.sleeveWad);
        else _syncVaultReserves();
    }

    function _emitRebalanceEvent(uint256 liquidPct) internal {
        _syncVaultReserves();
        (uint256 free0, uint256 free1) = _freeBalances();
        (uint256 deployed0, uint256 deployed1) = _deployedAmounts();
        emit IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.LiquidReserveRebalanced(
            free0, free1, deployed0, deployed1, liquidPct
        );
    }

    function _createManagedPositionsIfNeededCommon(ManagedTicks memory managedTicks) internal {
        if (UniswapV4FullSpreadPonsFamilyHookPositionRepo._isPositionCreated()) {
            return;
        }
        // D30: center only. Wings are not created.
        UniswapV4FullSpreadPonsFamilyHookPositionRepo._createPositionIfNeeded(
            managedTicks.centerLower, managedTicks.centerUpper
        );
    }

    function _burnImportedLiquidityCommon(uint128 liquidityToBurn) internal {
        bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionTokenId(),
            uint256(liquidityToBurn),
            uint128(0),
            uint128(0),
            bytes("")
        );
        params[1] = abi.encode(_currency0(), _currency1(), address(this));
        UniswapV4FullSpreadPonsFamilyHookPositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(_poolManager())) {
            revert UniswapV4Exchange_InvalidCallbackCaller(msg.sender);
        }

        ExecutionContext._consume(msg.sender, keccak256(data));
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
        ExecutionContext._spend(Currency.unwrap(currency) == Currency.unwrap(_currency0()) ? 0 : 1, amount);
        _poolManager().sync(currency);
        if (currency.isAddressZero()) {
            if (address(this).balance < amount) _weth().withdraw(amount - address(this).balance);
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

    function _quoteSwapAfterWithdrawal(uint256 amountIn, bool zeroForOne, uint256 sharesBurned, uint256 totalShares)
        internal view returns (uint256)
    {
        if (amountIn == 0) return 0;
        Types.Snapshot memory state = _snapshot(0, 0);
        Inventory._collect(state.book);
        uint128 removed = uint128(Math.mulDiv(state.position.liquidity, sharesBurned, totalShares));
        Types.Placement memory removal = Inventory._placement(state, state.position.liquidity - removed);
        if (!removal.funded) revert AccountingMismatch();
        return Quotes._redemptionForward(_quoteParams(removal.afterState, zeroForOne, amountIn)).amountOut;
    }

    function _quoteSwapOut(uint256 amountOut, bool zeroForOne) internal view returns (uint256 amountIn) {
        if (amountOut == 0) return 0;
        return _directOutPlan(_snapshot(0, 0), zeroForOne, amountOut).swap.amountIn;
    }

    function _quoteSwapIn(uint256 amountIn, bool zeroForOne) internal view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        return Quotes._forward(_quoteParams(_snapshot(0, 0), zeroForOne, amountIn)).amountOut;
    }

    
    function _deriveManagedTicks() internal view returns (ManagedTicks memory managedTicks) {
        int24 tickSpacing = UniswapV4FullSpreadPonsFamilyHookPoolKeyAwareRepo._tickSpacing();
        managedTicks.centerLower = TickMath.minUsableTick(tickSpacing);
        managedTicks.centerUpper = TickMath.maxUsableTick(tickSpacing);
    }

    
    function _isDualPoolCurrencies(address[] calldata tokens) internal view returns (bool) {
        if (tokens.length != 2) {
            return false;
        }
        if (tokens[0] == tokens[1]) {
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
            revert UniswapV4Exchange_ZeroAmount();
        }
        s0 = FullMath.mulDivRoundingUp(amount0, supply, total0);
        s1 = FullMath.mulDivRoundingUp(amount1, supply, total1);
    }

    
    function _burnCenterLiquidityForShares(uint256 sharesBurned, uint256 totalShares) internal {
        if (sharesBurned == 0 || totalShares == 0) {
            return;
        }
        uint128 currentLiquidity = _currentLiquidity();
        if (currentLiquidity == 0) {
            return;
        }
        uint128 liquidityToBurn = uint128(Math.mulDiv(currentLiquidity, sharesBurned, totalShares));
        if (liquidityToBurn == 0) {
            return;
        }
        if (UniswapV4FullSpreadPonsFamilyHookPositionRepo._isImportedPosition()) {
            _burnImportedLiquidityCommon(liquidityToBurn);
            return;
        }
        (int24 tickLower, int24 tickUpper) =
            UniswapV4FullSpreadPonsFamilyHookPositionRepo._positionTicks();
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidityToBurn,
                salt: UniswapV4FullSpreadPonsFamilyHookPositionRepo._salt()
            })
        );
    }

    /// @dev Push credit is unbooked ERC-20 delivery; pool inventory never funds delivery.
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountIn, bool pretransferred)
        internal returns (uint256 actualIn)
    {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            uint256 avail = LocalCreditLib.available(
                tokenIn.balanceOf(address(this)),
                MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn))
            );
            if (avail < amountIn) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, avail);
            return amountIn;
        }
        uint256 beforeBalance = tokenIn.balanceOf(address(this));
        // Preserve token callback reverts (including IsLocked) through the pull.
        bytes memory result = Address.functionCall(address(tokenIn),
            abi.encodeCall(IERC20.transferFrom, (msg.sender, address(this), amountIn)));
        if (result.length != 0 && !abi.decode(result, (bool))) {
            revert SafeERC20.SafeERC20FailedOperation(address(tokenIn));
        }
        actualIn = tokenIn.balanceOf(address(this)) - beforeBalance;
        if (actualIn != amountIn) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, actualIn);
    }

    function _transferCurrency(address token, address recipient, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        if (token == address(_weth()) && (_currency0().isAddressZero() || _currency1().isAddressZero())
            && address(this).balance != 0) _weth().deposit{value: address(this).balance}();
        IERC20(token).safeTransfer(recipient, amount);
    }

    function _requireExactDelivery(uint256 requested, uint256 delivered) internal pure {
        if (requested != delivered) revert ISecurePullErrors.TransferDeltaInsufficient(requested, delivered);
    }

    function _requireDelivered(uint256 used, uint256 delivered) internal pure {
        if (used > delivered) revert ISecurePullErrors.TransferDeltaInsufficient(used, delivered);
    }

    function _pretransferCredit(IERC20 token, uint256 maximum) internal view returns (uint256) {
        return LocalCreditLib.budget(
            LocalCreditLib.available(
                token.balanceOf(address(this)),
                MultiAssetBasicVaultRepo._reserveOfToken(address(token))
            ),
            maximum
        );
    }

    function _secureShareDelivery(uint256 amountIn, bool pretransferred) internal returns (uint256 actualIn) {
        if (!pretransferred && msg.sender == address(this) && NativeStandardYieldContextRepo._initiator() != address(0)) {
            uint256 selfBalance = IERC20(address(this)).balanceOf(address(this));
            _requireDelivered(amountIn, selfBalance);
            return amountIn;
        }
        if (!pretransferred) {
            ERC20Repo._transfer(msg.sender, address(this), amountIn);
            return amountIn;
        }
        return _secureTokenTransfer(IERC20(address(this)), amountIn, true);
    }

    function _refundUnusedShares(uint256 delivered, uint256 used, address recipient) internal {
        if (delivered > used) {
            IERC20(address(this)).safeTransfer(recipient, delivered - used);
        }
    }

    function _symbolOrAddress(address token) internal view returns (string memory symbol_) {
        return IERC20Metadata(token).symbol();
    }

    event MaintenanceEvaluated(Types.MaintenanceStatus status, uint256 swapInput, int128 fundingRemoval, int128 placement);
    error AlignmentNotAchievable();
    error PriceImpactExceeded();
    error ExecutionShortfall();
    error AccountingMismatch();
    error QuoteWorkLimit();
    uint16 internal constant REBALANCE_IMPACT_BPS = 25;
    uint16 internal constant COMPOSITION_IMPACT_BPS = 50;
    uint16 internal constant EXECUTION_SHORTFALL_BPS = 10;
    uint16 internal constant DEPOSIT_ALIGNMENT_BPS = 1;
    uint16 internal constant REPAIR_COMPOSITION_BPS = 1;

    function _snapshot(uint256 credit0, uint256 credit1) internal view returns (Types.Snapshot memory state) {
        if (!_supportsInventoryQuote()) revert ITransition.InvalidQuoteState();
        state.idle = canOpenPoolManagerUnlock();
        state.book.supply = IERC20(address(this)).totalSupply();
        (state.book.free[0], state.book.free[1]) = _freeBalances();
        (state.book.earned[0], state.book.earned[1]) = _collectablePositionFees();
        state.position.liquidity = _currentLiquidity();
        ManagedTicks memory ticks = _managedTicks();
        state.position.lower = ticks.centerLower;
        state.position.upper = ticks.centerUpper;
        state.position.lowerX96 = TickMath.getSqrtPriceAtTick(ticks.centerLower);
        state.position.upperX96 = TickMath.getSqrtPriceAtTick(ticks.centerUpper);
        (state.position.sqrtPriceX96, state.position.tick,,) = _slot0();
        state.position.activeLiquidity = StateLibrary.getLiquidity(_poolManager(), _poolId());
        (state.position.lowerLiquidityGross,) = StateLibrary.getTickLiquidity(_poolManager(), _poolId(), ticks.centerLower);
        (state.position.upperLiquidityGross,) = StateLibrary.getTickLiquidity(_poolManager(), _poolId(), ticks.centerUpper);
        state.position.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(_poolKey().tickSpacing);
        state.book.deployed = Inventory._amounts(state.position, state.position.liquidity, false);
        state.sleeveWad = _liveLiquidReservePercentage();
        state.absoluteFloor = [_absoluteFloor(_token0()), _absoluteFloor(_token1())];
        state.book.credit = [credit0, credit1];
        state.book.free[0] = Inventory._free(state.book.free[0], credit0, 0, 0);
        state.book.free[1] = Inventory._free(state.book.free[1], credit1, 0, 0);
        state.book.booked = [MultiAssetBasicVaultRepo._reserveOfToken(_token0()), MultiAssetBasicVaultRepo._reserveOfToken(_token1())];
    }

    function _inventoryState(InventoryQuote memory q) internal pure returns (Types.Snapshot memory state) {
        state.idle = q.idle;
        state.book.free = [q.free0, q.free1];
        state.book.earned = [q.fees0, q.fees1];
        state.book.supply = q.supply;
        state.sleeveWad = q.sleeveWad;
        state.absoluteFloor = q.absoluteFloor;
        state.position = Types.PositionState(q.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(q.lower),
            TickMath.getSqrtPriceAtTick(q.upper), q.pool.tick, q.lower, q.upper,
            q.positionLiquidity, q.pool.liquidity, q.liquidityDelta,
            q.lowerLiquidityGross, q.upperLiquidityGross, q.maxLiquidityPerTick);
        state.book.deployed = Inventory._amounts(state.position, state.position.liquidity, false);
    }

    function _storeInventory(InventoryQuote memory q, Types.Snapshot memory state) internal pure {
        q.free0 = state.book.free[0]; q.free1 = state.book.free[1];
        q.fees0 = state.book.earned[0]; q.fees1 = state.book.earned[1];
        q.supply = state.book.supply;
        q.positionLiquidity = state.position.liquidity;
        q.liquidityDelta = state.position.liquidityChange;
        q.lowerLiquidityGross = state.position.lowerLiquidityGross;
        q.upperLiquidityGross = state.position.upperLiquidityGross;
        q.maxLiquidityPerTick = state.position.maxLiquidityPerTick;
        q.pool = UniswapV4Quoter.PoolState(state.position.sqrtPriceX96, state.position.tick, state.position.activeLiquidity);
    }

    function _quoteParams(Types.Snapshot memory state, bool zeroForOne, uint256 amount)
        internal view returns (Quotes.Params memory)
    {
        return Quotes.Params(_poolManager(), _poolKey(), state.position, zeroForOne, amount, address(_weth()));
    }

    function _directOutPlan(Types.Snapshot memory state, bool zeroForOne, uint256 amount)
        internal view returns (Types.Plan memory plan)
    {
        return Planner._directOut(state, _quoteParams(state, zeroForOne, amount),
            zeroForOne ? _token0() : _token1(), zeroForOne ? _token1() : _token0());
    }

    function _linearExitPlan(Types.Snapshot memory state, bool token0, uint256 amount)
        internal view returns (uint256 shares, Types.Placement memory placement)
    {
        uint256 output = token0 ? 0 : 1;
        uint256[2] memory backing = Inventory._totals(state.book);
        address token = token0 ? _token0() : _token1();
        if (amount == 0) return (0, placement);
        shares = _linearExitShares(backing[output], backing[1-output], state.book.supply, amount, token);
        if (state.idle) {
            Inventory._collect(state.book);
            uint128 removed = uint128(Math.mulDiv(state.position.liquidity, shares, state.book.supply));
            Types.Placement memory removal = Inventory._placement(state, state.position.liquidity - removed);
            if (!removal.funded) revert IStandardExchangeErrors.InvalidRoute(address(this), token);
            state = removal.afterState;
        }
        if (state.book.free[output] < amount) revert UniswapV4Exchange_InsufficientLocalReserve(token, amount, state.book.free[output]);
        state.book.free[output] -= amount;
        state.book.supply -= shares;
        if (state.idle) {
            placement = Planner._closedPlacement(state);
            if (!placement.certified) revert IStandardExchangeErrors.InvalidRoute(address(this), token);
        }
    }

    /// @dev Existing linear F2 quantity only. Callers retain their own funding/CC checks.
    function _linearExitShares(uint256 backingOut, uint256 backingOther, uint256 supply, uint256 amount, address token)
        internal view returns (uint256)
    {
        if (supply == 0 || backingOther != 0 || backingOut == 0 || amount > backingOut) {
            revert IStandardExchangeErrors.InvalidRoute(address(this), token);
        }
        return Math.mulDiv(amount, supply, backingOut, Math.Rounding.Ceil);
    }

    function _executePlacement(Types.Placement memory placement) internal {
        if (!placement.funded) revert AccountingMismatch();
        int128 change = placement.liquidityDelta;
        if (change == 0) return;
        ManagedTicks memory ticks = _managedTicks();
        _createManagedPositionsIfNeededCommon(ticks);
        BalanceDelta delta = _executeUnlock(OperationParams({
            op: change > 0 ? Operation.AddLiquidity : Operation.RemoveLiquidity,
            zeroForOne: false, amountSpecified: 0, tickLower: ticks.centerLower, tickUpper: ticks.centerUpper,
            liquidity: uint128(uint256(change > 0 ? int256(change) : -int256(change))),
            salt: UniswapV4FullSpreadPonsFamilyHookPositionRepo._salt()
        }));
        if (int256(delta.amount0()) != int256(placement.proceeds[0]) - int256(placement.debt[0])
            || int256(delta.amount1()) != int256(placement.proceeds[1]) - int256(placement.debt[1])) revert AccountingMismatch();
    }

    function _executePlannedSwap(Types.Swap memory swap, bool exactOutput, uint16 impact) internal {
        (uint160 beforePrice,,,) = _slot0();
        BalanceDelta delta = _executeUnlock(OperationParams({
            op: exactOutput ? Operation.SwapExactOut : Operation.SwapExactIn, zeroForOne: swap.zeroForOne,
            amountSpecified: exactOutput ? swap.amountOut : swap.amountIn,
            tickLower: 0, tickUpper: 0, liquidity: 0, salt: bytes32(0)
        }));
        int128 inDelta = swap.zeroForOne ? delta.amount0() : delta.amount1();
        int128 outDelta = swap.zeroForOne ? delta.amount1() : delta.amount0();
        if (inDelta > 0 || outDelta < 0) revert AccountingMismatch();
        uint256 spent = uint256(-int256(inDelta));
        uint256 received = uint256(int256(outDelta));
        if (!Protection._shortfallWithin(swap.amountOut, received)) revert ExecutionShortfall();
        (uint160 afterPrice, int24 tick,,) = _slot0();
        if (impact != 0 && !Protection._priceWithin(beforePrice, afterPrice, impact)) revert PriceImpactExceeded();
        if (spent != swap.amountIn || received != swap.amountOut || afterPrice != swap.sqrtPriceAfterX96
            || tick != swap.tickAfter || StateLibrary.getLiquidity(_poolManager(), _poolId()) != swap.liquidityAfter) revert AccountingMismatch();
    }

    function _verifyState(Types.Snapshot memory expected) internal view {
        if (!Inventory._matches(_snapshot(0, 0), expected)) revert AccountingMismatch();
    }

    function _dualExitPlan(Types.Snapshot memory state, uint256 amount0, uint256 amount1)
        internal view returns (uint256 shares, Types.Placement memory placement)
    {
        uint256[2] memory backing = Inventory._totals(state.book);
        if (amount0 == 0 || amount1 == 0 || backing[0] == 0 || backing[1] == 0 || state.book.supply == 0)
            revert IStandardExchangeErrors.InvalidRoute(address(this), _token0());
        (uint256 s0, uint256 s1) = _dualExitShareBurns(amount0, amount1, backing[0], backing[1], state.book.supply);
        if (s0 != s1 || s0 > state.book.supply) revert IStandardExchangeErrors.InvalidRoute(address(this), _token0());
        shares = s0;
        if (state.idle) {
            Inventory._collect(state.book);
            uint128 removed = uint128(Math.mulDiv(state.position.liquidity, shares, state.book.supply));
            Types.Placement memory removal = Inventory._placement(state, state.position.liquidity - removed);
            if (!removal.funded) revert AccountingMismatch();
            state = removal.afterState;
        }
        if (state.book.free[0] < amount0) revert UniswapV4Exchange_InsufficientLocalReserve(_token0(), amount0, state.book.free[0]);
        if (state.book.free[1] < amount1) revert UniswapV4Exchange_InsufficientLocalReserve(_token1(), amount1, state.book.free[1]);
        state.book.free[0] -= amount0; state.book.free[1] -= amount1; state.book.supply -= shares;
        // R8 alone preserves required F3 execution when combined placement is unavailable.
        if (state.idle) placement = Planner._closedPlacement(state);
    }
    function _localBalance(address token) internal view returns (uint256 balance) {
        balance = IERC20(token).balanceOf(address(this));
        if (token == address(_weth()) && (_currency0().isAddressZero() || _currency1().isAddressZero()))
            balance += address(this).balance;
    }
    function _commitExecutionPlan(bytes32 plan, uint256 liability0, uint256 liability1) internal {
        ExecutionContext._commitPlan(plan, liability0, liability1);
    }
}
