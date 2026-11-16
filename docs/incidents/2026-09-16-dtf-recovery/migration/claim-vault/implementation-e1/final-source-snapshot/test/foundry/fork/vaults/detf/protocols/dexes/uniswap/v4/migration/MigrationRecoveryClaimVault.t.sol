// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {MigrationClaimVaultForkBase, IClaimVaultAcquisition} from "./MigrationClaimVaultForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

contract MigrationRecoveryClaimVaultTest is MigrationClaimVaultForkBase {
    function _takeSe() private returns (uint256 bond_) {
        _configureSe(seHolder, acquiredShares - 7);
        _activate();
        (bond_,) = _surrenderSe(acquiredShares - 7);
        vm.prank(seHolder);
        IERC20(Legacy.CLAIM_VAULT).transfer(detf, 7);
    }

    function _redeemSe(uint256 q_) private returns (uint256 out_) {
        uint256 sharesBefore_ = IERC20(Legacy.CLAIM_VAULT).balanceOf(detf);
        uint256 totalBefore_ = IERC20(Legacy.CLAIM_VAULT).totalSupply();
        uint256 assetsBefore_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        uint256 sourceBefore_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT);
        uint256 bookedBefore_ = recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY);
        uint256 sharesBooked_ = recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT);
        out_ = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).previewRedeem(q_);
        assertGt(out_, 0);
        _run(Recovery.Stage.ClaimVaultRedeem, 0, q_, out_);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(detf), sharesBefore_ - q_);
        assertEq(IERC20(Legacy.CLAIM_VAULT).totalSupply(), totalBefore_ - q_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), assetsBefore_ + out_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT), sourceBefore_ - out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), bookedBefore_ + out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT), sharesBooked_ - q_);
        assertEq(IERC20(Legacy.CLAIM_VAULT).allowance(detf, Legacy.CLAIM_VAULT), 0);
    }

    function test_selectedNative19BurnUsesActualOutputAndNeverRepricesCredit() public {
        uint256 bond_ = _takeSe();
        bytes32 protected_ = _protected(bond_);
        bytes memory credit_ = abi.encode(migration.claimVaultSurrender(SE_ORIGIN));
        uint256 q_ = (acquiredShares - 7) / 3 + 1;
        uint256 quote_ = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).previewRedeem(q_);
        uint256 depositQuote_ = IClaimVaultAcquisition(Legacy.CLAIM_VAULT).previewDeposit(3000);
        IERC20(Legacy.WEIGHTED_SY).transfer(Legacy.CLAIM_VAULT, 3000);
        assertLt(IClaimVaultAcquisition(Legacy.CLAIM_VAULT).previewDeposit(3000), depositQuote_);
        uint256 first_ = _redeemSe(q_);
        assertGe(first_, quote_);
        uint256 second_ = _redeemSe(acquiredShares - 7 - q_);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(detf), 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), first_ + second_);
        assertEq(abi.encode(migration.claimVaultSurrender(SE_ORIGIN)), credit_);
        assertEq(_protected(bond_), protected_);
        IERC20(Legacy.WEIGHTED_SY).transfer(detf, 7);
        uint256 sy_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        _run(Recovery.Stage.WeightedSyRedeem, 0, first_ + second_, 1);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), sy_ - first_ - second_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        uint256 ws_ = _weightedAmount();
        _run(Recovery.Stage.WeightedUnstake, 0, ws_, 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        _run(Recovery.Stage.WeightedConvert, 0, ws_, 1);
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        uint256 lp_ = IERC20(reserveHook).balanceOf(address(bonds));
        _run(Recovery.Stage.Donate, 0, dtf_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), lp_);
        assertEq(_protected(bond_), protected_);
    }

    function test_minimumSelectedBatchAndLaterFailurePreserveCommittedReceipts() public {
        uint256 bond_ = _takeSe();
        uint256 q_ = acquiredShares - 7;
        bytes32 protected_ = _protected(bond_);
        uint256 sourceAssets_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT);
        uint256 sourceSupply_ = IERC20(Legacy.CLAIM_VAULT).totalSupply();
        uint256 assets_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryDeltaMismatch.selector, Legacy.CLAIM_VAULT));
        _run(Recovery.Stage.ClaimVaultRedeem, 0, q_, type(uint256).max);
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.ClaimVaultRedeem, 0, q_ / 2, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.ClaimVaultRedeem, 0, q_, 1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.CLAIM_VAULT, q_, q_ - q_ / 2));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(detf), acquiredShares);
        assertEq(IERC20(Legacy.CLAIM_VAULT).totalSupply(), sourceSupply_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(Legacy.CLAIM_VAULT), sourceAssets_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), assets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT), q_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        assertEq(_protected(bond_), protected_);
        uint256 out_ = _redeemSe(q_ / 2);
        uint256 committedAssets_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.CLAIM_VAULT, q_, q_ - q_ / 2));
        _run(Recovery.Stage.ClaimVaultRedeem, 0, q_, 1);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), committedAssets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), out_);
        steps_[0] = Recovery.Step(Recovery.Stage.ClaimVaultRedeem, 0, q_ - q_ / 2, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.Donate, 0, out_, type(uint256).max);
        vm.prank(migrationOwner);
        (bool donated_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(donated_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), committedAssets_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.CLAIM_VAULT), q_ - q_ / 2);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), out_);
        assertEq(_protected(bond_), protected_);
        _redeemSe(q_ - q_ / 2);
    }

    function test_onlyCurrentOwnerSelectsBookedSharesAndNoOtherSource() public {
        _takeSe();
        uint256 q_ = acquiredShares - 7;
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.ClaimVaultRedeem, 0, q_, 1);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.CLAIM_VAULT, 0, q_));
        _run(Recovery.Stage.ClaimVaultRedeem, 0, 0, 1);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        _run(Recovery.Stage.ClaimVaultRedeem, 1, q_, 1);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.CLAIM_VAULT, q_ + 1, q_));
        _run(Recovery.Stage.ClaimVaultRedeem, 0, q_ + 1, 1);
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
        assertEq(IERC20(Legacy.CLAIM_VAULT).balanceOf(detf), 7);
        assertGt(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
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
        allocation.configureWeightedLiquidEntitlements(d_);
        allocation.configureWeightedSyEntitlements(y_);
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
        uint256 sy_ = recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY);
        uint256 dtf_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        uint256 out_ = _redeemSe(acquiredShares - 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), sy_ + out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtf_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 20);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 20);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 30 + out_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 37 + out_);
        assertEq(recovery.migrationRecoveryGons(), gons_);
        assertEq(_weightedAmount(), receipt_);
        assertEq(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)), nft_);
        assertEq(_protected(bond_), protected_);
    }
}

