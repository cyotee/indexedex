// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadMaintenance} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadMaintenance.sol";
import {TestBase_UniswapV3FullSpreadMaintenanceTransfers} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadMaintenanceTransfers.sol";
import {UniswapV3MaintenanceTransferToken as TransferToken} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/tokens/UniswapV3MaintenanceTransferToken.sol";

/// @notice V3-OWN-02 and V3-ACC-08/09/11/16: maintenance uses live authority and eligible custody.
contract UniswapV3FullSpreadAccounting_Maintenance_Test is TestBase_UniswapV3FullSpreadMaintenance {
    /// @notice Stranger, live owner, global operator, donate-only, and compound-only matrix.
    function testFuzz_liveOwnerGlobalAndFunctionAuthority(uint8 role_, bool revoked_) public {
        role_ = uint8(bound(role_, 0, 4));
        _seedVault(SEED);
        Family maintenance_ = Family(address(vault));
        vm.startPrank(alice);
        if (role_ == 2) maintenance_.setOperator(bob, true);
        if (role_ >= 3) maintenance_.setOperatorFor(role_ == 3 ? Family.donate.selector : Family.compound.selector, bob, true);
        if (revoked_ && role_ == 2) maintenance_.setOperator(bob, false);
        if (revoked_ && role_ >= 3) maintenance_.setOperatorFor(role_ == 3 ? Family.donate.selector : Family.compound.selector, bob, false);
        vm.stopPrank();
        address caller_ = role_ == 1 ? alice : bob;
        bool donateAllowed_ = role_ == 1 || (!revoked_ && (role_ == 2 || role_ == 3));
        bool compoundAllowed_ = role_ == 1 || (!revoked_ && (role_ == 2 || role_ == 4));
        vm.recordLogs();
        if (!donateAllowed_) vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, caller_));
        _donate(caller_, address(token0), 1);
        if (!compoundAllowed_) vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, caller_));
        vm.prank(caller_);
        maintenance_.compound();
        _maintenanceEvents(vm.getRecordedLogs(), donateAllowed_ ? 1 : 0, 0);
    }

    function testFuzz_onlyLiveOwnerAppointsEvenWithOperatorAuthority(bool function_, uint8 actor_) public {
        actor_ = uint8(bound(actor_, 0, 2));
        vm.startPrank(alice);
        Family(address(vault)).setOperator(bob, true);
        Family(address(vault)).setOperatorFor(Family.setOperatorFor.selector, recipient, true);
        vm.stopPrank();
        address caller_ = actor_ == 0 ? bob : actor_ == 1 ? recipient : address(0xBAD);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, caller_));
        vm.prank(caller_);
        if (function_) Family(address(vault)).setOperatorFor(Family.donate.selector, caller_, true);
        else Family(address(vault)).setOperator(caller_, true);
    }

    function test_ownerChangeImmediatelyReplacesOwnerButPreservesAppointments() public {
        _seedVault(SEED);
        vm.startPrank(alice);
        Family(address(vault)).setOperator(recipient, true);
        Family(address(vault)).setOperatorFor(Family.donate.selector, address(this), true);
        vm.stopPrank();
        _setFeeRecipient(bob);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, alice));
        _donate(alice, address(token0), 1);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, alice));
        vm.prank(alice);
        Family(address(vault)).setOperator(alice, true);
        _donate(bob, address(token0), 1);
        _donate(recipient, address(token0), 1);
        _donate(address(this), address(token0), 1);
        vm.prank(bob);
        Family(address(vault)).setOperatorFor(Family.compound.selector, alice, true);
        vm.prank(alice);
        Family(address(vault)).compound();
    }

    function test_donationBeforeGenesisRevertsWithoutTakingInput() public {
        uint256 balance_ = token0.balanceOf(alice);
        vm.expectRevert(Family.MinLiquidityNotMet.selector);
        _donate(alice, address(token0), 1);
        assertEq(token0.balanceOf(alice), balance_);
        assertEq(vault.totalSupply(), 0);
    }

    function testFuzz_disabledAppointmentReverts(bool function_) public {
        _setDisabled(true);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));
        vm.prank(alice);
        if (function_) Family(address(vault)).setOperatorFor(Family.donate.selector, bob, true);
        else Family(address(vault)).setOperator(bob, true);
    }

    function testFuzz_disabledMaintenanceStillProcessesLiquidity(bool compound_) public {
        _seedVault(SEED);
        if (compound_) _poolFees(1e12, 1e12);
        _setDisabled(true);
        uint128 liquidity_ = _positionLiquidity();
        uint256 supply_ = vault.totalSupply();
        vm.recordLogs();
        if (compound_) {
            vm.prank(alice);
            Family(address(vault)).compound();
        } else _donate(alice, address(token0), 1e10);
        assertGt(_positionLiquidity(), liquidity_);
        assertEq(vault.totalSupply(), supply_);
        _maintenanceEvents(vm.getRecordedLogs(), compound_ ? 0 : 1, compound_ ? 1 : 0);
        _assertSettled();
    }

    function testFuzz_underlyingDonationSwapsFortyNinePercentAndMintsNoShares(bool tokenOne_) public {
        _seedVault(SEED);
        _setUsageFee(3e17);
        uint256 supply_ = vault.totalSupply();
        uint256 shares_ = vault.balanceOf(alice);
        IERC20 input_ = IERC20(tokenOne_ ? address(token1) : address(token0));
        uint256 balance_ = input_.balanceOf(alice);
        vm.recordLogs();
        _donate(alice, address(input_), 1e10);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        PoolTrace memory trace_ = _poolTrace(logs_);
        assertEq(trace_.swaps, 1);
        assertEq(trace_.mints, 1);
        assertEq(tokenOne_ ? trace_.delta1 : trace_.delta0, int256(49e8));
        assertEq(input_.balanceOf(alice), balance_ - 1e10);
        assertEq(vault.totalSupply(), supply_);
        assertEq(vault.balanceOf(alice), shares_);
        _maintenanceEvents(logs_, 1, 0);
        _assertSettled();
    }

    function testFuzz_shareDonationBurnsCallerAndProcessesOnlyEligibleCustody(bool fees_) public {
        _seedVault(SEED);
        uint128 added_;
        if (fees_) {
            (uint256 fee0_, uint256 fee1_) = _poolFees(1e12, 1e12);
            added_ = _expectedLiquidity(Q96, fee0_, fee1_);
        }
        vm.prank(alice);
        vault.transfer(address(vault), 777);
        uint256 supply_ = vault.totalSupply();
        uint256 held_ = vault.balanceOf(alice);
        uint128 liquidity_ = _positionLiquidity();
        vm.recordLogs();
        _donate(alice, address(vault), 123);
        _maintenanceEvents(vm.getRecordedLogs(), 1, fees_ ? 1 : 0);
        assertEq(vault.totalSupply(), supply_ - 123);
        assertEq(vault.balanceOf(alice), held_ - 123);
        assertEq(vault.balanceOf(address(vault)), 777);
        assertEq(_positionLiquidity(), liquidity_ + added_);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, held_ - 123, held_));
        _donate(alice, address(vault), held_);
    }

    function test_bookedOpposingTokenChangesDonationIntoNoSwapProportionalAdd() public {
        _seedVault(SEED);
        _donate(alice, address(token1), 1);
        uint128 liquidity_ = _positionLiquidity();
        vm.recordLogs();
        _donate(alice, address(token0), 1);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        PoolTrace memory trace_ = _poolTrace(logs_);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 1);
        assertEq(_positionLiquidity(), liquidity_ + 1);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, 0);
        assertEq(booked1_, 0);
        _maintenanceEvents(logs_, 1, 1);
    }

    function testFuzz_unformableDonationBooksInputAndEmitsOnlyDonation(bool tokenOne_) public {
        _seedVault(SEED);
        uint128 liquidity_ = _positionLiquidity();
        vm.recordLogs();
        _donate(alice, tokenOne_ ? address(token1) : address(token0), 1);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        PoolTrace memory trace_ = _poolTrace(logs_);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 0);
        assertEq(_positionLiquidity(), liquidity_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, tokenOne_ ? 0 : 1);
        assertEq(booked1_, tokenOne_ ? 1 : 0);
        _maintenanceEvents(logs_, 1, 0);
    }

    function test_emptyCompoundIgnoresStrayCustodyAndEmitsNothing() public {
        _seedVault(SEED);
        token0.mint(address(vault), 77);
        vm.recordLogs();
        vm.prank(alice);
        Family(address(vault)).compound();
        assertEq(vm.getRecordedLogs().length, 0);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, 0);
        assertEq(booked1_, 0);
        assertEq(token0.balanceOf(address(vault)), 77);
        _assertSettled();
    }

    function test_compoundUsesCollectedFeesButNotStrayCustodyForSizing() public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e12, 1e12);
        token0.mint(address(vault), 77);
        uint128 liquidity_ = _positionLiquidity();
        uint128 added_ = _expectedLiquidity(Q96, fee0_, fee1_);
        uint256 supply_ = vault.totalSupply();
        vm.recordLogs();
        vm.prank(alice);
        Family(address(vault)).compound();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        PoolTrace memory trace_ = _poolTrace(logs_);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 1);
        assertEq(_positionLiquidity(), liquidity_ + added_);
        assertEq(vault.totalSupply(), supply_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_ - trace_.mint0 + 77);
        assertEq(booked1_, fee1_ - trace_.mint1);
        _maintenanceEvents(logs_, 0, 1);
        _assertSettled();
    }
}

