// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultExitTest[]
/// @notice Real-proxy exit allocation, fee ownership, terminal lifecycle and fallback acceptance.
contract UniswapV4PairTokenStandardExchangeVaultExitTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct Allocation {
        uint256 supply;
        uint128 liquidity;
        uint128 removed;
        uint256 book0;
        uint256 book1;
        uint256 idle0;
        uint256 idle1;
        uint256 payout0;
        uint256 payout1;
    }

    struct SaleExpectation {
        Allocation allocation;
        uint256 unwanted;
        uint256 proceeds;
        uint256 payout;
        uint256 fees0;
        uint256 fees1;
        bytes32 economicState;
    }

    /// @notice S1-A16/A17: all submitted shares, exact independent floors and dust ownership.
    function test_PairToken_EXT_ProportionalPairFloorsWithoutRetention() public {
        uint256 supply_ = _bootstrap(1e18 + 37, 1e18 + 37, address(this));
        _donate(997, 991);
        uint256 shares_ = supply_ / 3 + 7;
        Allocation memory expected_ = _afterMaintenance(shares_);
        assertEq(expected_.removed, uint256(expected_.liquidity) * shares_ / supply_);
        assertEq(expected_.idle0, expected_.book0 * shares_ / supply_);
        assertEq(expected_.idle1, expected_.book1 * shares_ / supply_);
        assertGt(mulmod(expected_.book0, shares_, supply_), 0, "exercise idle rounding");
        bytes32 before_ = _rollbackState();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector,
            expected_.payout0 + 1, expected_.payout0));
        vault.redeemPair(shares_, expected_.payout0 + 1, expected_.payout1, address(this), block.timestamp);
        assertEq(_rollbackState(), before_);
        _assertPair(shares_, expected_, IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
    }

    /// @notice S1-A17/A24: whole-position fees enter the common snapshot, not partial principal.
    function test_PairToken_EXT_WholePositionFeesAreProportionallyOwned() public {
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 900, 800);
        poolActor.donate(key, 900, 800);
        (uint256 fee0_, uint256 fee1_) = _claimable();
        assertGt(fee0_, 0);
        assertGt(fee1_, 0);
        uint256 shares_ = supply_ / 4;
        Allocation memory expected_ = _afterMaintenance(shares_);
        assertEq(expected_.book0, fee0_);
        assertEq(expected_.book1, fee1_);
        assertLt(expected_.idle0, fee0_, "not a whole-position fee windfall");
        assertLt(expected_.idle1, fee1_);
        _assertPair(shares_, expected_, IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        (fee0_, fee1_) = _claimable();
        assertEq(fee0_, 0, "no second fee receipt on removal");
        assertEq(fee1_, 0);
    }

    /// @notice S1-A18/A24/A27: both sale directions match independent real-manager execution.
    function test_PairToken_EXT_BothSingleOutputsAndRemainingHolderFees() public {
        uint256 supply_ = _bootstrap(1e20, 1e20, address(this));
        _donate(53, 47);
        _fund(address(poolActor), 1e24, 1e24);
        uint256 initial_ = vm.snapshotState();
        _assertSingle(supply_ / 3, true);
        assertTrue(vm.revertToState(initial_));
        _assertSingle(supply_ / 3, false);
    }

    /// @notice S1-A18/A43/A63: an unmet minimum never changes maintenance mode or leaks a burn.
    function test_PairToken_EXT_MinimumFailureRollsBackCompleteSale() public {
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        _donate(1e12, 0);
        uint256 shares_ = supply_ / 5;
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(shares_, false, address(token0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.None));(uint256 quote_,) = _exchange().previewExchangeIn(_share(), shares_, IERC20(address(token0)));
        bytes32 before_ = _rollbackState();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, quote_ + 1, quote_));_exchange().exchangeIn(_share(), shares_, IERC20(address(token0)), quote_ + 1, address(this), false, block.timestamp);
        assertEq(_rollbackState(), before_);
        (mode_, reason_) = vault.previewWithdrawalMode(shares_, false, address(token0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.None));
    }

    /// @notice S1-A19/A21/A63: a narrow external position permits only a partial terminal sale.
    function test_PairToken_EXT_PartialFinalSaleRollsBackAndPairStillWorks() public {
        _freshPool(32767, 3000, uint160(1) << 96, 1000);
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        _externalPosition(-32767, 32767, 1e12, bytes32(0));
        uint256 snapshot_ = vm.snapshotState();
        (uint256 amount0_, uint256 amount1_) = vault.redeemPair(supply_, 0, 0, address(this), block.timestamp);
        BalanceDelta sale_ = poolActor.swap(key, SwapParams(false, -int256(amount1_), TickMath.MAX_SQRT_PRICE - 1));
        uint256 consumed_ = uint256(-int256(sale_.amount1()));
        assertGt(consumed_, 0, "a partial fill, not a zero fill");
        assertLt(consumed_, amount1_);
        assertGt(amount0_, 0);
        assertTrue(vm.revertToState(snapshot_));
        bytes memory error_ = abi.encodeWithSelector(Planner.IncompleteExitSale.selector, amount1_, consumed_);
        bytes32 before_ = _rollbackState();
        vm.expectRevert(error_);
        vault.previewWithdrawalMode(supply_, false, address(token0));
        vm.expectRevert(error_);_exchange().previewExchangeIn(_share(), supply_, IERC20(address(token0)));
        vm.recordLogs();
        vm.expectRevert(error_);_exchange().exchangeIn(_share(), supply_, IERC20(address(token0)), 0, address(this), false, block.timestamp);
        assertEq(vm.getRecordedLogs().length, 0, "preflight failure emits no operation events");
        assertEq(_rollbackState(), before_);
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(supply_, true, address(0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.None));
        _assertPair(supply_, _afterMaintenance(supply_), mode_, reason_);
    }

    /// @notice S1-A20/A65: terminal payout drains owned receipts, excludes unsolicited inventory and restarts.
    function test_PairToken_EXT_LastHolderRestartExcludesUnsolicited() public {
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e12, 2e12);
        poolActor.donate(key, 1e12, 2e12);
        _fund(address(this), 123, 456);
        token0.transfer(address(vault), 123);
        token1.transfer(address(vault), 456);
        _assertPair(supply_, _afterMaintenance(supply_), IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        _assertBook(0, 0);
        assertEq(token0.balanceOf(address(vault)), 123);
        assertEq(token1.balanceOf(address(vault)), 456);
        uint256 next_ = _bootstrap(1e9, 1e9, address(this));
        assertEq(next_, 1e9, "fresh geometric mean, no dead-share subtraction");
        Allocation memory expected_ = _afterMaintenance(next_);
        _assertPair(next_, expected_, IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        assertEq(token0.balanceOf(address(vault)), 123);
        assertEq(token1.balanceOf(address(vault)), 456);
    }

    /// @notice S1-A21: no sale liquidity remains when the sole position is removed.
    function test_PairToken_EXT_TerminalSingleNeedsExternalLiquidity() public {
        _freshPool(32767, 3000, uint160(1) << 96, 1000);
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        (uint256 amount0_, uint256 amount1_) = vault.previewRedeemPair(supply_);
        bytes32 before_ = _rollbackState();
        vm.expectRevert(abi.encodeWithSelector(Planner.IncompleteExitSale.selector, amount1_, 0));_exchange().exchangeIn(_share(), supply_, IERC20(address(token0)), 0, address(this), false, block.timestamp);
        assertEq(_rollbackState(), before_);
        vm.expectRevert(abi.encodeWithSelector(Planner.IncompleteExitSale.selector, amount0_, 0));_exchange().exchangeIn(_share(), supply_, IERC20(address(token1)), 0, address(this), false, block.timestamp);
        assertEq(_rollbackState(), before_);
        _externalPosition(vault.tickLower(), vault.tickUpper(), 1e21, bytes32(0));
        uint256 snapshot_ = vm.snapshotState();
        _assertSingle(supply_, true);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        _assertBook(0, 0);
        assertTrue(vm.revertToState(snapshot_));
        _assertSingle(supply_, false);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        _assertBook(0, 0);
    }

    /// @notice S1-A19/A61: capacity is reached by a real other-owner full-range position.
    function test_PairToken_EXT_LiquidityCapacityCollectOnlyFallback() public {
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        // Canonical per-tick capacity is uint128.max / number of usable ticks.
        int24 minCompressed_ = TickMath.MIN_TICK / key.tickSpacing;
        if (TickMath.MIN_TICK % key.tickSpacing != 0) --minCompressed_;
        uint256 count_ = uint256(int256(TickMath.MAX_TICK / key.tickSpacing - minCompressed_)) + 1;
        uint128 cap_ = uint128(type(uint128).max / count_);
        _externalPosition(vault.tickLower(), vault.tickUpper(), cap_ - vault.positionLiquidity(), bytes32(0));
        _donate(1e12, 1e12);
        _assertFallback(supply_ / 2, IVault.MaintenanceReason.MaintenanceLiquidityLimit);
    }

    /// @notice S1-A19/A61: no legal zero-for-one interval exists at MIN_SQRT_PRICE+1.
    function test_PairToken_EXT_PriceBoundaryCollectOnlyFallback() public {
        _freshPool(1, 3000, TickMath.MIN_SQRT_PRICE + 1, 10000);
        uint256 supply_ = _bootstrap(1e30, 1, address(this));
        assertGt(pool.getLiquidity(key.toId()), 0, "not the zero-active no-swap branch");
        _donate(1e25, 0);
        _assertFallback(supply_, IVault.MaintenanceReason.MaintenancePriceLimit);
    }

    /// @notice S1-A19/A61: many individually legal positions create an unrepresentable maintenance delta.
    function test_PairToken_EXT_DeltaCapacityCollectOnlyFallback() public {
        _freshPool(60, 500, TickMath.getSqrtPriceAtTick(-860000), 10000);
        uint256 supply_ = _bootstrap(1e28, 1, address(this));
        // Every add's token0 principal fits int128; the aggregate reserve and its
        // quarter-sized maintenance swap do not. No fabricated pool/vault state.
        for (uint256 i_; i_ < 32; ++i_) {
            _externalPosition(vault.tickLower(), vault.tickUpper(), 1e19, bytes32(i_ + 1));
        }
        _donate(1e40, 0);
        _assertFallback(supply_, IVault.MaintenanceReason.MaintenanceDeltaLimit);
    }

    /// @notice S1-A19/A61: a dense real pool exhausts the normal crossing budget.
    function test_PairToken_EXT_WorkBudgetCollectOnlyFallback() public {
        _freshPool(1, 3000, uint160(1) << 96, 10000);
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        for (int24 i_ = 1; i_ <= 513; ++i_) {
            _externalPosition(-i_, 1, 1, bytes32(uint256(uint24(i_))));
        }
        _donate(1e20, 0);
        _assertFallback(supply_ / 2, IVault.MaintenanceReason.MaintenanceWorkLimit);
    }

    /// @notice S1-A63: the paired sentinel and raw-native single output are distinct valid queries.
    function test_PairToken_EXT_PairedSentinelAndNativeSingleModeAreUnambiguous() public {
        _nativeVault();
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        (IVault.WithdrawalMode paired_, IVault.MaintenanceReason pairedReason_) =
            vault.previewWithdrawalMode(supply_ / 10, true, address(0));
        (IVault.WithdrawalMode native_, IVault.MaintenanceReason nativeReason_) =
            vault.previewWithdrawalMode(supply_ / 10, false, address(0));
        assertEq(uint256(paired_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(native_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(pairedReason_), uint256(IVault.MaintenanceReason.None));
        assertEq(uint256(nativeReason_), uint256(IVault.MaintenanceReason.None));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(vault), address(token1)));
        vault.previewWithdrawalMode(supply_ / 10, true, address(token1));
    }

    /// @notice S1-A19/A62: a real payout exception rolls back instead of retrying collect-only.
    function test_PairToken_EXT_UnexpectedNativePayoutFailureDoesNotFallback() public {
        _nativeVault();
        uint256 supply_ = _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e12, 1e12);
        poolActor.donate(key, 1e12, 1e12);
        PairTokenExitRejectingNativeReceiver receiver_ = new PairTokenExitRejectingNativeReceiver();
        bytes32 before_ = _nativeRollbackState();
        vm.expectRevert();
        vault.redeemPair(supply_ / 2, 0, 0, address(receiver_), block.timestamp);
        assertEq(_nativeRollbackState(), before_, "fees, compound, removal and burn all roll back");
        assertEq(address(receiver_).balance, 0);
        assertEq(token1.balanceOf(address(receiver_)), 0);
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(supply_ / 2, true, address(0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.None));
    }

    /// @notice S1-A66: tiny burns cannot destroy shares for zero assets, but one-sided output is valid.
    function test_PairToken_EXT_TinyZeroPayoutAndOneSidedPositiveOutput() public {
        uint256 supply_ = _bootstrap(2, 2, address(this));
        assertEq(supply_, 2);
        bytes32 before_ = _rollbackState();
        vm.expectRevert(IVault.ZeroPayout.selector);
        vault.previewRedeemPair(1);
        vm.expectRevert(IVault.ZeroPayout.selector);
        vault.redeemPair(1, 0, 0, address(this), block.timestamp);
        assertEq(_rollbackState(), before_);
        for (uint256 i_; i_ < 2; ++i_) {
            IERC20 output_ = IERC20(i_ == 0 ? address(token0) : address(token1));
            vm.expectRevert(IVault.ZeroPayout.selector);_exchange().previewExchangeIn(_share(), 1, output_);
            vm.expectRevert(IVault.ZeroPayout.selector);_exchange().exchangeIn(_share(), 1, output_, 0, address(this), false, block.timestamp);
            assertEq(_rollbackState(), before_);
        }
        _donate(2, 0);
        Allocation memory expected_ = _afterMaintenance(1);
        assertGt(expected_.payout0, 0);
        assertEq(expected_.payout1, 0);
        _assertPair(1, expected_, IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        _assertPair(1, _afterMaintenance(1), IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        _assertBook(0, 0);
    }

    /// @dev Public compound reproduces the mandatory maintenance, without asking the planner for allocations.
    function _afterMaintenance(uint256 shares_) private returns (Allocation memory expected_) {
        uint256 snapshot_ = vm.snapshotState();
        vault.compound();
        expected_ = _allocation(shares_, 0, 0);
        assertTrue(vm.revertToState(snapshot_));
    }

    function _allocation(uint256 shares_, uint256 fees0_, uint256 fees1_) private view returns (Allocation memory a_) {
        a_.supply = _share().totalSupply();
        a_.liquidity = vault.positionLiquidity();
        (a_.book0, a_.book1) = vault.localReserves();
        a_.book0 += fees0_;
        a_.book1 += fees1_;
        // All test vectors keep these products below uint256; do not call SUT allocation math.
        a_.removed = uint128(uint256(a_.liquidity) * shares_ / a_.supply);
        a_.idle0 = a_.book0 * shares_ / a_.supply;
        a_.idle1 = a_.book1 * shares_ / a_.supply;
        (uint160 price_,,,) = pool.getSlot0(key.toId());
        uint160 lower_ = TickMath.getSqrtPriceAtTick(vault.tickLower());
        uint160 upper_ = TickMath.getSqrtPriceAtTick(vault.tickUpper());
        if (price_ < lower_) price_ = lower_;
        if (price_ > upper_) price_ = upper_;
        a_.payout0 = a_.idle0 + SqrtPriceMath.getAmount0Delta(price_, upper_, a_.removed, false);
        a_.payout1 = a_.idle1 + SqrtPriceMath.getAmount1Delta(lower_, price_, a_.removed, false);
    }

    function _assertPair(
        uint256 shares_, Allocation memory a_, IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_
    ) private {
        {
            uint256 snapshot_ = vm.snapshotState();
            (uint256 quote0_, uint256 quote1_) = vault.previewRedeemPair(shares_);
            assertEq(quote0_, a_.payout0);
            assertEq(quote1_, a_.payout1);
            assertTrue(vm.revertToState(snapshot_));
        }
        uint256[3] memory before_ = [
            token0.balanceOf(address(this)), token1.balanceOf(address(this)), _share().balanceOf(address(this))
        ];
        vm.recordLogs();
        (uint256 actual0_, uint256 actual1_) =
            vault.redeemPair(shares_, a_.payout0, a_.payout1, address(this), block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertEq(actual0_, a_.payout0);
        assertEq(actual1_, a_.payout1);
        assertEq(token0.balanceOf(address(this)), before_[0] + actual0_);
        assertEq(token1.balanceOf(address(this)), before_[1] + actual1_);
        assertEq(_share().totalSupply(), a_.supply - shares_);
        assertEq(_share().balanceOf(address(this)), before_[2] - shares_);
        assertEq(_share().balanceOf(address(0xdead)), 0);
        assertEq(vault.positionLiquidity(), a_.liquidity - a_.removed);
        _assertBook(a_.book0 - a_.idle0, a_.book1 - a_.idle1);
        _assertMode(logs_, mode_, reason_);
        uint256 events_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == address(vault) && logs_[i_].topics[0] == IVault.PairRedeemed.selector) {
                ++events_;
                assertEq(logs_[i_].topics[1], bytes32(uint256(uint160(address(this)))));
                assertEq(logs_[i_].topics[2], bytes32(uint256(uint160(address(this)))));
                assertEq(logs_[i_].data, abi.encode(shares_, a_.removed, a_.idle0, a_.idle1, a_.payout0, a_.payout1));
            }
        }
        assertEq(events_, 1);
        _settled();
    }

    function _assertSingle(uint256 shares_, bool output0_) private {
        SaleExpectation memory expected_;
        expected_.allocation = _afterMaintenance(shares_);
        uint256 snapshot_ = vm.snapshotState();
        vault.redeemPair(shares_, 0, 0, address(this), block.timestamp);
        expected_.unwanted = output0_ ? expected_.allocation.payout1 : expected_.allocation.payout0;
        {
            BalanceDelta sale_ = poolActor.swap(key, SwapParams(
                !output0_, -int256(expected_.unwanted),
                output0_ ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1
            ));
            assertEq(uint256(-int256(output0_ ? sale_.amount1() : sale_.amount0())), expected_.unwanted);
            expected_.proceeds = uint256(int256(output0_ ? sale_.amount0() : sale_.amount1()));
        }
        expected_.payout = (output0_ ? expected_.allocation.payout0 : expected_.allocation.payout1) + expected_.proceeds;
        expected_.economicState = _economicState();
        (expected_.fees0, expected_.fees1) = _claimable();
        assertTrue(vm.revertToState(snapshot_));
        IERC20 output_ = IERC20(output0_ ? address(token0) : address(token1));
        (uint256 previewAmountOut1,) = _exchange().previewExchangeIn(_share(), shares_, output_);
        assertEq(previewAmountOut1, expected_.payout);
        uint256 balance_ = output_.balanceOf(address(this));
        uint256 other_ = (output0_ ? token1 : token0).balanceOf(address(this));
        vm.recordLogs();
        (uint256 exchangeAmountOut2,) = _exchange().exchangeIn(_share(), shares_, output_, expected_.payout, address(this), false, block.timestamp);
        assertEq(exchangeAmountOut2,
            expected_.payout);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertEq(output_.balanceOf(address(this)), balance_ + expected_.payout);
        assertEq((output0_ ? token1 : token0).balanceOf(address(this)), other_, "no unwanted payout");
        assertEq(_share().totalSupply(), expected_.allocation.supply - shares_);
        assertEq(_economicState(), expected_.economicState, "same real removal and allocation-only sale");
        _assertMode(logs_, IVault.WithdrawalMode.FullCompound, IVault.MaintenanceReason.None);
        uint256 events_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == address(vault) && logs_[i_].topics[0] == IVault.WithdrawalSale.selector) {
                ++events_;
                assertEq(logs_[i_].data, abi.encode(shares_, expected_.allocation.payout0, expected_.allocation.payout1,
                    expected_.unwanted, expected_.proceeds, expected_.payout));
                assertEq(logs_[i_].topics[3], bytes32(uint256(uint160(address(output_)))));
            }
        }
        assertEq(events_, 1);
        (uint256 actualFee0_, uint256 actualFee1_) = _claimable();
        assertEq(actualFee0_, expected_.fees0);
        assertEq(actualFee1_, expected_.fees1);
        if (shares_ != expected_.allocation.supply) {
            assertGt(output0_ ? expected_.fees1 : expected_.fees0, 0, "exit-sale fees remain with holders");
        }
        _settled();
    }

    function _assertFallback(uint256 shares_, IVault.MaintenanceReason reason_) private {
        bytes32 before_ = _rollbackState();
        (IVault.WithdrawalMode selected_, IVault.MaintenanceReason actualReason_) =
            vault.previewWithdrawalMode(shares_, true, address(0));
        assertEq(uint256(selected_), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(actualReason_), uint256(reason_));
        assertEq(_rollbackState(), before_, "view candidate cannot leak state");
        // Standalone compound has no withdrawal fallback.
        if (reason_ == IVault.MaintenanceReason.MaintenanceWorkLimit) {
            vm.expectRevert(abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12));
        } else {
            vm.expectRevert();
        }
        vault.compound();
        assertEq(_rollbackState(), before_);
        (uint256 fee0_, uint256 fee1_) = _claimable();
        Allocation memory a_ = _allocation(shares_, fee0_, fee1_);
        _assertPair(shares_, a_, selected_, reason_);
    }

    function _assertMode(Vm.Log[] memory logs_, IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_)
        private view
    {
        uint256 count_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == address(vault) && logs_[i_].topics[0] == IVault.WithdrawalMaintenanceSelected.selector) {
                ++count_;
                assertEq(logs_[i_].data, abi.encode(mode_, reason_));
            }
        }
        assertEq(count_, 1);
    }

    function _freshPool(int24 spacing_, uint24 fee_, uint160 price_, uint16 maxBps_) private {
        key.tickSpacing = spacing_;
        key.fee = fee_;
        pool.initialize(key, price_);
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "exit special domain");
        args_.maxZapBps = maxBps_;
        vault = _deployVault(args_);
    }

    function _nativeVault() private {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "exit native mode"));
    }

    function _nativeRollbackState() private view returns (bytes32) {
        (uint128 owned_, uint256 last0_, uint256 last1_) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        bytes32 custody_ = keccak256(abi.encode(address(vault).balance, address(this).balance, address(pool).balance,
            token1.balanceOf(address(vault)), token1.balanceOf(address(this)), token1.balanceOf(address(pool))));
        return keccak256(abi.encode(_poolState(), owned_, last0_, last1_, book0_, book1_, custody_,
            _share().totalSupply(), _share().balanceOf(address(this))));
    }

    function _externalPosition(int24 lower_, int24 upper_, uint128 liquidity_, bytes32 salt_) private {
        _fund(address(poolActor), 1e40, 1e40);
        poolActor.modifyLiquidity(key, ModifyLiquidityParams(lower_, upper_, int256(uint256(liquidity_)), salt_));
    }

    function _donate(uint256 amount0_, uint256 amount1_) private {
        _fund(address(this), amount0_, amount1_);
        if (amount0_ != 0) vault.donate(address(token0), amount0_);
        if (amount1_ != 0) vault.donate(address(token1), amount1_);
    }

    function _claimable() private view returns (uint256 fee0_, uint256 fee1_) {
        (uint128 liquidity_, uint256 last0_, uint256 last1_) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 inside0_, uint256 inside1_) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        unchecked {
            // These vectors keep growth*liquidity below uint256.
            fee0_ = (inside0_ - last0_) * liquidity_ / (uint256(1) << 128);
            fee1_ = (inside1_ - last1_) * liquidity_ / (uint256(1) << 128);
        }
    }

    function _poolState() private view returns (bytes32) {
        (uint160 p_, int24 tick_, uint24 protocol_, uint24 fee_) = pool.getSlot0(key.toId());
        (uint256 growth0_, uint256 growth1_) = pool.getFeeGrowthGlobals(key.toId());
        return keccak256(abi.encode(p_, tick_, protocol_, fee_, growth0_, growth1_, pool.getLiquidity(key.toId())));
    }

    function _economicState() private view returns (bytes32) {
        (uint128 owned_, uint256 last0_, uint256 last1_) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        return keccak256(abi.encode(_poolState(), owned_, last0_, last1_, book0_, book1_,
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool))));
    }

    function _rollbackState() private view returns (bytes32) {
        return keccak256(abi.encode(_economicState(), _share().totalSupply(), _share().balanceOf(address(this)),
            _share().balanceOf(address(vault)), _share().allowance(address(this), address(vault)),
            token0.balanceOf(address(this)), token1.balanceOf(address(this)),
            token0.balanceOf(address(poolActor)), token1.balanceOf(address(poolActor)),
            token0.allowance(address(this), address(vault)), token1.allowance(address(this), address(vault))));
    }

    function _assertBook(uint256 book0_, uint256 book1_) private view {
        (uint256 actual0_, uint256 actual1_) = vault.localReserves();
        assertEq(actual0_, book0_);
        assertEq(actual1_, book1_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), book0_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), book1_);
        assertGe(token0.balanceOf(address(vault)), book0_);
        assertGe(token1.balanceOf(address(vault)), book1_);
    }

    function _settled() private view {
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1), 0);
    }

    function _share() private view returns (IERC20) { return IERC20(address(vault)); }
    function _exchange() private view returns (IStandardExchangeIn) { return IStandardExchangeIn(address(vault)); }
}
// end::UniswapV4PairTokenStandardExchangeVaultExitTest[]

/// @notice Boundary actor for an actual failed native payout, never a SUT replacement.
contract PairTokenExitRejectingNativeReceiver {
    receive() external payable { revert("reject exit ETH"); }
}
