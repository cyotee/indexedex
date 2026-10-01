// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest[]
/// @notice Actual core settlement controls for planning; this is not a deployed vault acceptance suite.
contract UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest is TestBase_UniswapV4FullSpreadPonsFamilyHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal manager;
    PoolKey internal key;
    int24 internal lower = -887_220;
    int24 internal upper = 887_220;
    uint128 internal ownLiquidity = 1_000e18;
    bool internal callbackActive;

    struct CompositionControl {
        Types.Snapshot beforeState;
        Types.Plan plan;
        BalanceDelta fees;
        BalanceDelta placement;
        BalanceDelta repricedPrincipal;
        uint256 credit;
    }

    function setUp() public override {
        super.setUp();
        manager = poolManager;
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e32);
        key = PoolKey({
            currency0: Currency.wrap(address(a) < address(b) ? address(a) : address(b)),
            currency1: Currency.wrap(address(a) < address(b) ? address(b) : address(a)),
            fee: 0, tickSpacing: 60, hooks: IHooks(address(ponsHook))
        });
        _registerKey();
        manager.initialize(key, TickMath.getSqrtPriceAtTick(120));
        _modify(1_000_000e18, bytes32(uint256(1)));
        _modify(int256(uint256(ownLiquidity)), bytes32(0));
    }

    function test_forwardBothDirectionsMatchesCoreExactly() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            Quotes.Params memory params = _params(direction == 0, 1e18);
            Types.Swap memory quote = Quotes._forward(params);
            BalanceDelta delta = _swap(direction == 0, -int256(params.amount));
            _assertSwap(quote, delta);
            BalanceDelta fees = _modify(0, bytes32(0));
            uint256 expectedOwnFees = quote.feeGrowthInsideX128 * ownLiquidity / (uint256(1) << 128);
            assertEq(uint128(direction == 0 ? fees.amount0() : fees.amount1()), expectedOwnFees);
            assertLe(quote.steps, 64);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function test_oneStepExactOutputBothDirectionsMatchesCoreExactly() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            Quotes.Params memory params = _params(direction == 0, 1e18);
            Types.Swap memory quote = Quotes._exactOutput(params);
            BalanceDelta delta = _swap(direction == 0, int256(params.amount));
            _assertSwap(quote, delta);
            assertEq(quote.steps, 1);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function exactOutput(bool zeroForOne_, uint256 amount_) external view returns (Types.Swap memory) {
        return Quotes._exactOutput(_params(zeroForOne_, amount_));
    }

    function test_exactOutputCrossingFirstWordRejected() public {
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector,
            Currency.unwrap(key.currency0), Currency.unwrap(key.currency1)));
        this.exactOutput(true, 100_000e18);
    }

    function test_compositionPlansSettleBothDirectionsWithExactBookAndShareMath() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            _compositionSettlement(direction == 0, 1e18);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function test_closedPlacementMatchesActualSignedCoreDelta() public {
        Types.Snapshot memory state = _state();
        state.book.free[0] += 10e18;
        state.book.free[1] += 10e18;
        Types.Placement memory plan = Planner._closedPlacement(state);
        assertTrue(plan.certified);
        assertGt(plan.liquidityDelta, 0);
        BalanceDelta delta = _modify(plan.liquidityDelta, bytes32(0));
        assertEq(uint128(-delta.amount0()), plan.debt[0]);
        assertEq(uint128(-delta.amount1()), plan.debt[1]);
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(manager, key.toId(), address(this), lower, upper, bytes32(0));
        assertEq(liquidity, plan.afterState.position.liquidity);
    }

    function test_noDirectionalRoomRetainsValidZeroSwapBothExtremes() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            _freshKey(60);
            ownLiquidity = 0;
            manager.initialize(key, direction == 0 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
            Types.Snapshot memory state = _state();
            state.book.free[direction] = 100e18;
            Types.Plan memory plan = Planner._composition(state, _params(direction == 0, 0), 1e18);
            assertTrue(plan.valid);
            assertEq(plan.swap.amountIn, 0);
            assertGt(plan.shares, 0);
            (, bool filled) = Quotes._tryForward(_params(direction == 0, 1e18));
            assertFalse(filled);
            Types.Plan memory repair = Planner._maintenance(state, _params(true, 0));
            assertTrue(repair.valid);
            assertEq(repair.swap.amountIn, 0);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function test_sharedEndpointCapacityMaxAndOneAboveAgainstCore() public {
        _freshKey(60);
        ownLiquidity = 0;
        manager.initialize(key, uint160(1) << 96);
        ERC20PermitMintableStub(Currency.unwrap(key.currency0)).mint(address(this), 1e38);
        ERC20PermitMintableStub(Currency.unwrap(key.currency1)).mint(address(this), 1e38);
        uint128 maximum = Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        _modify(int256(uint256(maximum - 100)), bytes32(uint256(1)));
        Types.Snapshot memory state = _state();
        state.book.free = [uint256(240), uint256(240)];
        state.absoluteFloor = [uint256(1), uint256(1)];
        Types.Placement memory atCapacity = Inventory._placement(state, 100);
        assertTrue(atCapacity.funded);
        assertFalse(Inventory._placement(state, 101).funded);
        uint256 snapshot = vm.snapshotState();
        _modify(100, bytes32(0));
        assertTrue(vm.revertToStateAndDelete(snapshot));
        vm.expectPartialRevert(Pool.TickLiquidityOverflow.selector);
        this.modifyForTest(101);
        assertFalse(Planner._closedPlacement(state).certified);
    }

    function test_sharedFullEndpointsOptionalMaintenanceDefers() public {
        _freshKey(60);
        ownLiquidity = 0;
        manager.initialize(key, uint160(1) << 96);
        ERC20PermitMintableStub(Currency.unwrap(key.currency0)).mint(address(this), 1e38);
        ERC20PermitMintableStub(Currency.unwrap(key.currency1)).mint(address(this), 1e38);
        _modify(int256(uint256(Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing))), bytes32(uint256(1)));
        Types.Snapshot memory state = _state();
        state.book.free = [uint256(120), uint256(120)];
        state.absoluteFloor = [uint256(1), uint256(1)];
        assertFalse(Planner._closedPlacement(state).certified);
        Types.Plan memory plan = Planner._maintenance(state, _params(true, 0));
        assertTrue(plan.valid);
        assertEq(plan.swap.amountIn, 0);
        assertEq(plan.placement.liquidityDelta, 0);
        assertEq(uint256(plan.maintenance), uint256(Types.MaintenanceStatus.Deferred));
    }

    function modifyForTest(int256 amount_) external { _modify(amount_, bytes32(0)); }

    function test_directionalProtocolFeesAndOwnLpRecoveryMatchIndependentFloors() public {
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(500 | (1_000 << 12)));
        test_oneStepExactOutputBothDirectionsMatchesCoreExactly();
        uint256 gross = 1e18;
        Types.Swap memory quote = Quotes._forward(_params(true, gross));
        _assertSwap(quote, _swap(true, -int256(gross)));
        uint256 protocol = gross * 500 / 1_000_000;
        assertEq(manager.protocolFeesAccrued(key.currency0), protocol);
        uint256 feePips = 500;
        uint256 fee = gross - gross * (1_000_000 - feePips) / 1_000_000;
        assertEq(quote.feeAmount, fee);
        uint256 growth = (fee - protocol) * (uint256(1) << 128) / quote.liquidityAfter;
        uint256 owned = growth * ownLiquidity / (uint256(1) << 128);
        BalanceDelta collected = _modify(0, bytes32(0));
        assertEq(uint128(collected.amount0()), owned);
    }

    function test_64StepBoundRejectsTruncationButAllowsMultiStepSuccess() public {
        _freshKey(1);
        lower = TickMath.MIN_TICK; upper = TickMath.MAX_TICK;
        ownLiquidity = 0;
        manager.initialize(key, uint160(1) << 96);
        _modify(1_000_000e18, bytes32(uint256(1)));
        (Types.Swap memory truncated, bool filled) = Quotes._tryForward(_params(true, 1e30));
        assertFalse(filled);
        assertEq(truncated.steps, 64);
        Types.Swap memory complete = Quotes._forward(_params(true, 1e24));
        assertGt(complete.steps, 1);
        assertLe(complete.steps, 64);
        _assertSwap(complete, _swap(true, -int256(1e24)));
    }

    function test_exactOutputRejectsHundredPercentFee() public {
        key.fee = 1_000_000;
        ownLiquidity = 0;
        manager.initialize(key, TickMath.getSqrtPriceAtTick(120));
        _modify(1_000_000e18, bytes32(uint256(1)));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector,
            Currency.unwrap(key.currency1), Currency.unwrap(key.currency0)));
        this.exactOutput(false, 1);
    }

    function _registerKey() internal {
        ponsHook.registerPool(key, Currency.unwrap(key.currency1), address(this), address(this),
            100, false, ponsHook.currentFeePolicy());
    }

    function _freshKey(int24 spacing_) internal {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Fresh A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Fresh B", "B", 18, address(this), 1e32);
        key = PoolKey(Currency.wrap(address(a) < address(b) ? address(a) : address(b)),
            Currency.wrap(address(a) < address(b) ? address(b) : address(a)), 0, spacing_, IHooks(address(ponsHook)));
        lower = TickMath.minUsableTick(spacing_); upper = TickMath.maxUsableTick(spacing_);
        _registerKey();
    }

    function _compositionSettlement(bool zeroForOne_, uint256 credit_) internal {
        Types.Snapshot memory state = _state();
        uint256 gasBefore = gasleft();
        Types.Plan memory plan = Planner._composition(state, _params(zeroForOne_, 0), credit_);
        emit log_named_uint("composition planning gas", gasBefore - gasleft());
        assertTrue(plan.valid);
        assertLe(plan.refinements, 32);
        assertLe(plan.evaluations, 37);
        assertLe(plan.swap.steps, 64);
        BalanceDelta swapDelta = _swap(zeroForOne_, -int256(plan.swap.amountIn));
        _assertSwap(plan.swap, swapDelta);
        CompositionControl memory control;
        control.beforeState = state;
        control.plan = plan;
        control.credit = credit_;
        control.fees = _modify(0, bytes32(0));
        uint256 snapshot = vm.snapshotState();
        control.repricedPrincipal = _modify(-int256(uint256(state.position.liquidity)), bytes32(0));
        assertTrue(vm.revertToStateAndDelete(snapshot));
        control.placement = _modify(plan.placement.liquidityDelta, bytes32(0));
        _assertCompositionBook(control);
    }

    function _assertCompositionBook(CompositionControl memory control_)
        internal view
    {
        uint256[2] memory incumbent;
        for (uint256 i; i < 2; ++i) {
            incumbent[i] = _assertCompositionLeg(control_, i);
        }
        uint256 m0 = control_.beforeState.book.supply * control_.plan.contribution[0] / incumbent[0];
        uint256 m1 = control_.beforeState.book.supply * control_.plan.contribution[1] / incumbent[1];
        assertEq(control_.plan.shares, m0 < m1 ? m0 : m1);
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(manager, key.toId(), address(this), lower, upper, bytes32(0));
        assertEq(liquidity, control_.plan.placement.afterState.position.liquidity);
    }

    function _assertCompositionLeg(CompositionControl memory control_, uint256 i_) internal pure returns (uint256 incumbent_) {
        uint256 fee = uint128(i_ == 0 ? control_.fees.amount0() : control_.fees.amount1());
        uint256 principal = uint128(i_ == 0 ? control_.repricedPrincipal.amount0() : control_.repricedPrincipal.amount1());
        int128 placementDelta = i_ == 0 ? control_.placement.amount0() : control_.placement.amount1();
        bool input = (i_ == 0) == control_.plan.swap.zeroForOne;
        uint256 contribution = input ? control_.credit - control_.plan.swap.amountIn : control_.plan.swap.amountOut;
        incumbent_ = control_.beforeState.book.free[i_] + principal + fee;
        uint256 free = control_.beforeState.book.free[i_] + fee + contribution;
        if (placementDelta < 0) free -= uint128(-placementDelta);
        else free += uint128(placementDelta);
        assertEq(free, control_.plan.placement.afterState.book.free[i_]);
        assertEq(contribution - control_.plan.placement.roundingLoss[i_], control_.plan.contribution[i_]);
        // Independent small-fixture products: no production protection helper is
        // used to decide the expected pass/fail result.
        assertGe(10_000 * control_.plan.shares * incumbent_,
            9_999 * control_.beforeState.book.supply * control_.plan.contribution[i_]);
    }

    function _assertSwap(Types.Swap memory quote_, BalanceDelta actual_) internal view {
        assertEq(uint128(-(quote_.zeroForOne ? actual_.amount0() : actual_.amount1())), quote_.amountIn);
        assertEq(uint128(quote_.zeroForOne ? actual_.amount1() : actual_.amount0()), quote_.amountOut);
        (uint160 price, int24 tick,,) = StateLibrary.getSlot0(manager, key.toId());
        assertEq(price, quote_.sqrtPriceAfterX96);
        assertEq(tick, quote_.tickAfter);
        assertEq(StateLibrary.getLiquidity(manager, key.toId()), quote_.liquidityAfter);
    }

    function _params(bool zeroForOne_, uint256 amount_) internal view returns (Quotes.Params memory params_) {
        params_.manager = manager;
        params_.key = key;
        params_.position = _state().position;
        params_.zeroForOne = zeroForOne_;
        params_.amount = amount_;
    }

    function _state() internal view returns (Types.Snapshot memory state_) {
        state_.idle = true;
        state_.sleeveWad = 0.2e18;
        state_.book.supply = 1_000e18;
        state_.absoluteFloor = [uint256(1e12), uint256(1e12)];
        (state_.position.sqrtPriceX96, state_.position.tick,,) = StateLibrary.getSlot0(manager, key.toId());
        state_.position.lower = lower;
        state_.position.upper = upper;
        state_.position.lowerX96 = TickMath.getSqrtPriceAtTick(lower);
        state_.position.upperX96 = TickMath.getSqrtPriceAtTick(upper);
        state_.position.liquidity = ownLiquidity;
        state_.position.activeLiquidity = StateLibrary.getLiquidity(manager, key.toId());
        (state_.position.lowerLiquidityGross,) = StateLibrary.getTickLiquidity(manager, key.toId(), lower);
        (state_.position.upperLiquidityGross,) = StateLibrary.getTickLiquidity(manager, key.toId(), upper);
        state_.position.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        state_.book.deployed = Inventory._amounts(state_.position, ownLiquidity, false);
        state_.book.free[0] = state_.book.deployed[0] / 5;
        state_.book.free[1] = state_.book.deployed[1] / 5;
    }

    function _modify(int256 liquidity_, bytes32 salt_) internal returns (BalanceDelta) {
        return _unlock(abi.encode(uint8(0), liquidity_, salt_, false));
    }

    /// @notice Real principal/fee separation for independent observed-maintenance controls.
    function _modifyWithFees(int256 liquidity_, bytes32 salt_) internal returns (BalanceDelta delta_, BalanceDelta fees_) {
        callbackActive = true;
        (delta_, fees_) = abi.decode(manager.unlock(abi.encode(uint8(0), liquidity_, salt_, false)), (BalanceDelta, BalanceDelta));
        callbackActive = false;
    }

    function _swap(bool direction_, int256 amount_) internal returns (BalanceDelta) {
        return _unlock(abi.encode(uint8(1), amount_, bytes32(0), direction_));
    }

    function _unlock(bytes memory data_) internal returns (BalanceDelta delta_) {
        callbackActive = true;
        delta_ = abi.decode(manager.unlock(data_), (BalanceDelta));
        callbackActive = false;
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager) && callbackActive, "unexpected callback");
        (uint8 operation, int256 amount, bytes32 salt, bool direction) = abi.decode(data_, (uint8, int256, bytes32, bool));
        BalanceDelta delta;
        BalanceDelta fees;
        if (operation == 0) {
            (delta, fees) = manager.modifyLiquidity(key, ModifyLiquidityParams(lower, upper, amount, salt), "");
        } else {
            delta = manager.swap(key, SwapParams(direction, amount, direction ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        }
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return abi.encode(delta, fees);
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), uint128(-delta_));
            manager.settle();
        } else if (delta_ > 0) manager.take(currency_, address(this), uint128(delta_));
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookCoreSettlementTest[]