/// @notice V3-OWN-02: real token transfers distinguish qualifying booking from rollback.
contract UniswapV3FullSpreadAccounting_MaintenanceTransfer_Test is TestBase_UniswapV3FullSpreadMaintenanceTransfers {
    function test_qualifyingCallbackBooksCustodyArrivingDuringProcessing() public {
        ERC20PermitMintableStub other_ = address(hostile) == address(token0) ? token1 : token0;
        _donate(alice, address(other_), 1);
        other_.mint(address(hostile), 77);
        hostile.arm(TransferToken.Trigger(address(vault), address(pool), IERC20(address(other_)), 77, false));
        uint128 liquidity_ = _positionLiquidity();
        vm.recordLogs();
        _donate(alice, address(hostile), 1);
        _maintenanceEvents(vm.getRecordedLogs(), 1, 1);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, address(other_) == address(token0) ? 77 : 0);
        assertEq(booked1_, address(other_) == address(token1) ? 77 : 0);
        assertEq(_positionLiquidity(), liquidity_ + 1);
        assertEq(other_.balanceOf(address(hostile)), 0);
        _assertSettled();
    }

    function test_realCallbackPaymentFailureRevertsDonationAndBooking() public {
        ERC20PermitMintableStub other_ = address(hostile) == address(token0) ? token1 : token0;
        _donate(alice, address(other_), 1);
        hostile.arm(TransferToken.Trigger(address(vault), address(pool), IERC20(address(other_)), 0, true));
        CustodySnapshot memory before_ = _custodySnapshot();
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        _donate(alice, address(hostile), 1);
        _assertCustodyUnchanged(before_);
    }

    function test_fundingReentryObservesCanonicalIsLockedAndRollsBackEverything() public {
        ERC20PermitMintableStub other_ = address(hostile) == address(token0) ? token1 : token0;
        _donate(alice, address(other_), 1);
        vm.prank(alice);
        Family(address(vault)).setOperator(address(hostile), true);
        hostile.armFundingReentry(address(vault), abi.encodeCall(Family.compound, ()));
        CustodySnapshot memory before_ = _custodySnapshot();
        vm.expectRevert(abi.encodeWithSelector(
            TransferToken.ReentryRejected.selector, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)
        ));
        _donate(alice, address(hostile), 1);
        _assertCustodyUnchanged(before_);
        // A successful retry proves the reverted operation also released its transient lock.
        hostile.armFundingReentry(address(0), "");
        _donate(alice, address(hostile), 1);
        assertEq(_positionLiquidity(), before_.liquidity + 1);
    }
}
