// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SafeCast} from "@crane/contracts/protocols/dexes/uniswap/libraries/SafeCast.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {ProjectionActor} from "./harness/ProjectionActor.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultProjectionTest[]
/// @notice P2 component evidence against real manager positions, not A27 product acceptance.
/// @dev No fake vault, manager replacement, SUT storage injection or etching. All pool
/// states below arise through initialize/modify/swap/donate on the artifact-loaded manager.
contract UniswapV4PairTokenStandardExchangeVaultProjectionTest is IndexedexTest {
    using PoolIdLibrary for PoolKey;

    uint160 internal constant Q96 = uint160(1) << 96;
    uint256 internal constant Q128 = uint256(1) << 128;
    IPoolManager internal manager;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    PoolKey internal key;
    Types.Config internal config;
    ProjectionActor internal actor;
    ProjectionActor internal other;

    struct OneStepControl {
        uint256 nextPrice;
        uint256 output;
        uint256 protocolAmount;
        uint256 lpGrowth;
    }

    // tag::setUp[]
    /// @notice Deploy the real protocol artifact through the existing CREATE3 infrastructure.
    function setUp() public override {
        super.setUp();
        manager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("PairToken.Projection.PoolManager")
        ));
        token0 = new ERC20PermitMintableStub("Projection A", "PA", 6, address(this), 0);
        token1 = new ERC20PermitMintableStub("Projection B", "PB", 18, address(this), 0);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        _pool(60, 3000, Q96, 1e18, 2e18);
    }
    // end::setUp[]

    // tag::test_PRO_CanonicalPositionKeyAndLoader[]
    /// @notice Loader selects only the actor's zero-salt range, with independent packed-key control.
    function test_PRO_CanonicalPositionKeyAndLoader() public {
        actor.modifySalted(config.tickLower, config.tickUpper, 7e17, bytes32(uint256(1)));
        Types.ProjectedState memory projected = _load();
        bytes32 expectedKey = keccak256(abi.encodePacked(address(actor), config.tickLower, config.tickUpper, bytes32(0)));
        assertEq(
            Position.calculatePositionKey(address(actor), config.tickLower, config.tickUpper, bytes32(0)),
            expectedKey
        );
        assertEq(StateLibrary.getPositionLiquidity(manager, key.toId(), expectedKey), 1e18);
        assertEq(projected.state.position.liquidity, 1e18);
        assertEq(projected.state.pool.liquidity, 37e17);
        (uint128 owned, uint256 last0, uint256 last1) =
            StateLibrary.getPositionInfo(manager, key.toId(), address(actor), config.tickLower, config.tickUpper, bytes32(0));
        assertEq(projected.state.position.liquidity, owned);
        assertEq(projected.state.position.feeGrowthInside0LastX128, last0);
        assertEq(projected.state.position.feeGrowthInside1LastX128, last1);
        _assertState(projected);
    }
    // end::test_PRO_CanonicalPositionKeyAndLoader[]

    // tag::test_PRO_ModifyPokeAndPartialRemoval[]
    /// @notice Whole-position fees use old liquidity, additions checkpoint, later removals do not double-collect.
    function test_PRO_ModifyPokeAndPartialRemoval() public {
        other.donate(3e12, 6e12);
        Types.ProjectedState memory projected = _load();
        uint256 expectedFee0 = ((uint256(3e12) * Q128 / 3e18) * 1e18) / Q128;
        uint256 expectedFee1 = ((uint256(6e12) * Q128 / 3e18) * 1e18) / Q128;
        (BalanceDelta delta, BalanceDelta fees, Types.Failure memory failure) =
            Projection.modify(projected, 5e17, Types.Phase.MaintenanceAddition);
        _success(failure);
        assertEq(int256(fees.amount0()), int256(expectedFee0));
        assertEq(int256(fees.amount1()), int256(expectedFee1));
        _actualModify(projected, 5e17, delta, fees);
        (delta, fees, failure) = Projection.modify(projected, 0, Types.Phase.MaintenanceCheckpoint);
        _success(failure);
        assertEq(BalanceDelta.unwrap(fees), 0);
        _actualModify(projected, 0, delta, fees);
        (delta, fees, failure) = Projection.modify(projected, -5e17, Types.Phase.ExitRemoval);
        _success(failure);
        assertEq(BalanceDelta.unwrap(fees), 0);
        _actualModify(projected, -5e17, delta, fees);
        assertEq(projected.state.position.liquidity, 1e18);
    }
    // end::test_PRO_ModifyPokeAndPartialRemoval[]

    // tag::test_PRO_FeeInclusiveAmountsExcludeReservations[]
    /// @notice Independent fee floors plus actual complete removal equal fee-inclusive amounts.
    function test_PRO_FeeInclusiveAmountsExcludeReservations() public {
        other.donate(3e12, 6e12);
        Types.ProjectedState memory projected = _load();
        projected.state.inventory.booked = Types.Amounts(17, 29);
        projected.state.inventory.callerInput = Types.Amounts(1e30, 2e30);
        projected.state.inventory.exitAllocation = Types.Amounts(3e30, 4e30);
        projected.state.inventory.refund = Types.Amounts(5e30, 6e30);
        Types.Amounts memory amounts = Projection.positionAmounts(projected);
        (BalanceDelta actual,) = actor.modify(config.tickLower, config.tickUpper, -1e18);
        assertEq(amounts.amount0, uint256(int256(actual.amount0())) + 17);
        assertEq(amounts.amount1, uint256(int256(actual.amount1())) + 29);
    }
    // end::test_PRO_FeeInclusiveAmountsExcludeReservations[]

    // tag::test_PRO_IndependentOneStepProtocolFeeBothDirections[]
    /// @notice Integer controls independently derive price, output and fee growth in both directions.
    function test_PRO_IndependentOneStepProtocolFeeBothDirections() public {
        uint256 snapshot = vm.snapshotState();
        _oneStep(true, 1000);
        assertTrue(vm.revertToState(snapshot));
        _oneStep(false, 500);
    }
    // end::test_PRO_IndependentOneStepProtocolFeeBothDirections[]

    // tag::test_PRO_ProtocolOnlyFeeHasNoLPGrowth[]
    /// @notice A zero-LP-fee pool assigns every trading fee to the directional protocol fee.
    function test_PRO_ProtocolOnlyFeeHasNoLPGrowth() public {
        _pool(60, 0, Q96, 1e18, 2e18);
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, 1000);
        Types.ProjectedState memory projected = _load();
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, true, 1e9, TickMath.MIN_SQRT_PRICE + 1, Types.Phase.EntrySwap);
        _success(failure);
        _actualSwap(projected, true, 1e9, TickMath.MIN_SQRT_PRICE + 1, delta);
        assertEq(projected.state.pool.feeGrowthGlobal0X128, 0);
        assertEq(manager.protocolFeesAccrued(key.currency0), 1e6);
    }
    // end::test_PRO_ProtocolOnlyFeeHasNoLPGrowth[]

    // tag::test_PRO_InitializedCrossingAndStoredBoundaryBothDirections[]
    /// @notice Initialized crossings change active liquidity and preserve the directional stored tick.
    function test_PRO_InitializedCrossingAndStoredBoundaryBothDirections() public {
        other.modify(-60, 60, 4e18);
        uint256 snapshot = vm.snapshotState();
        _boundarySwap(true, -120);
        assertTrue(vm.revertToState(snapshot));
        _boundarySwap(false, 120);
    }
    // end::test_PRO_InitializedCrossingAndStoredBoundaryBothDirections[]

    // tag::test_PRO_ClearAndReinitializeBoundaryOverlays[]
    /// @notice Last boundary removal clears every tick field and bitmap bit; re-add uses fresh fee checkpoints.
    function test_PRO_ClearAndReinitializeBoundaryOverlays() public {
        other.modify(config.tickLower, config.tickUpper, -2e18);
        other.donate(1e12, 2e12);
        Types.ProjectedState memory projected = _load();
        Types.ProjectedState memory original = Projection.capture(projected);
        (BalanceDelta delta, BalanceDelta fees, Types.Failure memory failure) =
            Projection.modify(projected, -1e18, Types.Phase.ExitRemoval);
        _success(failure);
        _actualModify(projected, -1e18, delta, fees);
        assertEq(projected.ticks[0].current.liquidityGross, 0);
        assertEq(projected.ticks[0].current.feeGrowthOutside0X128, 0);
        assertEq(projected.ticks[1].current.liquidityGross, 0);
        assertEq(projected.ticks[1].current.feeGrowthOutside1X128, 0);
        assertEq(projected.ticks[0].initial.liquidityGross, 1e18);
        assertEq(original.ticks[0].current.liquidityGross, 1e18);
        (delta, fees, failure) = Projection.modify(projected, 1e18, Types.Phase.EntryAddition);
        _success(failure);
        assertEq(BalanceDelta.unwrap(fees), 0);
        _actualModify(projected, 1e18, delta, fees);
    }
    // end::test_PRO_ClearAndReinitializeBoundaryOverlays[]

    // tag::test_PRO_EndpointAndOutsidePrincipalDomains[]
    /// @notice Actual manager addition and removal control both endpoints and both outside domains.
    function test_PRO_EndpointAndOutsidePrincipalDomains() public {
        _endpoint(-887220, 61);
        _endpoint(887220, 62);
        _endpoint(-887272, 63);
        _endpoint(887271, 64);
    }
    // end::test_PRO_EndpointAndOutsidePrincipalDomains[]

    // tag::test_PRO_Word16Allowed17FailsAndSharedCounter[]
    /// @notice Real empty-word progress consumes canonical iterations, not just initialized crossings.
    function test_PRO_Word16Allowed17FailsAndSharedCounter() public {
        _pool(1, 0, Q96, 0, 0);
        Types.ProjectedState memory projected = _load();
        Types.Snapshot memory original = abi.decode(abi.encode(projected.state), (Types.Snapshot));
        uint160 firstLimit = TickMath.getSqrtPriceAtTick(-3072);
        (BalanceDelta first, Types.Failure memory failure) =
            Projection.swap(projected, true, 1, firstLimit, Types.Phase.MaintenanceSwap);
        _success(failure);
        assertEq(projected.swapSteps, 13);
        assertEq(projected.wordCount, 15);
        assertEq(BalanceDelta.unwrap(first), 0);
        uint160 secondLimit = TickMath.getSqrtPriceAtTick(-3328);
        (BalanceDelta second, Types.Failure memory secondFailure) =
            Projection.swap(projected, true, 1, secondLimit, Types.Phase.ExitSale);
        _success(secondFailure);
        assertEq(projected.swapSteps, 14);
        assertEq(projected.wordCount, 16);
        assertEq(BalanceDelta.unwrap(second), 0);
        _assertDelta(actor.swap(true, 1, firstLimit), first);
        _actualSwap(projected, true, 1, secondLimit, second);
        Types.ProjectedState memory completed = Projection.capture(projected);
        (, failure) = Projection.swap(
            projected, true, 1, TickMath.getSqrtPriceAtTick(-3584), Types.Phase.ExitSale
        );
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.WorkLimit));
        assertEq(uint256(failure.phase), uint256(Types.Phase.ExitSale));
        assertEq(failure.revertData, abi.encodeWithSelector(IVault.QuoteBitmapWordsExceeded.selector, 17, 16));
        assertEq(projected.swapSteps, 15);
        assertEq(projected.wordCount, 16);
        assertEq(keccak256(abi.encode(projected.state)), keccak256(abi.encode(completed.state)));
        // Fresh fallback uses the immutable original, not the failed mutable candidate.
        // Pool state is a passed snapshot; only unchanged tick/word records are re-read.
        Types.ProjectedState memory fallbackCandidate = Projection.fresh(original);
        assertEq(fallbackCandidate.swapSteps, 0);
        assertEq(fallbackCandidate.state.pool.sqrtPriceX96, Q96);
        assertEq(fallbackCandidate.state.pool.tick, 0);
        assertEq(fallbackCandidate.state.position.liquidity, 0);
    }
    // end::test_PRO_Word16Allowed17FailsAndSharedCounter[]

    // tag::test_PRO_OneSwapRequiredWord17[]
    /// @notice A single long swap returns a typed failure rather than a partial valid quote.
    function test_PRO_OneSwapRequiredWord17() public {
        _pool(1, 0, Q96, 0, 0);
        Types.ProjectedState memory projected = _load();
        Types.ProjectedState memory untouched = Projection.capture(projected);
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, true, 1, TickMath.getSqrtPriceAtTick(-131072), Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.WorkLimit));
        assertEq(BalanceDelta.unwrap(delta), 0);
        assertEq(failure.revertData, abi.encodeWithSelector(IVault.QuoteBitmapWordsExceeded.selector, 17, 16));
        assertEq(projected.swapSteps, 15);
        assertEq(projected.wordCount, 16);
        assertEq(untouched.swapSteps, 0);
        assertEq(untouched.state.pool.sqrtPriceX96, Q96);
        assertEq(untouched.wordCount, 2);
        assertGt(projected.wordCount, untouched.wordCount);
    }
    // end::test_PRO_OneSwapRequiredWord17[]

    // tag::test_PRO_FutureOnlyTickInvalidatesInitialWitness[]
    /// @notice An off-price future tick mutation is caught before the first planned action.
    function test_PRO_FutureOnlyTickInvalidatesInitialWitness() public {
        _futureMutation(true);
    }
    // end::test_PRO_FutureOnlyTickInvalidatesInitialWitness[]

    // tag::test_PRO_FutureOnlyWordInvalidatesInitialWitness[]
    /// @notice Initializing a later-only bitmap bit invalidates the full-plan witness at unchanged price.
    function test_PRO_FutureOnlyWordInvalidatesInitialWitness() public {
        _futureMutation(false);
    }
    // end::test_PRO_FutureOnlyWordInvalidatesInitialWitness[]

    // tag::test_PRO_PhaseCaptureAndLocalReservationIndependence[]
    /// @notice Complete-key phase witnesses permit prior own actions and separate local-ledger mutations.
    function test_PRO_PhaseCaptureAndLocalReservationIndependence() public {
        other.modify(60000, 60120, 1e18);
        Types.ProjectedState memory projected = _load();
        Types.ProjectedState memory initial = Projection.capture(projected);
        (BalanceDelta delta, BalanceDelta fees, Types.Failure memory failure) =
            Projection.modify(projected, 1e17, Types.Phase.MaintenanceAddition);
        _success(failure);
        Types.ProjectedState memory checkpoint = Projection.capture(projected);
        (, failure) = Projection.swap(
            projected, false, 1e25, TickMath.getSqrtPriceAtTick(60060), Types.Phase.ExitSale
        );
        _success(failure);
        _assertInitialWitness(initial, projected);
        {
            (BalanceDelta actual, BalanceDelta actualFees) = actor.modify(config.tickLower, config.tickUpper, 1e17);
            _assertDelta(actual, delta);
            _assertDelta(actualFees, fees);
        }
        (int24[] memory ticks, int16[] memory words) = Projection.readKeys(projected);
        Types.Witness memory expected = Projection.witness(checkpoint, projected);
        checkpoint.state.supply = 123;
        checkpoint.state.inventory.booked = Types.Amounts(77, 99);
        checkpoint.state.inventory.callerInput = Types.Amounts(1e20, 2e20);
        checkpoint.state.inventory.exitAllocation = Types.Amounts(3e20, 4e20);
        checkpoint.state.inventory.refund = Types.Amounts(5e20, 6e20);
        checkpoint.state.inventory.wrapped.callerInput = 1e19;
        assertTrue(Projection.check(checkpoint.state, address(actor), ticks, words, expected));
        // This is a canonical-state check, NOT evidence that arbitrary book changes are valid.
        // The product executor must validate its own book/supply transitions separately.
        checkpoint.state.config.maxZapBps += 1;
        assertFalse(Projection.check(checkpoint.state, address(actor), ticks, words, expected));
    }
    // end::test_PRO_PhaseCaptureAndLocalReservationIndependence[]

    function _assertInitialWitness(Types.ProjectedState memory initial_, Types.ProjectedState memory complete_)
        internal view
    {
        (int24[] memory ticks_, int16[] memory words_) = Projection.readKeys(complete_);
        Types.Witness memory expected_ = Projection.witness(initial_, complete_);
        assertTrue(Projection.check(initial_.state, address(actor), ticks_, words_, expected_));
    }

    // tag::test_PRO_RealModularGrowthAndCheckpoint[]
    /// @notice Real donations put growth near uint256 wrap; a 100% fee swap wraps and a poke collects three.
    function test_PRO_RealModularGrowthAndCheckpoint() public {
        _pool(60, 1_000_000, Q96, 1, 0);
        uint256 donation = uint256(uint128(type(int128).max));
        other.donate(donation, donation);
        actor.modify(config.tickLower, config.tickUpper, 0);
        other.donate(donation, donation);
        actor.modify(config.tickLower, config.tickUpper, 0);
        Types.ProjectedState memory projected = _load();
        assertEq(projected.state.pool.feeGrowthGlobal0X128, type(uint256).max - 2 * Q128 + 1);
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, true, 3, TickMath.MIN_SQRT_PRICE + 1, Types.Phase.MaintenanceSwap);
        _success(failure);
        assertEq(int256(delta.amount0()), -3);
        assertEq(int256(delta.amount1()), 0);
        assertEq(projected.state.pool.feeGrowthGlobal0X128, Q128);
        _actualSwap(projected, true, 3, TickMath.MIN_SQRT_PRICE + 1, delta);
        BalanceDelta fees;
        (delta, fees, failure) = Projection.modify(projected, 0, Types.Phase.MaintenanceCheckpoint);
        _success(failure);
        assertEq(int256(fees.amount0()), 3);
        assertEq(int256(fees.amount1()), 0);
        _actualModify(projected, 0, delta, fees);
    }
    // end::test_PRO_RealModularGrowthAndCheckpoint[]

    // tag::test_PRO_CapacityAndPrincipalFailuresAreTyped[]
    /// @notice Real capacity and canonical principal bounds return the precise maintenance classification.
    function test_PRO_CapacityAndPrincipalFailuresAreTyped() public {
        uint128 maximum = Pool.tickSpacingToMaxLiquidityPerTick(32767);
        _pool(32767, 0, Q96, maximum, 0);
        Types.ProjectedState memory projected = _load();
        (, , Types.Failure memory failure) = Projection.modify(projected, 1, Types.Phase.MaintenanceAddition);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.LiquidityLimit));
        assertEq(uint256(failure.phase), uint256(Types.Phase.MaintenanceAddition));
        assertEq(failure.revertData, abi.encodeWithSelector(Pool.TickLiquidityOverflow.selector, config.tickLower));
        vm.expectRevert(abi.encodeWithSelector(Pool.TickLiquidityOverflow.selector, config.tickLower));
        actor.modify(config.tickLower, config.tickUpper, 1);

        _pool(60, 1, TickMath.getSqrtPriceAtTick(-887220), 0, 0);
        projected = _load();
        (, , failure) = Projection.modify(projected, 1e22, Types.Phase.MaintenanceAddition);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.LiquidityLimit));
        assertEq(failure.revertData, abi.encodeWithSelector(SafeCast.SafeCastOverflow.selector));
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        actor.modify(config.tickLower, config.tickUpper, 1e22);
    }
    // end::test_PRO_CapacityAndPrincipalFailuresAreTyped[]

    // tag::test_PRO_UnrepresentableFeesAreNotMaintenanceCapacity[]
    /// @notice A real fee receipt overflow stays economic, even when an addition would collect it.
    function test_PRO_UnrepresentableFeesAreNotMaintenanceCapacity() public {
        _pool(60, 1_000_000, Q96, 1, 0);
        other.donate(uint256(uint128(type(int128).max)), 0);
        other.donate(1, 0);
        Types.ProjectedState memory projected = _load();
        (, , Types.Failure memory failure) = Projection.modify(projected, 1, Types.Phase.MaintenanceAddition);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.Economic));
        assertEq(uint256(failure.phase), uint256(Types.Phase.MaintenanceAddition));
        assertEq(failure.revertData, abi.encodeWithSelector(SafeCast.SafeCastOverflow.selector));
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        actor.modify(config.tickLower, config.tickUpper, 1);
    }
    // end::test_PRO_UnrepresentableFeesAreNotMaintenanceCapacity[]

    // tag::test_PRO_SignedSwapEndpointsAndLargePartialRequest[]
    /// @notice Positive int128 settlement maximum is valid; one more fails even though its negative delta fits.
    function test_PRO_SignedSwapEndpointsAndLargePartialRequest() public {
        _pool(60, 1_000_000, Q96, 1e18, 0);
        Types.ProjectedState memory projected = _load();
        uint256 endpoint = uint256(uint128(type(int128).max));
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, false, endpoint, TickMath.MAX_SQRT_PRICE - 1, Types.Phase.MaintenanceSwap);
        _success(failure);
        assertEq(int256(delta.amount1()), -int256(endpoint));
        _actualSwap(projected, false, endpoint, TickMath.MAX_SQRT_PRICE - 1, delta);
        projected = _load();
        (, failure) =
            Projection.swap(projected, false, endpoint + 1, TickMath.MAX_SQRT_PRICE - 1, Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.DeltaLimit));
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        actor.swap(false, endpoint + 1, TickMath.MAX_SQRT_PRICE - 1);

        _pool(60, 2, Q96, 1e18, 0);
        projected = _load();
        uint160 limit = TickMath.getSqrtPriceAtTick(1);
        (delta, failure) = Projection.swap(projected, false, uint256(1) << 255, limit, Types.Phase.EntrySwap);
        _success(failure);
        assertGt(-int256(delta.amount1()), 0);
        assertLt(uint256(-int256(delta.amount1())), uint256(1) << 127);
        _actualSwap(projected, false, uint256(1) << 255, limit, delta);
    }
    // end::test_PRO_SignedSwapEndpointsAndLargePartialRequest[]

    // tag::test_PRO_UnsupportedAndEmptyDomainsReturnFailure[]
    /// @notice Invalid quantity, price interval, empty poke and over-removal never masquerade as success.
    function test_PRO_UnsupportedAndEmptyDomainsReturnFailure() public {
        Types.ProjectedState memory projected = _load();
        (, Types.Failure memory failure) =
            Projection.swap(projected, true, 1, Q96, Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.PriceLimit));
        (, failure) = Projection.swap(
            projected, true, (uint256(1) << 255) + 1, TickMath.MIN_SQRT_PRICE + 1, Types.Phase.MaintenanceSwap
        );
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.DeltaLimit));
        (, failure) = Projection.swap(projected, false, 0, TickMath.MAX_SQRT_PRICE - 1, Types.Phase.EntrySwap);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.Economic));
        (, , failure) =
            Projection.modify(projected, int256(type(int128).max) + 1, Types.Phase.MaintenanceAddition);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.LiquidityLimit));
        (, , failure) = Projection.modify(projected, -int256(1e18 + 1), Types.Phase.ExitRemoval);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.LiquidityLimit));
        _pool(1, 0, Q96, 0, 0);
        projected = _load();
        (, , failure) = Projection.modify(projected, 0, Types.Phase.MaintenanceCollection);
        assertEq(uint256(failure.kind), uint256(Types.FailureKind.Economic));
        assertEq(failure.revertData, abi.encodeWithSelector(Position.CannotUpdateEmptyPosition.selector));
    }
    // end::test_PRO_UnsupportedAndEmptyDomainsReturnFailure[]

    // tag::testFuzz_PRO_SwapAddRemoveRealManagerParity[]
    /// @notice Bounded real-manager sequences cover both directions with independent receipt/state comparisons.
    function testFuzz_PRO_SwapAddRemoveRealManagerParity(bool zeroForOne_, uint64 input_, uint64 add_) public {
        uint256 input = bound(input_, 1, 1e17);
        int256 addition = int256(bound(add_, 1, 1e18));
        Types.ProjectedState memory projected = _load();
        uint160 limit = zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, zeroForOne_, input, limit, Types.Phase.EntrySwap);
        _success(failure);
        _actualSwap(projected, zeroForOne_, input, limit, delta);
        BalanceDelta fees;
        (delta, fees, failure) = Projection.modify(projected, addition, Types.Phase.EntryAddition);
        _success(failure);
        _actualModify(projected, addition, delta, fees);
        (delta, fees, failure) = Projection.modify(projected, -addition, Types.Phase.ExitRemoval);
        _success(failure);
        assertEq(BalanceDelta.unwrap(fees), 0);
        _actualModify(projected, -addition, delta, fees);
    }
    // end::testFuzz_PRO_SwapAddRemoveRealManagerParity[]

    function _pool(int24 spacing_, uint24 fee_, uint160 price_, uint128 owned_, uint128 external_) internal {
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), fee_, spacing_, IHooks(address(0)));
        manager.initialize(key, price_);
        actor = new ProjectionActor(manager, key);
        other = new ProjectionActor(manager, key);
        token0.mint(address(actor), uint256(1) << 240);
        token1.mint(address(actor), uint256(1) << 240);
        token0.mint(address(other), uint256(1) << 240);
        token1.mint(address(other), uint256(1) << 240);
        config.poolManager = manager;
        config.poolKey = key;
        config.tickLower = TickMath.minUsableTick(spacing_);
        config.tickUpper = TickMath.maxUsableTick(spacing_);
        config.maxZapBps = 1000;
        config.rateAsset = address(token0);
        if (owned_ != 0) actor.modify(config.tickLower, config.tickUpper, int256(uint256(owned_)));
        if (external_ != 0) other.modify(config.tickLower, config.tickUpper, int256(uint256(external_)));
    }

    function _load() internal view returns (Types.ProjectedState memory) {
        Types.Inventory memory inventory;
        return Projection.load(config, inventory, 1e18, address(actor));
    }

    function _success(Types.Failure memory failure_) internal pure {
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
    }

    function _assertDelta(BalanceDelta actual_, BalanceDelta expected_) internal pure {
        assertEq(int256(actual_.amount0()), int256(expected_.amount0()));
        assertEq(int256(actual_.amount1()), int256(expected_.amount1()));
    }

    function _assertState(Types.ProjectedState memory projected_) internal view {
        (int24[] memory ticks, int16[] memory words) = Projection.readKeys(projected_);
        assertTrue(Projection.check(projected_.state, address(actor), ticks, words, Projection.witness(projected_)));
        assertEq(TransientStateLibrary.currencyDelta(manager, address(actor), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(manager, address(actor), key.currency1), 0);
    }

    function _actualModify(
        Types.ProjectedState memory projected_, int256 amount_, BalanceDelta delta_, BalanceDelta fees_
    ) internal {
        uint256 before0 = token0.balanceOf(address(actor));
        uint256 before1 = token1.balanceOf(address(actor));
        (BalanceDelta delta, BalanceDelta fees) = actor.modify(config.tickLower, config.tickUpper, amount_);
        _assertDelta(delta, delta_);
        _assertDelta(fees, fees_);
        _balances(before0, before1, delta);
        _assertState(projected_);
    }

    function _actualSwap(
        Types.ProjectedState memory projected_, bool zeroForOne_, uint256 input_, uint160 limit_, BalanceDelta delta_
    ) internal {
        uint256 before0 = token0.balanceOf(address(actor));
        uint256 before1 = token1.balanceOf(address(actor));
        BalanceDelta actual = actor.swap(zeroForOne_, input_, limit_);
        _assertDelta(actual, delta_);
        _balances(before0, before1, actual);
        _assertState(projected_);
    }

    function _balances(uint256 before0_, uint256 before1_, BalanceDelta delta_) internal view {
        assertEq(int256(token0.balanceOf(address(actor))) - int256(before0_), int256(delta_.amount0()));
        assertEq(int256(token1.balanceOf(address(actor))) - int256(before1_), int256(delta_.amount1()));
    }

    function _oneStep(bool zeroForOne_, uint16 protocol_) internal {
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(1000) | (uint24(500) << 12));
        Types.ProjectedState memory projected = _load();
        OneStepControl memory expected = _oneStepControl(zeroForOne_, protocol_);
        uint160 limit = zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, zeroForOne_, 1e9, limit, Types.Phase.EntrySwap);
        _success(failure);
        assertEq(projected.state.pool.sqrtPriceX96, expected.nextPrice);
        assertEq(int256(zeroForOne_ ? delta.amount0() : delta.amount1()), -int256(1e9));
        assertEq(int256(zeroForOne_ ? delta.amount1() : delta.amount0()), int256(expected.output));
        assertEq(
            zeroForOne_ ? projected.state.pool.feeGrowthGlobal0X128 : projected.state.pool.feeGrowthGlobal1X128,
            expected.lpGrowth
        );
        _actualSwap(projected, zeroForOne_, 1e9, limit, delta);
        assertEq(manager.protocolFeesAccrued(zeroForOne_ ? key.currency0 : key.currency1), expected.protocolAmount);
    }

    function _oneStepControl(bool zeroForOne_, uint16 protocol_)
        internal pure returns (OneStepControl memory expected)
    {
        uint256 input = 1e9;
        uint256 combinedFee = protocol_ + 3000 - uint256(protocol_) * 3000 / 1_000_000;
        uint256 effective = input * (1_000_000 - combinedFee) / 1_000_000;
        uint256 liquidity = 3e18;
        if (zeroForOne_) {
            uint256 numerator = liquidity * Q96;
            expected.nextPrice = (numerator + liquidity + effective - 1) / (liquidity + effective);
            expected.output = liquidity * (Q96 - expected.nextPrice) / Q96;
        } else {
            expected.nextPrice = Q96 + effective * Q96 / liquidity;
            expected.output = ((liquidity * Q96) * (expected.nextPrice - Q96) / expected.nextPrice) / Q96;
        }
        expected.protocolAmount = input * protocol_ / 1_000_000;
        expected.lpGrowth = (input - effective - expected.protocolAmount) * Q128 / liquidity;
    }

    function _boundarySwap(bool zeroForOne_, int24 tick_) internal {
        Types.ProjectedState memory projected = _load();
        uint160 limit = TickMath.getSqrtPriceAtTick(tick_);
        (BalanceDelta delta, Types.Failure memory failure) =
            Projection.swap(projected, zeroForOne_, 1e20, limit, Types.Phase.EntrySwap);
        _success(failure);
        // tick_ is a price limit, not necessarily a bitmap boundary. At +/-60 the
        // initialized crossing itself stores tickNext-1 for leftward movement.
        _actualSwap(projected, zeroForOne_, 1e20, limit, delta);
        assertEq(projected.state.pool.liquidity, 3e18);
        projected = _load();
        bool reverse = !zeroForOne_;
        int24 initializedTick = zeroForOne_ ? int24(-60) : int24(60);
        limit = TickMath.getSqrtPriceAtTick(initializedTick);
        (delta, failure) = Projection.swap(projected, reverse, 1e20, limit, Types.Phase.EntrySwap);
        _success(failure);
        _actualSwap(projected, reverse, 1e20, limit, delta);
        assertEq(projected.state.pool.tick, reverse ? initializedTick - 1 : initializedTick);
        assertEq(projected.state.pool.sqrtPriceX96, limit);
        assertEq(projected.state.pool.liquidity, 7e18);
    }

    function _endpoint(int24 tick_, uint24 fee_) internal {
        _pool(60, fee_, TickMath.getSqrtPriceAtTick(tick_), 0, 0);
        Types.ProjectedState memory projected = _load();
        // L=1 keeps endpoint token costs inside int128 while exercising ceil/floor.
        (BalanceDelta delta, BalanceDelta fees, Types.Failure memory failure) =
            Projection.modify(projected, 1, Types.Phase.EntryAddition);
        _success(failure);
        _actualModify(projected, 1, delta, fees);
        if (tick_ <= config.tickLower) assertEq(int256(delta.amount1()), 0);
        if (tick_ >= config.tickUpper) assertEq(int256(delta.amount0()), 0);
        Types.Amounts memory principal = Projection.positionAmounts(projected);
        (delta, fees, failure) = Projection.modify(projected, -1, Types.Phase.ExitRemoval);
        _success(failure);
        assertEq(principal.amount0, uint256(int256(delta.amount0())));
        assertEq(principal.amount1, uint256(int256(delta.amount1())));
        _actualModify(projected, -1, delta, fees);
    }

    function _futureMutation(bool existingTick_) internal {
        other.modify(60000, 60120, 1e18);
        Types.ProjectedState memory projected = _load();
        Types.ProjectedState memory initial = Projection.capture(projected);
        (, Types.Failure memory failure) = Projection.swap(
            projected, false, 1e25, TickMath.getSqrtPriceAtTick(60060), Types.Phase.ExitSale
        );
        _success(failure);
        (int24[] memory ticks, int16[] memory words) = Projection.readKeys(projected);
        Types.Witness memory expected = Projection.witness(initial, projected);
        assertGt(projected.tickCount, initial.tickCount);
        assertGt(projected.wordCount, initial.wordCount);
        assertTrue(Projection.check(initial.state, address(actor), ticks, words, expected));
        bytes32 poolBefore = keccak256(abi.encode(_load().state.pool));
        if (existingTick_) other.modify(60000, 60120, 1);
        else other.modify(50040, 50100, 1);
        assertEq(keccak256(abi.encode(_load().state.pool)), poolBefore);
        assertFalse(Projection.check(initial.state, address(actor), ticks, words, expected));
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultProjectionTest[]
