// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Real pinned WY custody; original contribution/share allocation is explicitly synthetic.
contract MigrationRecoveryWeightedSyTest is MigrationRecoveryDonationForkBase {
    address constant HOLDER = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
    bytes32 constant ORIGIN = keccak256("synthetic WY recovery");
    uint256 constant SHARES = 8087; // Leave seven real holder shares for unsolicited-custody protection.

    function _takeSy() private returns (uint256 bond_) {
        address facet_ = 0x4B6e65CfC9a16aae0DfA4257A680f4697275e5fc;
        assertEq(facet_.codehash, 0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_SY).facetAddress(IMigrationWeightedSy.redeem.selector), facet_);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_SY).facetAddress(IERC20.transferFrom.selector), facet_);
        Migration.WeightedSyEntitlementInput[] memory inputs_ = new Migration.WeightedSyEntitlementInput[](1);
        inputs_[0] = Migration.WeightedSyEntitlementInput(
            ORIGIN, HOLDER, Legacy.WEIGHTED_SY, SHARES, 0.01 ether, 0, bytes32("synthetic WY inputs"), true
        );
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(inputs_);
        _activate();
        vm.startPrank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, SHARES);
        (bond_,) = migration.surrenderMigrationWeightedSy(ORIGIN, SHARES, 1, block.timestamp);
        IERC20(Legacy.WEIGHTED_SY).transfer(detf, 7);
        vm.stopPrank();
    }

    function _redeem(uint256 shares_) private returns (uint256 out_) {
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 before_ = old_.gonsOf(detf);
        uint256 wrapper_ = old_.gonsOf(Legacy.WEIGHTED_SY);
        uint256 booked_ = recovery.migrationRecoveryGons();
        uint256 sy_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        _run(Recovery.Stage.WeightedSyRedeem, 0, shares_, 1);
        uint256 k_ = old_.stakingState().gonsPerUnit;
        out_ = Math.mulDiv(shares_, Math.mulDiv(1e36, 1e18, k_), 1e18);
        assertEq(old_.gonsOf(detf) - before_, out_ * k_);
        assertEq(wrapper_ - old_.gonsOf(Legacy.WEIGHTED_SY), out_ * k_);
        assertEq(recovery.migrationRecoveryGons(), booked_ + out_ * k_);
        assertEq(_weightedAmount(), booked_ / k_ + out_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), sy_ - shares_);
        assertLt(out_ * k_, shares_ * 1e36);
    }

    function test_selectedRedemptionReconcilesGrowthDustMixedNftAndUnsolicitedGons() public {
        _configureNft(WEIGHTED, 4);
        uint256 bond_ = _takeSy();
        _surrender(WEIGHTED, 4);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        bytes memory nft_ = abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4));
        address donor_ = address(bytes20(hex"01b0b538d0201efacdde7bb0397abb2133723009"));
        vm.prank(donor_);
        IERC20(Legacy.WEIGHTED_RECEIPT).transfer(detf, 17);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 unbooked_ = old_.gonsOf(detf) - recovery.migrationRecoveryGons();
        uint256 k0_ = old_.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _redeem(SHARES / 2);
        assertLt(old_.stakingState().gonsPerUnit, k0_);
        _redeem(SHARES - SHARES / 2);
        uint256 amount_ = _weightedAmount();
        _run(Recovery.Stage.WeightedUnstake, 0, amount_ / 2, 0);
        _run(Recovery.Stage.WeightedUnstake, 0, amount_ - amount_ / 2, 0);
        assertEq(old_.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        assertLt(recovery.migrationRecoveryGons(), old_.stakingState().gonsPerUnit);
        assertEq(_weightedAmount(), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        assertEq(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)), nft_);
        assertEq(migration.weightedSySurrender(ORIGIN).deliveredCredit, bonds.positionOf(bond_).principal);
        assertEq(migration.weightedSySurrender(ORIGIN).remainingCredit, 0);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_SY, 1, 0));
        _run(Recovery.Stage.WeightedSyRedeem, 0, 1, 0);
    }

    function test_actualWyToWsToWdToDtfAndFixedDonationProtectBacking() public {
        uint256 bond_ = _takeSy();
        bytes32 protected_ = _protected(bond_);
        uint256 out_ = _redeem(SHARES);
        _run(Recovery.Stage.WeightedUnstake, 0, out_, 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), out_);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        _run(Recovery.Stage.WeightedConvert, 0, out_, 1);
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertGt(dtf_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), before_ + dtf_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        _run(Recovery.Stage.Donate, 0, dtf_ / 2, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtf_ - dtf_ / 2);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), before_ + dtf_ - dtf_ / 2);
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertEq(_protected(bond_), protected_);
    }

    function test_minimumAuthorityAndLateConversionFailureRollBackSelectedBurn() public {
        uint256 bond_ = _takeSy();
        bytes32 protected_ = _protected(bond_);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 wrapper_ = old_.gonsOf(Legacy.WEIGHTED_SY);
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.WeightedSyRedeem, 0, SHARES, 1);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.WEIGHTED_SY, SHARES + 1, SHARES));
        _run(Recovery.Stage.WeightedSyRedeem, 0, SHARES + 1, 1);
        steps_[0].minimum = type(uint256).max;
        vm.prank(migrationOwner);
        (bool minimum_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(minimum_);
        uint256 snapshot_ = vm.snapshotState();
        uint256 out_ = _redeem(SHARES);
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        steps_ = new Recovery.Step[](3);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedSyRedeem, 0, SHARES, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, out_, 0);
        steps_[2] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, out_, type(uint256).max);
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(ok_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), SHARES + 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), SHARES);
        assertEq(old_.gonsOf(Legacy.WEIGHTED_SY), wrapper_);
        assertEq(old_.gonsOf(detf), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
        steps_[2].minimum = 1;
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 7);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }
}
