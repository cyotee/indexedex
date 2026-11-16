// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultWorkBudgetTest[]
/// @notice S1-P07/A28/A70: independent admission boundaries and real atomic exit safety.
contract UniswapV4PairTokenStandardExchangeVaultWorkBudgetTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;

    // tag::test_BUD_Crossing12Allowed13RejectedWithoutFetchingTick[]
    /// @notice Admit crossing twelve and reject thirteen before fetching its tick.
    /// @custom:signature test_BUD_Crossing12Allowed13RejectedWithoutFetchingTick()
    /// @custom:selector 0x814942a6
    function test_BUD_Crossing12Allowed13RejectedWithoutFetchingTick() public {
        _poolWithTicks(0, 13, 0);
        Types.ProjectedState memory state_ = Projection.fresh(_snapshot());
        (, Types.Failure memory failure_) =
            Projection.swap(state_, false, 1e20, TickMath.getSqrtPriceAtTick(12), Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.tickCrossings, 12);
        assertEq(state_.tickCount, 14);
        (, failure_) = Projection.swap(
            state_, false, 1e20, TickMath.getSqrtPriceAtTick(13), Types.Phase.ExitSale
        );
        _failure(failure_, abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12));
        assertEq(state_.tickCrossings, 12);
        assertEq(state_.tickCount, 14, "rejected crossing is not fetched");
    }
    // end::test_BUD_Crossing12Allowed13RejectedWithoutFetchingTick[]

    // tag::test_BUD_RepeatCrossingsShareTheWholeCandidateBudget[]
    /// @notice Count reverse crossings of cached ticks against the same candidate budget.
    /// @custom:signature test_BUD_RepeatCrossingsShareTheWholeCandidateBudget()
    /// @custom:selector 0x2c381933
    function test_BUD_RepeatCrossingsShareTheWholeCandidateBudget() public {
        _poolWithTicks(0, 13, 0);
        Types.ProjectedState memory state_ = Projection.fresh(_snapshot());
        (, Types.Failure memory failure_) =
            Projection.swap(state_, false, 1e20, TickMath.getSqrtPriceAtTick(6), Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.tickCrossings, 6);
        (, failure_) = Projection.swap(
            state_, true, 1e20, TickMath.getSqrtPriceAtTick(1), Types.Phase.EntrySwap
        );
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.tickCrossings, 12, "the same six ticks count twice");
        assertEq(state_.tickCount, 8, "unique tick count is not the crossing budget");
        (, failure_) = Projection.swap(
            state_, false, 1e20, TickMath.getSqrtPriceAtTick(2), Types.Phase.ExitSale
        );
        _failure(failure_, abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12));
    }
    // end::test_BUD_RepeatCrossingsShareTheWholeCandidateBudget[]

    // tag::test_BUD_DistinctWord16Allowed17RejectedAndRepeatReadFree[]
    /// @notice Admit sixteen distinct words while repeated reads consume no new key.
    /// @custom:signature test_BUD_DistinctWord16Allowed17RejectedAndRepeatReadFree()
    /// @custom:selector 0x8eb4d377
    function test_BUD_DistinctWord16Allowed17RejectedAndRepeatReadFree() public {
        _poolWithTicks(0, 0, 0);
        Types.ProjectedState memory state_ = Projection.fresh(_snapshot());
        (, Types.Failure memory failure_) =
            Projection.swap(state_, false, 1e20, TickMath.getSqrtPriceAtTick(3583), Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.wordCount, 16, "fourteen scanned words plus two owned boundaries");
        assertEq(state_.tickCrossings, 0);
        (, failure_) = Projection.swap(
            state_, true, 1e12, TickMath.getSqrtPriceAtTick(3500), Types.Phase.EntrySwap
        );
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.wordCount, 16, "cached word reads do not consume another key");
        (, failure_) = Projection.swap(
            state_, false, 1e20, TickMath.getSqrtPriceAtTick(3584), Types.Phase.ExitSale
        );
        _failure(failure_, abi.encodeWithSelector(IVault.QuoteBitmapWordsExceeded.selector, 17, 16));
        assertEq(state_.wordCount, 16, "rejected key is not fetched");
    }
    // end::test_BUD_DistinctWord16Allowed17RejectedAndRepeatReadFree[]

    /// @dev This sets only a memory work counter, not SUT storage or economic state.
    /// Whole product candidates can encounter crossing/word limits before step 65.
    // tag::test_BUD_Iteration64Allowed65RejectedComponentGuard[]
    /// @notice Verify the independent iteration guard using memory-only work-counter state.
    /// @custom:signature test_BUD_Iteration64Allowed65RejectedComponentGuard()
    /// @custom:selector 0x25e8bcb9
    function test_BUD_Iteration64Allowed65RejectedComponentGuard() public {
        _poolWithTicks(0, 0, 0);
        Types.ProjectedState memory state_ = Projection.fresh(_snapshot());
        state_.swapSteps = 63;
        (, Types.Failure memory failure_) =
            Projection.swap(state_, false, 1e12, TickMath.getSqrtPriceAtTick(1), Types.Phase.MaintenanceSwap);
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.None));
        assertEq(state_.swapSteps, 64);
        (, failure_) = Projection.swap(
            state_, false, 1e12, TickMath.getSqrtPriceAtTick(1), Types.Phase.ExitSale
        );
        _failure(failure_, abi.encodeWithSelector(IVault.QuoteWorkExceeded.selector, 65, 64));
        assertEq(state_.swapSteps, 64);
    }
    // end::test_BUD_Iteration64Allowed65RejectedComponentGuard[]

    // tag::test_BUD_DenseSingleExitRejectedBeforeBurnAndPairRemainsAffordable[]
    /// @notice Reject oversized single exits atomically and preserve disabled paired escape.
    /// @custom:signature test_BUD_DenseSingleExitRejectedBeforeBurnAndPairRemainsAffordable()
    /// @custom:selector 0xb2e0a694
    function test_BUD_DenseSingleExitRejectedBeforeBurnAndPairRemainsAffordable() public {
        _poolWithTicks(13, 13, 0);
        _donateBook(1e20);
        uint256 shares_ = IERC20(address(vault)).totalSupply() * 3 / 100;
        bytes32 before_ = _stateHash();
        bytes memory expected_ = abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12);
        _cold();
        uint256 start_ = gasleft();
        vm.expectRevert(expected_);
        IStandardizedYield(address(vault)).previewRedeem(address(token0), shares_);
        assertLe(start_ - gasleft(), 5_000_000, "rejected preview ceiling");
        vm.expectRevert(expected_);
        vault.previewWithdrawalMode(shares_, false, address(token0));
        vm.expectRevert(expected_);IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(vault)), shares_, IERC20(address(token0))
        );
        _cold();
        start_ = gasleft();
        vm.expectRevert(expected_);
        IStandardizedYield(address(vault)).redeem(address(this), shares_, address(token0), 0, false);
        assertLe(start_ - gasleft(), 11_900_000, "rejected execution ceiling");
        vm.expectRevert(expected_);IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(vault)), shares_, IERC20(address(token0)), 0,
            address(this), false, block.timestamp
        );
        assertEq(_stateHash(), before_, "no burn, transfer, book or manager mutation");
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        _pairedExit(shares_, IVault.WithdrawalMode.CollectOnly);
    }
    // end::test_BUD_DenseSingleExitRejectedBeforeBurnAndPairRemainsAffordable[]

    // tag::test_BUD_BitmapExhaustionPreservesPairedEscapeAndRejectsZap[]
    /// @notice Reject oversized zap scans and retain the affordable paired route.
    /// @custom:signature test_BUD_BitmapExhaustionPreservesPairedEscapeAndRejectsZap()
    /// @custom:selector 0xd1c96f53
    function test_BUD_BitmapExhaustionPreservesPairedEscapeAndRejectsZap() public {
        _poolWithTicks(0, 0, 0);
        _fund(address(this), 0, 9e17);
        bytes32 before_ = _stateHash();
        bytes memory expected_ = abi.encodeWithSelector(IVault.QuoteBitmapWordsExceeded.selector, 17, 16);
        vm.expectRevert(expected_);
        IStandardizedYield(address(vault)).previewDeposit(address(token1), 9e17);
        vm.expectRevert(expected_);
        IStandardizedYield(address(vault)).deposit(address(this), address(token1), 9e17, 0);
        assertEq(_stateHash(), before_);
        _donateBook(1e20);
        _pairedExit(IERC20(address(vault)).totalSupply() / 2, IVault.WithdrawalMode.CollectOnly);
    }
    // end::test_BUD_BitmapExhaustionPreservesPairedEscapeAndRejectsZap[]

    // tag::test_BUD_MaximumCrossingFallbackWithBothFeeCurrencies[]
    /// @notice Execute full-budget fallback with both LP fee currencies and protocol fees.
    /// @custom:signature test_BUD_MaximumCrossingFallbackWithBothFeeCurrencies()
    /// @custom:selector 0x1ed332fa
    function test_BUD_MaximumCrossingFallbackWithBothFeeCurrencies() public {
        _poolWithTicks(13, 12, 3000);
        _fund(address(poolActor), 1e15, 1e15);
        poolActor.donate(key, 1e15, 1e15);
        _donateBook(1e20);
        _singleExit(IERC20(address(vault)).totalSupply() * 3 / 100, 12);
    }
    // end::test_BUD_MaximumCrossingFallbackWithBothFeeCurrencies[]

    // tag::test_BUD_MaintenanceFitsButFinalSaleExhaustsSharedBudget[]
    /// @notice Select fresh fallback when the final sale exhausts prior maintenance work.
    /// @custom:signature test_BUD_MaintenanceFitsButFinalSaleExhaustsSharedBudget()
    /// @custom:selector 0x49dcc879
    function test_BUD_MaintenanceFitsButFinalSaleExhaustsSharedBudget() public {
        _poolWithTicks(6, 12, 3000);
        _donateBook(1e17);
        uint256 shares_ = IERC20(address(vault)).totalSupply() / 10;
        (IVault.WithdrawalMode mode_,) = vault.previewWithdrawalMode(shares_, true, address(0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound), "maintenance/removal alone fits");
        _singleExit(shares_, 12);
    }
    // end::test_BUD_MaintenanceFitsButFinalSaleExhaustsSharedBudget[]

    // tag::test_BUD_MaximumSupportedEntryAcrossMaintenanceAndZap[]
    /// @notice Bound the six-action token0 entry at the crossing and word maxima.
    /// @custom:signature test_BUD_MaximumSupportedEntryAcrossMaintenanceAndZap()
    /// @custom:selector 0xbdfc7ab9
    function test_BUD_MaximumSupportedEntryAcrossMaintenanceAndZap() public {
        _maximumEntry(false, false, true);
    }
    // end::test_BUD_MaximumSupportedEntryAcrossMaintenanceAndZap[]

    // tag::test_BUD_MaximumSupportedToken1Entry[]
    /// @notice Bound the mirrored six-action token1 entry.
    /// @custom:signature test_BUD_MaximumSupportedToken1Entry()
    /// @custom:selector 0xa7305fee
    function test_BUD_MaximumSupportedToken1Entry() public {
        _maximumEntry(false, false, false);
    }
    // end::test_BUD_MaximumSupportedToken1Entry[]

    // tag::test_BUD_MaximumSupportedNativeEntry[]
    /// @notice Bound native delivery for the maximum-complexity entry.
    /// @custom:signature test_BUD_MaximumSupportedNativeEntry()
    /// @custom:selector 0xd4a3cc1f
    function test_BUD_MaximumSupportedNativeEntry() public {
        _maximumEntry(true, false, true);
    }
    // end::test_BUD_MaximumSupportedNativeEntry[]

    // tag::test_BUD_MaximumSupportedWrappedEntry[]
    /// @notice Bound wrapped-native delivery for the maximum-complexity entry.
    /// @custom:signature test_BUD_MaximumSupportedWrappedEntry()
    /// @custom:selector 0x0cdfe6ca
    function test_BUD_MaximumSupportedWrappedEntry() public {
        _maximumEntry(true, true, true);
    }
    // end::test_BUD_MaximumSupportedWrappedEntry[]

    // tag::test_BUD_MaximumSupportedNativePoolToken1Entry[]
    /// @notice Bound opposite-leg entry into the native pool at the work maxima.
    /// @custom:signature test_BUD_MaximumSupportedNativePoolToken1Entry()
    /// @custom:selector 0x81e65409
    function test_BUD_MaximumSupportedNativePoolToken1Entry() public {
        _maximumEntry(true, false, false);
    }
    // end::test_BUD_MaximumSupportedNativePoolToken1Entry[]

    // tag::test_BUD_MaximumFullCompoundPairedAndTerminalExits[]
    /// @notice Bound partial and terminal paired exits with maximum normal maintenance.
    /// @custom:signature test_BUD_MaximumFullCompoundPairedAndTerminalExits()
    /// @custom:selector 0x5a784ad8
    function test_BUD_MaximumFullCompoundPairedAndTerminalExits() public {
        _maximumPair(false);
    }
    // end::test_BUD_MaximumFullCompoundPairedAndTerminalExits[]

    // tag::test_BUD_MaximumNativeFullCompoundPairedAndTerminalExits[]
    /// @notice Bound native paired and terminal exits with maximum normal maintenance.
    /// @custom:signature test_BUD_MaximumNativeFullCompoundPairedAndTerminalExits()
    /// @custom:selector 0x8c8cc7d1
    function test_BUD_MaximumNativeFullCompoundPairedAndTerminalExits() public {
        _maximumPair(true);
    }
    // end::test_BUD_MaximumNativeFullCompoundPairedAndTerminalExits[]

    function _maximumPair(bool native_) private {
        if (native_) _deployPool(true, 18, 18);
        _poolWithTicks(12, 0, 3000);
        _fund(address(poolActor), 1e15, 1e15);
        poolActor.donate(key, 1e15, 1e15);
        _donateBook(36e16);
        Types.Operation memory operation_;
        operation_.kind = Types.OperationKind.RedeemPair;
        operation_.shares = IERC20(address(vault)).totalSupply() / 2;
        Types.Plan memory plan_ = Planner.plan(_snapshot(), operation_);
        assertEq(plan_.tickCrossings, 12);
        assertEq(plan_.ticks.length, 14);
        assertEq(plan_.words.length, 16);
        assertEq(uint256(plan_.mode), uint256(IVault.WithdrawalMode.FullCompound));
        uint256 saved_ = vm.snapshotState();
        _pairedExit(operation_.shares, IVault.WithdrawalMode.FullCompound);
        assertTrue(vm.revertToState(saved_));
        _pairedExit(IERC20(address(vault)).totalSupply(), IVault.WithdrawalMode.FullCompound);
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        (uint256 b0_, uint256 b1_) = vault.localReserves();
        assertEq(b0_, 0);
        assertEq(b1_, 0);
    }

    function _maximumEntry(bool native_, bool wrapped_, bool zeroForOne_) private {
        if (native_) _deployPool(true, 18, 18);
        _poolWithTicks(zeroForOne_ ? 6 : 0, zeroForOne_ ? 0 : 6, 3000);
        for (int24 i_ = 1; i_ <= 6; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(
                zeroForOne_ ? -1000 - i_ : int24(-1),
                zeroForOne_ ? int24(1) : 1000 + i_, 1, bytes32(uint256(uint24(i_)) + 2000)
            ));
        }
        _fund(address(poolActor), 1e15, 1e15);
        poolActor.donate(key, 1e15, 1e15);
        _fund(address(this), zeroForOne_ ? 1e17 : 0, zeroForOne_ ? 0 : 1e17);
        address currency_ = zeroForOne_ ? address(token0) : address(token1);
        vault.donate{value: native_ && zeroForOne_ ? 1e17 : 0}(currency_, 1e17);
        uint256 amount_;
        {
            uint256 saved_ = vm.snapshotState();
            vault.compound();
            (uint160 price_,,,) = StateLibrary.getSlot0(pool, key.toId());
            uint128 liquidity_ = StateLibrary.getLiquidity(pool, key.toId());
            amount_ = 2 * ((zeroForOne_
                ? SqrtPriceMath.getAmount0Delta(TickMath.getSqrtPriceAtTick(-3300), price_, liquidity_, true)
                : SqrtPriceMath.getAmount1Delta(price_, TickMath.getSqrtPriceAtTick(3580), liquidity_, true)
            ) + 100);
            assertTrue(vm.revertToState(saved_));
        }
        _fund(address(this), zeroForOne_ ? amount_ : 0, zeroForOne_ ? 0 : amount_);
        address input_ = wrapped_ ? address(wrappedNative) : currency_;
        if (wrapped_) {
            wrappedNative.deposit{value: amount_}();
            wrappedNative.approve(address(vault), amount_);
        }
        {
            Types.Operation memory operation_;
            operation_.kind = Types.OperationKind.DepositZap;
            if (zeroForOne_) operation_.amounts.amount0 = amount_;
            else operation_.amounts.amount1 = amount_;
            operation_.token = input_;
            Types.Plan memory plan_ = Planner.plan(_snapshot(), operation_);
            assertEq(plan_.tickCrossings, 12);
            assertEq(plan_.ticks.length, 14);
            assertEq(plan_.words.length, 16);
            assertEq(plan_.actions.length, 6);
        }
        _cold();
        uint256 start_ = gasleft();
        uint256 quote_ = IStandardizedYield(address(vault)).previewDeposit(input_, amount_);
        uint256 used_ = start_ - gasleft();
        emit log_named_uint("gas.budget.maximumEntry.preview", used_);
        assertLe(used_, 5_000_000);
        _cold();
        start_ = gasleft();
        assertEq(IStandardizedYield(address(vault)).deposit{value: native_ && zeroForOne_ && !wrapped_ ? amount_ : 0}(
            address(this), input_, amount_, quote_
        ), quote_);
        used_ = start_ - gasleft();
        emit log_named_uint("gas.budget.maximumEntry.execute", used_);
        assertLe(used_, 11_900_000);
    }

    function _poolWithTicks(uint24 negative_, uint24 positive_, uint24 fee_) private {
        key.tickSpacing = 1;
        key.fee = fee_;
        pool.initialize(key, uint160(1) << 96);
        if (fee_ != 0) {
            pool.setProtocolFeeController(address(this));
            pool.setProtocolFee(key, uint24(1000) | (uint24(1000) << 12));
        }
        IPackage.PkgArgs memory args_ = _defaultArgs(
            key, address(token0) == address(0) ? address(wrappedNative) : address(token0), "Bounded work"
        );
        args_.maxZapBps = 10000;
        args_.maxZapTickMove = 20000;
        vault = _deployVault(args_);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e18, 1e18);
        for (uint24 i_ = 1; i_ <= negative_; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(-int24(i_), 1, 1, bytes32(uint256(i_))));
        }
        for (uint24 i_ = 1; i_ <= positive_; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(-1, int24(i_), 1, bytes32(uint256(i_) + 1000)));
        }
    }

    function _donateBook(uint256 amount_) private {
        _fund(address(this), amount_, 0);
        vault.donate{value: address(token0) == address(0) ? amount_ : 0}(address(token0), amount_);
    }

    function _snapshot() private view returns (Types.Snapshot memory) {
        Types.Inventory memory inventory_;
        (inventory_.booked.amount0, inventory_.booked.amount1) = vault.localReserves();
        Types.Config memory config_ = Types.Config(
            pool, key, address(indexedexManager), address(wrappedNative), vault.rateAsset(),
            vault.tickLower(), vault.tickUpper(), vault.maxZapBps(), vault.maxZapTickMove(), 18
        );
        return Projection.loadSnapshot(config_, inventory_, IERC20(address(vault)).totalSupply(), address(vault));
    }

    function _singleExit(uint256 shares_, uint256 crossings_) private {
        Types.Operation memory operation_;
        operation_.kind = Types.OperationKind.RedeemSingle;
        operation_.shares = shares_;
        operation_.token = address(token0);
        Types.Plan memory plan_ = Planner.plan(_snapshot(), operation_);
        assertEq(uint256(plan_.mode), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(plan_.reason), uint256(IVault.MaintenanceReason.MaintenanceWorkLimit));
        assertEq(plan_.tickCrossings, crossings_);
        assertLe(plan_.swapSteps, 64);
        assertLe(plan_.words.length, 16);
        _cold();
        uint256 start_ = gasleft();
        uint256 quote_ = IStandardizedYield(address(vault)).previewRedeem(address(token0), shares_);
        uint256 used_ = start_ - gasleft();
        emit log_named_uint("gas.budget.single.preview", used_);
        assertLe(used_, 5_000_000);
        uint256 before_ = token0.balanceOf(address(this));
        _cold();
        start_ = gasleft();
        assertEq(IStandardizedYield(address(vault)).redeem(address(this), shares_, address(token0), quote_, false), quote_);
        used_ = start_ - gasleft();
        emit log_named_uint("gas.budget.single.execute", used_);
        assertLe(used_, 11_900_000);
        assertEq(token0.balanceOf(address(this)), before_ + quote_);
    }

    function _pairedExit(uint256 shares_, IVault.WithdrawalMode expectedMode_) private {
        _cold();
        uint256 start_ = gasleft();
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(shares_, true, address(0));
        assertLe(start_ - gasleft(), 5_000_000);
        assertEq(uint256(mode_), uint256(expectedMode_));
        assertEq(uint256(reason_), uint256(expectedMode_ == IVault.WithdrawalMode.CollectOnly
            ? IVault.MaintenanceReason.MaintenanceWorkLimit : IVault.MaintenanceReason.None));
        _cold();
        start_ = gasleft();
        (uint256 a0_, uint256 a1_) = vault.previewRedeemPair(shares_);
        assertLe(start_ - gasleft(), 5_000_000);
        uint256 before0_ = address(token0) == address(0) ? address(this).balance : token0.balanceOf(address(this));
        uint256 before1_ = token1.balanceOf(address(this));
        _cold();
        start_ = gasleft();
        (uint256 actual0_, uint256 actual1_) = vault.redeemPair(shares_, a0_, a1_, address(this), block.timestamp);
        uint256 used_ = start_ - gasleft();
        emit log_named_uint("gas.budget.pair.execute", used_);
        assertLe(used_, 11_900_000);
        assertEq(actual0_, a0_);
        assertEq(actual1_, a1_);
        assertEq(address(token0) == address(0) ? address(this).balance : token0.balanceOf(address(this)), before0_ + a0_);
        assertEq(token1.balanceOf(address(this)), before1_ + a1_);
    }

    function _stateHash() private view returns (bytes32) {
        return keccak256(abi.encode(
            _snapshot(), token0.balanceOf(address(this)), token1.balanceOf(address(this)),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool)),
            token0.allowance(address(this), address(vault)), token1.allowance(address(this), address(vault)),
            IERC20(address(vault)).balanceOf(address(this))
        ));
    }

    function _cold() private {
        address[] memory facets_ = pairTokenPackage.facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) vm.cool(facets_[i_]);
        for (uint256 i_; i_ < 6; ++i_) vm.cool(pkgInit.linkedLibraries[i_]);
        vm.cool(address(vault));
        vm.cool(address(pool));
        vm.cool(address(indexedexManager));
        if (address(token0) != address(0)) vm.cool(address(token0));
        vm.cool(address(token1));
        vm.cool(address(wrappedNative));
    }

    function _failure(Types.Failure memory failure_, bytes memory expected_) private pure {
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.WorkLimit));
        assertEq(failure_.revertData, expected_);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultWorkBudgetTest[]
