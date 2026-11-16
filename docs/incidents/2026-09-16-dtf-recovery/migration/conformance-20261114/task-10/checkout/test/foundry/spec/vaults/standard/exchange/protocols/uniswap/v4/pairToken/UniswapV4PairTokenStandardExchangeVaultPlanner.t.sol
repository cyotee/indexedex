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
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SafeCast} from "@crane/contracts/protocols/dexes/uniswap/libraries/SafeCast.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {ProjectionActor} from "./harness/ProjectionActor.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultPlannerTest[]
/// @notice Whole-operation P2 component controls using funded real-manager actors.
/// @dev Supply/book are explicit component inputs, backed by actor custody; this is not
/// a fake vault or registered-proxy acceptance evidence. No SUT store/etch/mock is used.
contract UniswapV4PairTokenStandardExchangeVaultPlannerTest is IndexedexTest {
    using PoolIdLibrary for PoolKey;

    uint160 internal constant Q96 = uint160(1) << 96;
    IPoolManager internal manager;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    PoolKey internal key;
    Types.Config internal config;
    ProjectionActor internal actor;
    ProjectionActor internal other;

    struct ReceiptControl {
        int256 net0;
        int256 net1;
        uint256 fees0;
        uint256 fees1;
        Types.Amounts book;
        Types.Amounts caller;
        Types.Amounts beforePrincipal;
    }

    // tag::setUp[]
    /// @notice Use the real canonical manager artifact and the existing component actor.
    function setUp() public override {
        super.setUp();
        manager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("PairToken.Planner.PoolManager")
        ));
        token0 = new ERC20PermitMintableStub("Planner A", "PA", 6, address(this), 0);
        token1 = new ERC20PermitMintableStub("Planner B", "PB", 18, address(this), 0);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        _pool(60, 3000, Q96, 1e18, 2e18);
    }
    // end::setUp[]

    // tag::planSnapshot[]
    /// @notice External boundary only for observing exact planner revert bytes.
    function planSnapshot(Types.Snapshot memory snapshot_, Types.Operation memory operation_)
        external view returns (Types.Plan memory)
    {
        return Planner.plan(snapshot_, operation_);
    }
    // end::planSnapshot[]

    // tag::test_PLN_LinkedPlannerRejectsDirectCalls[]
    /// @notice Compiler-generated library delegation works; direct access to the same runtime rejects.
    function test_PLN_LinkedPlannerRejectsDirectCalls() public view {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.Compound);
        Types.Plan memory delegated = Planner.plan(original, operation);
        assertEq(delegated.actions.length, 1);
        (bool success, bytes memory data) =
            address(Planner).staticcall(abi.encodeWithSelector(Planner.plan.selector, original, operation));
        assertFalse(success);
        assertEq(data, abi.encodeWithSelector(Planner.DirectCallNotAllowed.selector));
    }
    // end::test_PLN_LinkedPlannerRejectsDirectCalls[]

    // tag::test_PLN_FallbackClassifierAllPhasesAndKinds[]
    /// @notice WorkLimit includes final sale; only swap price/delta and add liquidity permit other fallback.
    function test_PLN_FallbackClassifierAllPhasesAndKinds() public pure {
        for (uint256 phase; phase <= uint256(Types.Phase.ExitSale); ++phase) {
            for (uint256 kind; kind <= uint256(Types.FailureKind.Economic); ++kind) {
                IVault.MaintenanceReason expected;
                if (kind == uint256(Types.FailureKind.WorkLimit)) {
                    expected = IVault.MaintenanceReason.MaintenanceWorkLimit;
                } else if (phase == uint256(Types.Phase.MaintenanceSwap)) {
                    if (kind == uint256(Types.FailureKind.PriceLimit)) {
                        expected = IVault.MaintenanceReason.MaintenancePriceLimit;
                    } else if (kind == uint256(Types.FailureKind.DeltaLimit)) {
                        expected = IVault.MaintenanceReason.MaintenanceDeltaLimit;
                    }
                } else if (
                    phase == uint256(Types.Phase.MaintenanceAddition)
                        && kind == uint256(Types.FailureKind.LiquidityLimit)
                ) expected = IVault.MaintenanceReason.MaintenanceLiquidityLimit;
                Types.Failure memory failure = Types.Failure(Types.Phase(phase), Types.FailureKind(kind), hex"1234");
                assertEq(uint256(Planner.maintenanceReason(failure)), uint256(expected));
            }
        }
    }
    // end::test_PLN_FallbackClassifierAllPhasesAndKinds[]

    // tag::test_PLN_EmptyCompoundExcludesReservationsAndUnbookedCustody[]
    /// @notice A funded actor with a clean owned book has no manager action and adopts nothing.
    function test_PLN_EmptyCompoundExcludesReservationsAndUnbookedCustody() public {
        _pool(120, 0, Q96, 0, 0);
        Types.Snapshot memory original = _snapshot(0, 0, 0);
        original.inventory.callerInput = Types.Amounts(1e25, 2e25);
        original.inventory.refund = Types.Amounts(3e25, 0);
        Types.Plan memory result = Planner.plan(original, _operation(Types.OperationKind.Compound));
        assertEq(result.actions.length, 0);
        assertEq(result.swapSteps, 0);
        assertEq(result.finalState.supply, 0);
        assertEq(result.finalState.inventory.booked.amount0, 0);
        assertEq(result.finalState.inventory.booked.amount1, 0);
        assertEq(result.fees.amount0, 0);
        assertEq(result.fees.amount1, 0);
        _stable(result);
        _execute(original, result);
    }
    // end::test_PLN_EmptyCompoundExcludesReservationsAndUnbookedCustody[]

    // tag::test_PLN_GenesisMintsAllGeometricSharesAndTerminalRestart[]
    /// @notice All geometric shares are issued; full paired exit drains only owned inventory.
    function test_PLN_GenesisMintsAllGeometricSharesAndTerminalRestart() public {
        _pool(120, 0, Q96, 0, 1e18);
        Types.Snapshot memory original = _snapshot(0, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(4e12, 9e12);
        Types.Plan memory entry = Planner.plan(original, operation);
        assertEq(entry.shares, 6e12);
        assertEq(entry.qQuote, 6e12);
        assertEq(entry.reserves.amount0, 0);
        assertEq(entry.reserves.amount1, 0);
        assertEq(entry.accepted.amount0, 4e12);
        assertEq(entry.accepted.amount1, 9e12);
        assertEq(entry.actions.length, 1);
        assertEq(uint256(entry.actions[0].phase), uint256(Types.Phase.EntryAddition));
        assertGt(entry.finalState.position.liquidity, 0);
        _execute(original, entry);
        Types.Operation memory exit = _operation(Types.OperationKind.RedeemPair);
        exit.shares = entry.shares;
        Types.Plan memory terminal = Planner.plan(entry.finalState, exit);
        _execute(entry.finalState, terminal);
        assertEq(terminal.finalState.supply, 0);
        assertEq(terminal.finalState.position.liquidity, 0);
        assertEq(terminal.finalState.inventory.booked.amount0, 0);
        assertEq(terminal.finalState.inventory.booked.amount1, 0);
        Types.Plan memory restarted = Planner.plan(terminal.finalState, operation);
        assertEq(restarted.shares, 6e12);
        _execute(terminal.finalState, restarted);
    }
    // end::test_PLN_GenesisMintsAllGeometricSharesAndTerminalRestart[]

    // tag::test_PLN_GenesisAndEmptyZapErrors[]
    /// @notice Empty, zero-mint and checked-product domains bubble rather than return partial plans.
    function test_PLN_GenesisAndEmptyZapErrors() public {
        _pool(120, 0, Q96, 0, 0);
        Types.Snapshot memory original = _snapshot(0, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(0, 1);
        vm.expectRevert(Math.ZeroShares.selector);
        this.planSnapshot(original, operation);
        operation.amounts = Types.Amounts(type(uint256).max, 2);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        this.planSnapshot(original, operation);
        operation.kind = Types.OperationKind.DepositZap;
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_GenesisAndEmptyZapErrors[]

    // tag::test_PLN_PositiveGenesisSharesStillRequireFundableLiquidity[]
    /// @notice Geometric output alone cannot bootstrap a position whose affordable liquidity floors to zero.
    function test_PLN_PositiveGenesisSharesStillRequireFundableLiquidity() public {
        _pool(120, 0, TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(120)), 0, 0);
        Types.Snapshot memory original = _snapshot(0, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(1, 1);
        vm.expectRevert(Math.ZeroShares.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_PositiveGenesisSharesStillRequireFundableLiquidity[]

    // tag::test_PLN_InvalidPositiveSupplyEmptyBookAndFinalSupplyOverflow[]
    /// @notice Empty backing is never a second genesis branch; supply capacity is enforced after credit.
    function test_PLN_InvalidPositiveSupplyEmptyBookAndFinalSupplyOverflow() public {
        Types.Snapshot memory original = _snapshot(type(uint256).max, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(1e10, 1e10);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        this.planSnapshot(original, operation);
        _pool(120, 0, Q96, 0, 0);
        original = _snapshot(1, 0, 0);
        vm.expectRevert(IVault.InvalidAccountingState.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_InvalidPositiveSupplyEmptyBookAndFinalSupplyOverflow[]

    // tag::test_PLN_CompoundDustAndPositiveAddCheckpoint[]
    /// @notice Dust equality skips deployment; a positive add is the final fee checkpoint.
    function test_PLN_CompoundDustAndPositiveAddCheckpoint() public {
        Types.Snapshot memory original = _snapshot(1e18, 1000, 1000);
        Types.Plan memory result = Planner.plan(original, _operation(Types.OperationKind.Compound));
        assertEq(result.actions.length, 1);
        assertEq(uint256(result.actions[0].phase), uint256(Types.Phase.MaintenanceCollection));
        assertEq(result.finalState.inventory.booked.amount0, 1000);
        _execute(original, result);
        original = _snapshot(1e18, 1001, 1001);
        result = Planner.plan(original, _operation(Types.OperationKind.Compound));
        assertEq(result.actions.length, 2);
        assertEq(uint256(result.actions[1].phase), uint256(Types.Phase.MaintenanceAddition));
        assertEq(result.finalState.supply, original.supply);
        _execute(original, result);
    }
    // end::test_PLN_CompoundDustAndPositiveAddCheckpoint[]

    // tag::test_PLN_CompoundSwapWithoutAdditionFinishesWithOneCheckpoint[]
    /// @notice A real 100-percent-fee pool produces no output leg, so swap fees require a final poke.
    function test_PLN_CompoundSwapWithoutAdditionFinishesWithOneCheckpoint() public {
        _pool(120, 1_000_000, Q96, 1e18, 2e18);
        Types.Snapshot memory original = _snapshot(1e18, 10000, 0);
        Types.Plan memory result = Planner.plan(original, _operation(Types.OperationKind.Compound));
        assertEq(result.actions.length, 3);
        assertEq(uint256(result.actions[0].phase), uint256(Types.Phase.MaintenanceCollection));
        assertEq(uint256(result.actions[1].phase), uint256(Types.Phase.MaintenanceSwap));
        assertEq(result.actions[1].amountIn, 5000);
        assertEq(int256(result.actions[1].callerDelta.amount0()), -5000);
        assertEq(int256(result.actions[1].callerDelta.amount1()), 0);
        assertEq(uint256(result.actions[2].phase), uint256(Types.Phase.MaintenanceCheckpoint));
        uint256 fee = ((uint256(5000) * (uint256(1) << 128) / 3e18) * 1e18) / (uint256(1) << 128);
        assertEq(result.fees.amount0, fee);
        assertEq(result.finalState.inventory.booked.amount0, 5000 + fee);
        assertEq(result.finalState.position.liquidity, 1e18);
        _execute(original, result);
    }
    // end::test_PLN_CompoundSwapWithoutAdditionFinishesWithOneCheckpoint[]

    // tag::test_PLN_FeesMaintenanceAndPairedCallerAttribution[]
    /// @notice The complete plan separates collection, incumbent deployment and accepted caller growth.
    function test_PLN_FeesMaintenanceAndPairedCallerAttribution() public {
        other.donate(3e12, 6e12);
        Types.Snapshot memory original = _snapshot(1e18, 7e12, 2e12);
        original.inventory.callerInput = Types.Amounts(1e24, 2e24);
        original.inventory.refund = Types.Amounts(1e25, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(2e14, 3e14);
        bytes32 beforeHash = keccak256(abi.encode(original));
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(keccak256(abi.encode(original)), beforeHash);
        assertEq(uint256(result.mode), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(result.reason), uint256(IVault.MaintenanceReason.None));
        assertEq(uint256(result.actions[result.actions.length - 1].phase), uint256(Types.Phase.EntryAddition));
        assertLe(result.accepted.amount0, operation.amounts.amount0);
        assertLe(result.accepted.amount1, operation.amounts.amount1);
        assertGt(result.fees.amount0, 0);
        assertGt(result.fees.amount1, 0);
        _execute(original, result);
    }
    // end::test_PLN_FeesMaintenanceAndPairedCallerAttribution[]

    // tag::test_PLN_ZapBothDirectionsCheckpointsAndResidualDonation[]
    /// @notice Both zaps retain residual without extra credit and collect incumbent swap fees first.
    function test_PLN_ZapBothDirectionsCheckpointsAndResidualDonation() public {
        uint256 snapshot = vm.snapshotState();
        _zap(true);
        assertTrue(vm.revertToState(snapshot));
        _zap(false);
    }
    // end::test_PLN_ZapBothDirectionsCheckpointsAndResidualDonation[]

    // tag::test_PLN_ZapCapAndTickMoveErrors[]
    /// @notice Size and movement violations are economic errors, not maintenance fallback.
    function test_PLN_ZapCapAndTickMoveErrors() public {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositZap);
        operation.token = address(token0);
        operation.amounts.amount0 = 1e18;
        vm.expectPartialRevert(Planner.ZapSizeExceeded.selector);
        this.planSnapshot(original, operation);
        original.config.maxZapTickMove = 0;
        operation.amounts.amount0 = 1e16;
        vm.expectPartialRevert(Planner.ZapTickMoveExceeded.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_ZapCapAndTickMoveErrors[]

    // tag::test_PLN_ZapSizeEqualityAndOneOver[]
    /// @notice Independent actual removal establishes the pre-swap reserve used by the cap.
    function test_PLN_ZapSizeEqualityAndOneOver() public {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        uint256 snapshot = vm.snapshotState();
        (BalanceDelta removed,) = actor.modify(config.tickLower, config.tickUpper, -1e18);
        uint256 maximum = uint256(int256(removed.amount0())) / 10;
        assertTrue(vm.revertToState(snapshot));
        Types.Operation memory operation = _operation(Types.OperationKind.DepositZap);
        operation.token = address(token0);
        operation.amounts.amount0 = maximum;
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(result.accepted.amount0, maximum);
        operation.amounts.amount0 = maximum + 1;
        vm.expectRevert(abi.encodeWithSelector(Planner.ZapSizeExceeded.selector, maximum + 1, maximum));
        this.planSnapshot(original, operation);
        _execute(original, result);
    }
    // end::test_PLN_ZapSizeEqualityAndOneOver[]

    // tag::test_PLN_ZapTickEqualityAndOneBelow[]
    /// @notice The configured stored-tick limit is inclusive, with real-manager phase parity.
    function test_PLN_ZapTickEqualityAndOneBelow() public {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositZap);
        operation.token = address(token0);
        operation.amounts.amount0 = 1e16;
        Types.Plan memory observed = Planner.plan(original, operation);
        int24 movement = original.pool.tick - observed.finalState.pool.tick;
        assertGt(movement, 0);
        original.config.maxZapTickMove = movement;
        Types.Plan memory exact = Planner.plan(original, operation);
        assertEq(exact.shares, observed.shares);
        original.config.maxZapTickMove = movement - 1;
        vm.expectRevert(abi.encodeWithSelector(
            Planner.ZapTickMoveExceeded.selector, uint256(uint24(movement)), uint256(uint24(movement - 1))
        ));
        this.planSnapshot(original, operation);
        // The witness intentionally commits immutable config too.
        original.config.maxZapTickMove = movement;
        Types.Config memory saved = config;
        config = original.config;
        _execute(original, exact);
        config = saved;
    }
    // end::test_PLN_ZapTickEqualityAndOneBelow[]

    // tag::test_PLN_PartialPairedExitAllocatesWholePositionFeesOnlyOnce[]
    /// @notice The fee checkpoint precedes the proportional removal; removal reports zero new fees.
    function test_PLN_PartialPairedExitAllocatesWholePositionFeesOnlyOnce() public {
        other.donate(3e12, 6e12);
        Types.Snapshot memory original = _snapshot(1e18, 17, 29);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = uint256(1e18) / 3;
        Types.Plan memory result = Planner.plan(original, operation);
        Types.Action memory removal = result.actions[result.actions.length - 1];
        assertEq(uint256(removal.phase), uint256(Types.Phase.ExitRemoval));
        assertEq(BalanceDelta.unwrap(removal.feesAccrued), 0);
        assertEq(result.shares, operation.shares);
        assertEq(result.finalState.supply, original.supply - operation.shares);
        assertGt(result.payout.amount0, 0);
        assertGt(result.payout.amount1, 0);
        _execute(original, result);
    }
    // end::test_PLN_PartialPairedExitAllocatesWholePositionFeesOnlyOnce[]

    // tag::test_PLN_SingleExitBothDirectionsOnlySellsAllocation[]
    /// @notice Remaining shareholders retain their book and post-removal sale fees.
    function test_PLN_SingleExitBothDirectionsOnlySellsAllocation() public {
        uint256 snapshot = vm.snapshotState();
        _singleExit(true, 1e17);
        assertTrue(vm.revertToState(snapshot));
        _singleExit(false, 1e17);
    }
    // end::test_PLN_SingleExitBothDirectionsOnlySellsAllocation[]

    // tag::test_PLN_LastSingleExitWithExternalLiquidity[]
    /// @notice Terminal sale uses genuinely remaining external liquidity.
    function test_PLN_LastSingleExitWithExternalLiquidity() public {
        _singleExit(true, 1e18);
    }
    // end::test_PLN_LastSingleExitWithExternalLiquidity[]

    // tag::test_PLN_LastSingleExitWithoutLiquidityRevertsWithoutFallback[]
    /// @notice Empty remaining pool produces incomplete sale, while paired terminal exit stays valid.
    function test_PLN_LastSingleExitWithoutLiquidityRevertsWithoutFallback() public {
        _pool(32767, 3000, Q96, 1e18, 0);
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemSingle);
        operation.shares = 1e18;
        operation.token = address(token0);
        vm.expectPartialRevert(Planner.IncompleteExitSale.selector);
        this.planSnapshot(original, operation);
        operation.kind = Types.OperationKind.RedeemPair;
        Types.Plan memory paired = Planner.plan(original, operation);
        assertEq(uint256(paired.mode), uint256(IVault.WithdrawalMode.FullCompound));
        _execute(original, paired);
    }
    // end::test_PLN_LastSingleExitWithoutLiquidityRevertsWithoutFallback[]

    // tag::test_PLN_RealTickCapacityFallbackUsesUntouchedOriginal[]
    /// @notice Real manager tick capacity rejects maintenance only; fresh collection/removal succeeds.
    function test_PLN_RealTickCapacityFallbackUsesUntouchedOriginal() public {
        Types.Snapshot memory original = _snapshot(1e18, 1e36, 1e36);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = 1e17;
        bytes32 originalHash = keccak256(abi.encode(original));
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(keccak256(abi.encode(original)), originalHash);
        assertEq(uint256(result.mode), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(result.reason), uint256(IVault.MaintenanceReason.MaintenanceLiquidityLimit));
        assertEq(result.actions.length, 2);
        assertEq(result.actions[1].liquidityDelta, -int128(1e17));
        assertEq(result.swapSteps, 0);
        assertEq(result.finalState.pool.sqrtPriceX96, original.pool.sqrtPriceX96);
        _execute(original, result);
    }
    // end::test_PLN_RealTickCapacityFallbackUsesUntouchedOriginal[]

    // tag::test_PLN_UnsignedLiquidityOverflowFallbackAndNoCompoundFallback[]
    /// @notice Inspectable Math capacity failure selects withdrawal fallback but bubbles for compound.
    function test_PLN_UnsignedLiquidityOverflowFallbackAndNoCompoundFallback() public {
        Types.Snapshot memory original = _snapshot(1e18, uint256(1) << 200, uint256(1) << 200);
        Types.Operation memory operation = _operation(Types.OperationKind.Compound);
        vm.expectRevert(Math.LiquidityOverflow.selector);
        this.planSnapshot(original, operation);
        operation.kind = Types.OperationKind.RedeemPair;
        operation.shares = 1e18;
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(uint256(result.reason), uint256(IVault.MaintenanceReason.MaintenanceLiquidityLimit));
        assertEq(result.finalState.supply, 0);
        _execute(original, result);
    }
    // end::test_PLN_UnsignedLiquidityOverflowFallbackAndNoCompoundFallback[]

    // tag::test_PLN_RealCollectionOverflowCannotSelectFallback[]
    /// @notice Fee collection failure remains economic even when the book would separately exceed capacity.
    function test_PLN_RealCollectionOverflowCannotSelectFallback() public {
        for (uint256 i; i < 7; ++i) other.donate(uint256(1) << 126, 0);
        Types.Snapshot memory original = _snapshot(1e18, 1e36, 1e36);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = 1e17;
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_RealCollectionOverflowCannotSelectFallback[]

    // tag::test_PLN_WholeMaintenanceWorkLimitSelectsFreshPairCandidate[]
    /// @notice A real narrow external position leaves a long low-liquidity traversal in normal maintenance.
    function test_PLN_WholeMaintenanceWorkLimitSelectsFreshPairCandidate() public {
        _pool(1, 0, Q96, 1, 0);
        other.modify(-1, 1, 1e18);
        Types.Snapshot memory original = _snapshot(1, 1e16, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = 1;
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(uint256(result.mode), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(result.reason), uint256(IVault.MaintenanceReason.MaintenanceWorkLimit));
        assertEq(result.swapSteps, 0);
        assertEq(result.actions.length, 2);
        _execute(original, result);
    }
    // end::test_PLN_WholeMaintenanceWorkLimitSelectsFreshPairCandidate[]

    // tag::test_PLN_OneSidedPairedIdleCreditWithoutAddition[]
    /// @notice Positive supply at the usable lower endpoint accepts the complete live-leg maximum.
    function test_PLN_OneSidedPairedIdleCreditWithoutAddition() public {
        _pool(120, 0, TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(120)), 1, 0);
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(100, 1e18);
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(result.accepted.amount0, 100);
        assertEq(result.accepted.amount1, 0);
        assertEq(result.credit.amount0, 100);
        Types.Amounts memory removable = _removable();
        assertEq(result.reserves.amount0, removable.amount0);
        assertEq(result.reserves.amount1, 0);
        assertEq(result.growth.amount0, 0);
        assertEq(result.growth.amount1, 0);
        assertEq(result.residual.amount0, 100);
        assertEq(result.residual.amount1, 0);
        assertEq(result.qQuote, uint256(100) * original.supply / removable.amount0);
        assertEq(result.shares, result.qQuote);
        assertEq(result.actions.length, 1);
        assertEq(result.finalState.position.liquidity, 1);
        _execute(original, result);
    }
    // end::test_PLN_OneSidedPairedIdleCreditWithoutAddition[]

    // tag::test_PLN_TinyPairedZeroPayoutRejects[]
    /// @notice A positive-share burn that floors both principal and idle to zero is not a valid plan.
    function test_PLN_TinyPairedZeroPayoutRejects() public {
        Types.Snapshot memory original = _snapshot(type(uint128).max, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = 1;
        vm.expectRevert(IVault.ZeroPayout.selector);
        this.planSnapshot(original, operation);
    }
    // end::test_PLN_TinyPairedZeroPayoutRejects[]

    // tag::test_PLN_InitialWitnessCoversLaterSwapWord[]
    /// @notice A future-read bitmap change invalidates the initial witness without changing current price.
    function test_PLN_InitialWitnessCoversLaterSwapWord() public {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositZap);
        operation.token = address(token0);
        operation.amounts.amount0 = 1e16;
        Types.Plan memory result = Planner.plan(original, operation);
        assertTrue(Projection.check(original, address(actor), result.ticks, result.words, result.initialState));
        assertGt(result.words.length, 2);
        other.modify(-120, -60, 1e15);
        assertFalse(Projection.check(original, address(actor), result.ticks, result.words, result.initialState));
        (uint160 price,,,) = StateLibrary.getSlot0(manager, key.toId());
        assertEq(price, original.pool.sqrtPriceX96);
    }
    // end::test_PLN_InitialWitnessCoversLaterSwapWord[]

    // tag::testFuzz_PLN_PairedEntryAndExitManagerParity[]
    /// @notice Bounded exact-input sequences check every manager delta, phase witness and ledger conservation.
    function testFuzz_PLN_PairedEntryAndExitManagerParity(uint64 amount0_, uint64 amount1_, uint64 book_) public {
        Types.Snapshot memory original = _snapshot(1e18, bound(book_, 0, 1e13), 37);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositPair);
        operation.amounts = Types.Amounts(bound(amount0_, 1e8, 1e16), bound(amount1_, 1e8, 1e16));
        Types.Plan memory entry = Planner.plan(original, operation);
        _execute(original, entry);
        operation = _operation(Types.OperationKind.RedeemPair);
        operation.shares = entry.shares;
        Types.Plan memory exit = Planner.plan(entry.finalState, operation);
        _execute(entry.finalState, exit);
        assertEq(exit.finalState.supply, original.supply);
    }
    // end::testFuzz_PLN_PairedEntryAndExitManagerParity[]

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
        config.maxZapTickMove = 600;
        config.rateAsset = address(token0);
        if (owned_ != 0) actor.modify(config.tickLower, config.tickUpper, int256(uint256(owned_)));
        if (external_ != 0) other.modify(config.tickLower, config.tickUpper, int256(uint256(external_)));
    }

    function _snapshot(uint256 supply_, uint256 book0_, uint256 book1_)
        internal view returns (Types.Snapshot memory)
    {
        Types.Inventory memory inventory;
        inventory.booked = Types.Amounts(book0_, book1_);
        return Projection.loadSnapshot(config, inventory, supply_, address(actor));
    }

    function _operation(Types.OperationKind kind_) internal pure returns (Types.Operation memory result) {
        result.kind = kind_;
    }

    function _zap(bool input0_) internal {
        Types.Snapshot memory original = _snapshot(1e18, 0, 0);
        Types.Operation memory operation = _operation(Types.OperationKind.DepositZap);
        operation.token = input0_ ? address(token0) : address(token1);
        operation.amounts = input0_ ? Types.Amounts(1e14, 0) : Types.Amounts(0, 1e14);
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(result.actions.length, 4);
        assertEq(uint256(result.actions[1].phase), uint256(Types.Phase.EntrySwap));
        assertEq(result.actions[1].amountIn, 5e13);
        assertEq(uint256(result.actions[2].phase), uint256(Types.Phase.EntryCheckpoint));
        assertEq(uint256(result.actions[3].phase), uint256(Types.Phase.EntryAddition));
        assertEq(BalanceDelta.unwrap(result.actions[3].feesAccrued), 0);
        assertGt(input0_ ? result.fees.amount0 : result.fees.amount1, 0);
        assertGt(result.shares, 0);
        assertEq(result.qQuote, 0);
        assertGt(result.uncredited.amount0 + result.uncredited.amount1, 0);
        assertEq(result.residual.amount0, result.uncredited.amount0);
        assertEq(result.residual.amount1, result.uncredited.amount1);
        assertEq(result.finalState.inventory.booked.amount0, result.fees.amount0 + result.uncredited.amount0);
        assertEq(result.finalState.inventory.booked.amount1, result.fees.amount1 + result.uncredited.amount1);
        _execute(original, result);
    }

    function _singleExit(bool output0_, uint256 shares_) internal {
        Types.Snapshot memory original = _snapshot(1e18, 17, 29);
        Types.Operation memory operation = _operation(Types.OperationKind.RedeemSingle);
        operation.token = output0_ ? address(token0) : address(token1);
        operation.shares = shares_;
        Types.Plan memory result = Planner.plan(original, operation);
        assertEq(result.actions.length, 3);
        Types.Action memory removal = result.actions[1];
        Types.Action memory sale = result.actions[2];
        assertEq(uint256(removal.phase), uint256(Types.Phase.ExitRemoval));
        assertEq(uint256(sale.phase), uint256(Types.Phase.ExitSale));
        assertEq(BalanceDelta.unwrap(removal.feesAccrued), 0);
        uint256 allocated = uint256(int256(output0_ ? removal.callerDelta.amount1() : removal.callerDelta.amount0()))
            + (output0_ ? uint256(29) : uint256(17)) * shares_ / 1e18;
        assertEq(sale.amountIn, allocated);
        assertEq(uint256(-int256(output0_ ? sale.callerDelta.amount1() : sale.callerDelta.amount0())), allocated);
        assertEq(output0_ ? result.payout.amount1 : result.payout.amount0, 0);
        assertGt(output0_ ? result.payout.amount0 : result.payout.amount1, 0);
        _execute(original, result);
        if (shares_ < original.supply) {
            (, BalanceDelta remainingFees) = actor.modify(config.tickLower, config.tickUpper, 0);
            assertGt(int256(output0_ ? remainingFees.amount1() : remainingFees.amount0()), 0);
        }
    }

    function _execute(Types.Snapshot memory original_, Types.Plan memory result_) internal {
        assertLe(result_.actions.length, 6);
        assertEq(uint256(result_.failure.kind), uint256(Types.FailureKind.None));
        assertTrue(Projection.check(original_, address(actor), result_.ticks, result_.words, result_.initialState));
        ReceiptControl memory control;
        control.book = Types.Amounts(original_.inventory.booked.amount0, original_.inventory.booked.amount1);
        control.caller = Types.Amounts(result_.accepted.amount0, result_.accepted.amount1);
        for (uint256 i; i < result_.actions.length; ++i) {
            Types.Action memory action = result_.actions[i];
            if (action.phase == Types.Phase.EntryAddition) control.beforePrincipal = _removable();
            uint256 before0 = token0.balanceOf(address(actor));
            uint256 before1 = token1.balanceOf(address(actor));
            BalanceDelta delta;
            BalanceDelta fees;
            if (action.kind == Types.ActionKind.ModifyLiquidity) {
                (delta, fees) = actor.modify(config.tickLower, config.tickUpper, int256(action.liquidityDelta));
            } else {
                delta = actor.swap(action.zeroForOne, action.amountIn, action.sqrtPriceLimitX96);
            }
            assertEq(BalanceDelta.unwrap(delta), BalanceDelta.unwrap(action.callerDelta));
            assertEq(BalanceDelta.unwrap(fees), BalanceDelta.unwrap(action.feesAccrued));
            assertEq(int256(token0.balanceOf(address(actor))) - int256(before0), int256(delta.amount0()));
            assertEq(int256(token1.balanceOf(address(actor))) - int256(before1), int256(delta.amount1()));
            control.net0 += int256(delta.amount0());
            control.net1 += int256(delta.amount1());
            control.fees0 += uint256(int256(fees.amount0()));
            control.fees1 += uint256(int256(fees.amount1()));
            _entryReceipts(original_, result_, control, action);
            assertTrue(Projection.check(original_, address(actor), result_.ticks, result_.words, action.afterState));
        }
        assertEq(control.fees0, result_.fees.amount0);
        assertEq(control.fees1, result_.fees.amount1);
        assertEq(
            int256(original_.inventory.booked.amount0 + result_.accepted.amount0) + control.net0,
            int256(result_.finalState.inventory.booked.amount0 + result_.payout.amount0)
        );
        assertEq(
            int256(original_.inventory.booked.amount1 + result_.accepted.amount1) + control.net1,
            int256(result_.finalState.inventory.booked.amount1 + result_.payout.amount1)
        );
        Types.Snapshot memory actual = Projection.loadSnapshot(
            config, result_.finalState.inventory, result_.finalState.supply, address(actor)
        );
        assertEq(keccak256(abi.encode(actual.pool, actual.position)), keccak256(abi.encode(result_.finalState.pool, result_.finalState.position)));
        assertEq(TransientStateLibrary.currencyDelta(manager, address(actor), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(manager, address(actor), key.currency1), 0);
        _stable(result_);
    }

    function _entryReceipts(
        Types.Snapshot memory original_,
        Types.Plan memory result_,
        ReceiptControl memory control_,
        Types.Action memory action_
    ) internal {
        if (action_.phase == Types.Phase.EntrySwap || action_.phase == Types.Phase.EntryAddition) {
            control_.caller.amount0 = uint256(int256(control_.caller.amount0) + int256(action_.callerDelta.amount0()));
            control_.caller.amount1 = uint256(int256(control_.caller.amount1) + int256(action_.callerDelta.amount1()));
        } else if (
            action_.phase != Types.Phase.ExitRemoval && action_.phase != Types.Phase.ExitSale
        ) {
            control_.book.amount0 = uint256(int256(control_.book.amount0) + int256(action_.callerDelta.amount0()));
            control_.book.amount1 = uint256(int256(control_.book.amount1) + int256(action_.callerDelta.amount1()));
        }
        if (action_.phase != Types.Phase.EntryAddition) return;
        // Independent removable principal comes from actual manager removals, not FMath.
        Types.Amounts memory afterPrincipal = _removable();
        Types.Amounts memory growth = Types.Amounts(
            afterPrincipal.amount0 - control_.beforePrincipal.amount0,
            afterPrincipal.amount1 - control_.beforePrincipal.amount1
        );
        assertEq(result_.growth.amount0, growth.amount0);
        assertEq(result_.growth.amount1, growth.amount1);
        assertEq(result_.residual.amount0, control_.caller.amount0);
        assertEq(result_.residual.amount1, control_.caller.amount1);
        bool paired = result_.operation.kind == Types.OperationKind.DepositPair;
        Types.Amounts memory credit = Types.Amounts(
            growth.amount0 + (paired ? control_.caller.amount0 : 0),
            growth.amount1 + (paired ? control_.caller.amount1 : 0)
        );
        assertEq(result_.credit.amount0, credit.amount0);
        assertEq(result_.credit.amount1, credit.amount1);
        if (!paired) {
            assertEq(result_.uncredited.amount0, control_.caller.amount0);
            assertEq(result_.uncredited.amount1, control_.caller.amount1);
        }
        uint256 reserve0 = control_.beforePrincipal.amount0 + control_.book.amount0;
        uint256 reserve1 = control_.beforePrincipal.amount1 + control_.book.amount1;
        assertEq(result_.reserves.amount0, reserve0);
        assertEq(result_.reserves.amount1, reserve1);
        if (original_.supply == 0) {
            assertEq(result_.qQuote, result_.shares);
            return;
        }
        // Component fuzz domain is deliberately small enough for independent direct products.
        uint256 expected = type(uint256).max;
        if (reserve0 != 0) expected = original_.supply * credit.amount0 / reserve0;
        if (reserve1 != 0) {
            uint256 leg = original_.supply * credit.amount1 / reserve1;
            if (leg < expected) expected = leg;
        }
        if (paired) {
            uint256 quote = type(uint256).max;
            if (reserve0 != 0) quote = original_.supply * result_.operation.amounts.amount0 / reserve0;
            if (reserve1 != 0) {
                uint256 leg = original_.supply * result_.operation.amounts.amount1 / reserve1;
                if (leg < quote) quote = leg;
            }
            assertEq(result_.qQuote, quote);
            if (quote < expected) expected = quote;
        } else assertEq(result_.qQuote, 0);
        assertEq(result_.shares, expected);
        assertLe(result_.shares * reserve0, original_.supply * credit.amount0);
        assertLe(result_.shares * reserve1, original_.supply * credit.amount1);
    }

    function _removable() internal returns (Types.Amounts memory amounts) {
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(
            manager, key.toId(), address(actor), config.tickLower, config.tickUpper, bytes32(0)
        );
        if (liquidity == 0) return amounts;
        uint256 snapshot = vm.snapshotState();
        (BalanceDelta delta, BalanceDelta fees) = actor.modify(
            config.tickLower, config.tickUpper, -int256(uint256(liquidity))
        );
        amounts.amount0 = uint256(int256(delta.amount0()) - int256(fees.amount0()));
        amounts.amount1 = uint256(int256(delta.amount1()) - int256(fees.amount1()));
        assertTrue(vm.revertToState(snapshot));
    }

    function _stable(Types.Plan memory result_) internal pure {
        Types.Inventory memory inventory = result_.finalState.inventory;
        assertEq(inventory.callerInput.amount0, 0);
        assertEq(inventory.callerInput.amount1, 0);
        assertEq(inventory.exitAllocation.amount0, 0);
        assertEq(inventory.exitAllocation.amount1, 0);
        assertEq(inventory.refund.amount0, 0);
        assertEq(inventory.refund.amount1, 0);
        assertEq(inventory.wrapped.callerInput, 0);
        assertEq(inventory.wrapped.exitAllocation, 0);
        assertEq(inventory.wrapped.refund, 0);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultPlannerTest[]
