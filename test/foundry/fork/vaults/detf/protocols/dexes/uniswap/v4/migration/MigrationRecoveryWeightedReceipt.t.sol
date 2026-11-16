// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MigrationWeightedReceiptForkBase} from "./MigrationWeightedReceiptForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice New admitted WS custody composes with the existing fixed recovery route and budgets.
contract MigrationRecoveryWeightedReceiptTest is MigrationWeightedReceiptForkBase {
    function test_postCustodyGrowthFullAccountRetiresActualBookedFractionAndDonatesOnlyRecovery() public {
        uint256 c0_ = _configureWs(wsWallet, acquiredGons);
        _activate();
        (uint256 bond_,) = _surrenderWs(101);
        bytes32 protected_ = _protected(bond_);
        uint256 k0_ = oldReceipt.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _settleWs();
        uint256 k_ = oldReceipt.stakingState().gonsPerUnit;
        assertLt(k_, k0_);
        assertGt(acquiredGons % k_, 0);
        uint256 native_ = acquiredGons / k_;
        _run(Recovery.Stage.WeightedUnstake, 0, native_, 0);
        // Full-account source retirement debits MORE than native*k; all those gons are booked.
        assertEq(oldReceipt.gonsOf(detf), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), native_);
        _run(Recovery.Stage.WeightedConvert, 0, native_, 1);
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertGt(dtf_, 0);
        _run(Recovery.Stage.Donate, 0, dtf_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        // Existing reserve residuals may be consumed by its existing sweep. The separately
        // booked donor budget is the protected floor, not an immutable raw residual balance.
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), migration.migrationDonationInventory(IERC20(Legacy.DTF)));
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertEq(migration.weightedReceiptEntitlement(WS_ORIGIN).credit, c0_);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).deliveredCredit, c0_);
        assertEq(_protected(bond_), protected_);
    }

    function test_mixedNftWyWsAndUnbookedWholeFractionPreserveAllBudgets() public {
        _configureNft(WEIGHTED, 4);
        _configureWs(wsWallet, acquiredGons);
        address holder_ = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
        Migration.WeightedSyEntitlementInput[] memory a_ = new Migration.WeightedSyEntitlementInput[](1);
        a_[0] = Migration.WeightedSyEntitlementInput(
            bytes32("distinct synthetic WY"), holder_, Legacy.WEIGHTED_SY, 30, 0.01 ether, 0, bytes32("WY"), true
        );
        vm.prank(migrationOwner); allocation.configureWeightedSyEntitlements(a_, pricingId);
        _activate();
        (uint256 bond_,) = _surrenderWs(101);
        vm.startPrank(holder_);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 30);
        migration.surrenderMigrationWeightedSy(a_[0].originalId, 30, 1, block.timestamp);
        IERC20(Legacy.WEIGHTED_SY).transfer(detf, 7);
        vm.stopPrank();
        _surrender(WEIGHTED, 4);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        bytes memory nft_ = abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4));
        vm.prank(address(bytes20(hex"01b0b538d0201efacdde7bb0397abb2133723009")));
        IERC20(Legacy.WEIGHTED_RECEIPT).transfer(detf, 17);
        uint256 unbooked_ = oldReceipt.gonsOf(detf) - recovery.migrationRecoveryGons();
        IERC20(Legacy.DTF).transfer(detf, 7 ether);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _run(Recovery.Stage.WeightedSyRedeem, 0, 30, 1);
        uint256 k_ = oldReceipt.stakingState().gonsPerUnit;
        assertGt(unbooked_ % k_, 0);
        assertEq(oldReceipt.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        bytes32 protected_ = _protected(bond_);
        uint256 booked_ = recovery.migrationRecoveryGons() / k_;
        uint256 wholeAccount_ = oldReceipt.gonsOf(detf) / k_;
        // An actual full-account source exit cannot spend the unbooked native/fraction budget.
        vm.prank(migrationOwner);
        (bool full_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts,
            (_step(Recovery.Stage.WeightedUnstake, 0, wholeAccount_, 0), block.timestamp)));
        assertFalse(full_);
        assertEq(oldReceipt.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        _run(Recovery.Stage.WeightedUnstake, 0, booked_ / 2, 0);
        _run(Recovery.Stage.WeightedUnstake, 0, booked_ - booked_ / 2, 0);
        assertEq(oldReceipt.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        assertLt(recovery.migrationRecoveryGons(), k_);
        uint256 wd_ = recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF);
        _run(Recovery.Stage.WeightedConvert, 0, wd_, 1);
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        _run(Recovery.Stage.Donate, 0, dtf_, 1);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), 7 ether);
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertEq(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)), nft_);
        assertEq(_protected(bond_), protected_);
    }

    function test_lateSelectedFailureRevertsSourceGrowthUnstakeConversionAndBookkeeping() public {
        _configureWs(wsWallet, acquiredGons);
        _activate();
        (uint256 bond_,) = _surrenderWs(101);
        bytes32 protected_ = _protected(bond_);
        bytes32 before_ = _wsEconomicState(wsWallet);
        uint256 dtf_ = IERC20(Legacy.DTF).balanceOf(detf);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        Recovery.Step[] memory a_ = new Recovery.Step[](3);
        a_[0] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, 101, 0);
        a_[1] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, 101, 1);
        a_[2] = Recovery.Step(Recovery.Stage.WeightedClaim, 26, 0, 0);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 26));
        recovery.recoverMigrationNfts(a_, block.timestamp);
        assertEq(_wsEconomicState(wsWallet), before_);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), dtf_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.WeightedUnstake, 0, 101, 0);
        _run(Recovery.Stage.WeightedConvert, 0, 101, 1);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }
}
