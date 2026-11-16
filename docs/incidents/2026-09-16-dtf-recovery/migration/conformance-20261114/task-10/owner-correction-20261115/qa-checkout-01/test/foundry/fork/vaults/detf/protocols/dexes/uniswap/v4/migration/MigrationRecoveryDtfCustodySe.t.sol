// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {MigrationDtfCustodySeForkBase, IDtfCustodySeAcquisition} from "./MigrationDtfCustodySeForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

contract MigrationRecoveryDtfCustodySeTest is MigrationDtfCustodySeForkBase {
    function _takeSe() private returns (uint256 bond_) {
        _configureSe(seHolder, acquiredShares - 7);
        _activate();
        (bond_,) = _surrenderSe(acquiredShares - 7);
        vm.prank(seHolder);
        IERC20(Legacy.DTF_CUSTODY_SE).transfer(detf, 7);
    }

    function _redeemSe(uint256 q_) private returns (uint256 out_) {
        uint256 sharesBefore_ = IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf);
        uint256 totalBefore_ = IERC20(Legacy.DTF_CUSTODY_SE).totalSupply();
        uint256 assetsBefore_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 sourceBefore_ = IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE);
        uint256 bookedBefore_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        uint256 sharesBooked_ = recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE);
        out_ = IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).previewRedeem(q_);
        assertGt(out_, 0);
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, q_, out_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), sharesBefore_ - q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).totalSupply(), totalBefore_ - q_);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), assetsBefore_ + out_);
        assertEq(IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE), sourceBefore_ - out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), bookedBefore_ + out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), sharesBooked_ - q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).allowance(detf, Legacy.DTF_CUSTODY_SE), 0);
    }

    function test_selectedNative28BurnUsesActualOutputAndNeverRepricesCredit() public {
        uint256 bond_ = _takeSe();
        bytes32 protected_ = _protected(bond_);
        bytes memory credit_ = abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN));
        uint256 q_ = (acquiredShares - 7) / 3 + 1;
        uint256 originalQuote_ = IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).previewRedeem(q_);
        // Real unsolicited asset transfer changes source redemption value, not frozen compensation.
        IERC20(Legacy.DTF).transfer(Legacy.DTF_CUSTODY_SE, 1 ether);
        uint256 first_ = _redeemSe(q_);
        assertGt(first_, originalQuote_);
        uint256 second_ = _redeemSe(acquiredShares - 7 - q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), first_ + second_);
        assertEq(abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN)), credit_);
        assertEq(_protected(bond_), protected_);
        uint256 lp_ = IERC20(reserveHook).balanceOf(address(bonds));
        IERC20(Legacy.DTF).transfer(detf, 7 ether);
        uint256 assets_ = IERC20(Legacy.DTF).balanceOf(detf);
        _run(Recovery.Stage.Donate, 0, first_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), second_);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), assets_ - first_);
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), lp_);
        assertEq(_protected(bond_), protected_);
    }

    function test_minimumSelectedBatchAndLaterFailurePreserveCommittedReceipts() public {
        uint256 bond_ = _takeSe();
        uint256 q_ = acquiredShares - 7;
        bytes32 protected_ = _protected(bond_);
        uint256 sourceAssets_ = IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE);
        uint256 sourceSupply_ = IERC20(Legacy.DTF_CUSTODY_SE).totalSupply();
        uint256 assets_ = IERC20(Legacy.DTF).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryDeltaMismatch.selector, Legacy.DTF_CUSTODY_SE));
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, q_, type(uint256).max);
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.DtfCustodySeRedeem, 0, q_ / 2, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.DtfCustodySeRedeem, 0, q_, 1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.DTF_CUSTODY_SE, q_, q_ - q_ / 2));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), acquiredShares);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).totalSupply(), sourceSupply_);
        assertEq(IERC20(Legacy.DTF).balanceOf(Legacy.DTF_CUSTODY_SE), sourceAssets_);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), assets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), q_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
        uint256 out_ = _redeemSe(q_ / 2);
        uint256 committedAssets_ = IERC20(Legacy.DTF).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.DTF_CUSTODY_SE, q_, q_ - q_ / 2));
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, q_, 1);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), committedAssets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        steps_[0] = Recovery.Step(Recovery.Stage.DtfCustodySeRedeem, 0, q_ - q_ / 2, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.Donate, 0, out_, type(uint256).max);
        vm.prank(migrationOwner);
        (bool donated_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(donated_);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), committedAssets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), q_ - q_ / 2);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        assertEq(_protected(bond_), protected_);
        _redeemSe(q_ - q_ / 2);
    }

    function test_onlyCurrentOwnerSelectsBookedSharesAndNoOtherSource() public {
        _takeSe();
        uint256 q_ = acquiredShares - 7;
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.DtfCustodySeRedeem, 0, q_, 1);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.DTF_CUSTODY_SE, 0, q_));
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, 0, 1);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        _run(Recovery.Stage.DtfCustodySeRedeem, 1, q_, 1);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.DTF_CUSTODY_SE, q_ + 1, q_));
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, q_ + 1, 1);
        address next_ = makeAddr("new recovery owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.prank(next_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), 7);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
    }

    function test_recoveryPreservesMixedNftLiquidSyAndUnsolicitedInventory() public {
        _configureNft(WEIGHTED, 4);
        address liquidHolder_ = address(bytes20(hex"082cb14f04d9c485473dedc00d604d7e9abca303"));
        address syHolder_ = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
        Migration.WeightedLiquidEntitlementInput[] memory d_ = new Migration.WeightedLiquidEntitlementInput[](1);
        d_[0] = Migration.WeightedLiquidEntitlementInput(bytes32("mixed WD"), liquidHolder_, Legacy.WEIGHTED_DETF,
            30, 0.001 ether, 0, bytes32("synthetic WD"), true);
        Migration.WeightedSyEntitlementInput[] memory y_ = new Migration.WeightedSyEntitlementInput[](1);
        y_[0] = Migration.WeightedSyEntitlementInput(bytes32("mixed WY"), syHolder_, Legacy.WEIGHTED_SY,
            30, 0.001 ether, 0, bytes32("synthetic WY"), true);
        vm.startPrank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(d_, pricingId);
        allocation.configureWeightedSyEntitlements(y_, pricingId);
        vm.stopPrank();
        uint256 bond_ = _takeSe();
        _surrender(WEIGHTED, 4);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        vm.startPrank(liquidHolder_);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, 30);
        migration.surrenderMigrationWeightedLiquid(bytes32("mixed WD"), 30, 1, block.timestamp);
        vm.stopPrank();
        vm.startPrank(syHolder_);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 30);
        migration.surrenderMigrationWeightedSy(bytes32("mixed WY"), 30, 1, block.timestamp);
        IERC20(Legacy.WEIGHTED_SY).transfer(detf, 7);
        vm.stopPrank();
        _run(Recovery.Stage.WeightedConvert, 0, 10, 1);
        bytes32 protected_ = _protected(bond_);
        bytes memory nft_ = abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4));
        uint256 gons_ = recovery.migrationRecoveryGons();
        uint256 receipt_ = _weightedAmount();
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        uint256 out_ = _redeemSe(acquiredShares - 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtf_ + out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 20);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 20);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 30);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 37);
        assertEq(recovery.migrationRecoveryGons(), gons_);
        assertEq(_weightedAmount(), receipt_);
        assertEq(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)), nft_);
        assertEq(_protected(bond_), protected_);
    }
}
