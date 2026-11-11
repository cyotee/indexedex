// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {Vm} from "forge-std/Vm.sol";
import {MigrationRecoveryForkBase} from "./MigrationRecoveryForkBase.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedClaims, IMigrationWeightedReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice R1: a burned NFT's attributed receipt growth remains convertible through Migration.
contract MigrationRecoveryAccrualTest is MigrationRecoveryForkBase {
    event AttributedGrowthConverted(uint256 originalClaim, uint256 growth, uint256 divisor, uint256 wdReceived);

    function test_terminalBurnedNftGrowthConvertsAfterOriginalClaimSpent() public {
        uint256 bond_ = _take(WEIGHTED, 3);
        bytes32 protected_ = _protected(bond_);
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        uint256 original_ = _weightedAmount();
        assertEq(original_, 4308806205);
        assertEq(IERC721(WEIGHTED).ownerOf(3), address(0));
        bytes32 claimed_ = keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3)));
        // Match the independent witness's genuine external holder activity.
        address holder_ = IERC721(WEIGHTED).ownerOf(4);
        vm.prank(holder_);
        IMigrationWeightedClaims(WEIGHTED).claimBond(4, holder_);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 k0_ = old_.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _run(Recovery.Stage.WeightedUnstake, 0, original_, 0);
        uint256 k1_ = old_.stakingState().gonsPerUnit;
        assertLt(k1_, k0_);
        uint256 gons_ = old_.gonsOf(detf);
        uint256 growth_ = gons_ / k1_;
        assertEq(gons_, recovery.migrationRecoveryGons());
        assertEq(growth_, 488794);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), original_);

        // Positive execution is the regression: the old source rejects here with
        // RecoveryInventoryInsufficient(WS,1,0), before calling the receipt.
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        assertEq(old_.gonsOf(detf), gons_ - k1_);
        assertEq(recovery.migrationRecoveryGons(), gons_ - k1_);
        assertEq(_weightedAmount(), growth_ - 1);
        _run(Recovery.Stage.WeightedUnstake, 0, growth_ - 1, 0);
        assertEq(old_.gonsOf(detf), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), original_ + growth_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), original_ + growth_);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3))), claimed_);
        assertEq(_protected(bond_), protected_);
        emit AttributedGrowthConverted(original_, growth_, k1_, original_ + growth_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 3));
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
    }

    /// @notice Real whole and fractional unbooked gons survive every partial recovery exit.
    function test_revaluedPartialAndFinalExitsPreserveMixedUnbookedGons() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        bytes32 protected_ = _protected(bond_);
        address donor_ = IERC721(WEIGHTED).ownerOf(3);
        vm.prank(donor_);
        IMigrationWeightedClaims(WEIGHTED).claimBond(3, donor_);
        vm.prank(donor_);
        IERC20(Legacy.WEIGHTED_RECEIPT).transfer(detf, 17);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 unbooked_ = old_.gonsOf(detf);
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        uint256 original_ = _weightedAmount();
        bytes32 claimed_ = keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)));
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _run(Recovery.Stage.WeightedUnstake, 0, original_, 0);
        uint256 k_ = old_.stakingState().gonsPerUnit;
        assertGt(unbooked_ / k_, 0);
        assertGt(unbooked_ % k_, 0);
        uint256 growth_ = recovery.migrationRecoveryGons() / k_;
        assertGt(growth_, 1);
        _run(Recovery.Stage.WeightedUnstake, 0, growth_ / 2, 0);
        assertEq(old_.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        _run(Recovery.Stage.WeightedUnstake, 0, growth_ - growth_ / 2, 0);
        uint256 fraction_ = recovery.migrationRecoveryGons();
        assertLt(fraction_, k_);
        assertEq(old_.gonsOf(detf), unbooked_ + fraction_);
        assertEq(_weightedAmount(), 0);
        uint256 wd_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf);
        assertEq(wd_, original_ + growth_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        assertEq(old_.gonsOf(detf), unbooked_ + fraction_);
        assertEq(recovery.migrationRecoveryGons(), fraction_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), wd_);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4))), claimed_);
        assertEq(_protected(bond_), protected_);
    }

    /// @notice Revaluation, a later genuine claim, and subsequent conversion reconcile once each.
    function test_revaluationAndLaterClaimRemainSeparateWithoutDoubleCounting() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        bytes32 protected_ = _protected(bond_);
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        uint256 original_ = _weightedAmount();
        uint256 g0_ = recovery.migrationRecoveryGons();
        Recovery.NftRecovery memory first_ = recovery.migrationNftRecovery(WEIGHTED, 4);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        vm.recordLogs();
        _run(Recovery.Stage.WeightedUnstake, 0, original_, 0);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 k_ = old_.stakingState().gonsPerUnit;
        uint256 revaluations_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != detf) continue;
            assertTrue(logs_[i_].topics[0] != Recovery.MigrationRecoveryClaimed.selector);
            if (logs_[i_].topics[0] == Recovery.MigrationRecoveryRevalued.selector) {
                assertEq(logs_[i_].topics[1], bytes32(uint256(uint160(Legacy.WEIGHTED_RECEIPT))));
                assertEq(logs_[i_].data, abi.encode(original_, g0_ / k_, g0_, k_));
                ++revaluations_;
            }
        }
        assertEq(revaluations_, 1);
        uint256 beforeRepeat_ = _weightedAmount();
        vm.recordLogs();
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        logs_ = vm.getRecordedLogs();
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == detf) {
                assertTrue(logs_[i_].topics[0] != Recovery.MigrationRecoveryRevalued.selector);
                assertTrue(logs_[i_].topics[0] != Recovery.MigrationRecoveryClaimed.selector);
            }
        }
        assertEq(_weightedAmount(), beforeRepeat_ - 1);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4))),
            keccak256(abi.encode(first_)));
        uint256 held_ = recovery.migrationRecoveryGons();
        uint256 nativeBeforeClaim_ = _weightedAmount();
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        vm.recordLogs();
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        logs_ = vm.getRecordedLogs();
        uint256 k2_ = old_.stakingState().gonsPerUnit;
        assertLt(k2_, k_);
        Recovery.NftRecovery memory next_ = recovery.migrationNftRecovery(WEIGHTED, 4);
        uint256 newClaim_ = next_.principalClaimed - first_.principalClaimed
            + next_.rewardsClaimed - first_.rewardsClaimed;
        assertGt(newClaim_, 0);
        assertEq(old_.gonsOf(detf) - held_, newClaim_ * k2_);
        assertEq(recovery.migrationRecoveryGons(), held_ + newClaim_ * k2_);
        assertEq(_weightedAmount(), held_ / k2_ + newClaim_);
        uint256 claimEvents_;
        revaluations_ = 0;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != detf) continue;
            if (logs_[i_].topics[0] == Recovery.MigrationRecoveryClaimed.selector) {
                assertEq(logs_[i_].data, abi.encode(
                    next_.principalClaimed - first_.principalClaimed,
                    next_.rewardsClaimed - first_.rewardsClaimed
                ));
                ++claimEvents_;
            }
            if (logs_[i_].topics[0] == Recovery.MigrationRecoveryRevalued.selector) {
                assertEq(logs_[i_].data, abi.encode(nativeBeforeClaim_, held_ / k2_, held_, k2_));
                ++revaluations_;
            }
        }
        assertEq(claimEvents_, 1);
        assertEq(revaluations_, held_ / k2_ == nativeBeforeClaim_ ? 0 : 1);
        uint256 all_ = _weightedAmount();
        _run(Recovery.Stage.WeightedUnstake, 0, all_, 0);
        assertEq(old_.gonsOf(detf), 0);
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), original_ + 1 + all_);
        assertEq(_protected(bond_), protected_);
    }
}
