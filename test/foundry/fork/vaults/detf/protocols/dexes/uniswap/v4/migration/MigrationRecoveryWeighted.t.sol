// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IMigrationWeightedNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
import {IMigrationWeightedClaims, IMigrationWeightedReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {MigrationRecoveryForkBase} from "./MigrationRecoveryForkBase.sol";

contract MigrationRecoveryWeightedTest is MigrationRecoveryForkBase {
    function test_weightedFullClaimUnstakeAndRealConversionPreserveNewBacking() public {
        uint256 bond_ = _take(WEIGHTED, 3);
        bytes32 protected_ = _protected(bond_);
        uint256 start_ = gasleft();
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        emit RecoveryGas("W1", 1, 1, start_ - gasleft());
        Recovery.NftRecovery memory r_ = recovery.migrationNftRecovery(WEIGHTED, 3);
        assertEq(r_.principalClaimed, 3772281649);
        assertGt(r_.rewardsClaimed, 0);
        uint256 amount_ = r_.principalClaimed + r_.rewardsClaimed;
        assertEq(_weightedAmount(), amount_);
        assertEq(IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(detf), amount_);
        assertEq(IERC721(WEIGHTED).ownerOf(3), address(0));
        start_ = gasleft();
        _run(Recovery.Stage.WeightedUnstake, 0, amount_, 0);
        emit RecoveryGas("W2", 1, 1, start_ - gasleft());
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), amount_);
        uint256 reserveBefore_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(0x46E068c2393e189Fbc86632f67210aF253a42Aa8);
        start_ = gasleft();
        _run(Recovery.Stage.WeightedConvert, 0, amount_, 1);
        emit RecoveryGas("W3", 1, 1, start_ - gasleft());
        uint256 out_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertGt(out_, 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), out_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        // This execution is the reserve-swap branch, not proof of primary burn.
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(0x46E068c2393e189Fbc86632f67210aF253a42Aa8) - reserveBefore_, amount_);
        assertEq(_protected(bond_), protected_);
        assertTrue(migration.nftSurrender(WEIGHTED, 3).consumed);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 3));
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
    }

    function test_partialPrincipalZeroRepeatNewVestingAndRewardOnlyFinalBurn() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        bytes32 protected_ = _protected(bond_);
        IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(WEIGHTED).positionOf(4);
        uint256 vested_ = p_.principal * (block.timestamp - p_.startTimestamp) / p_.vestingDuration;
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        assertEq(recovery.migrationNftRecovery(WEIGHTED, 4).principalClaimed, vested_ - p_.claimedPrincipal);
        uint256 first_ = _weightedAmount();
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        assertEq(_weightedAmount(), first_);
        vm.warp(vm.getBlockTimestamp() + 1 days);
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        assertGt(_weightedAmount(), first_);
        vm.warp(p_.startTimestamp + p_.vestingDuration);
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        assertEq(IMigrationWeightedNft(WEIGHTED).positionOf(4).claimedPrincipal, p_.principal);
        assertEq(IERC721(WEIGHTED).ownerOf(4), detf);
        _run(Recovery.Stage.WeightedRewards, 4, 0, 0);
        assertEq(IERC721(WEIGHTED).ownerOf(4), address(0));
        assertEq(recovery.migrationNftRecovery(WEIGHTED, 4).principalClaimed, p_.principal - p_.claimedPrincipal);
        assertEq(_protected(bond_), protected_);
    }

    function test_failedMiddleBatchRollsBackClaimAndSmallerRetrySucceeds() public {
        uint256 bond_ = _take(WEIGHTED, 3);
        bytes32 protected_ = _protected(bond_);
        bytes32 source_ = keccak256(abi.encode(IMigrationWeightedNft(WEIGHTED).positionOf(3)));
        Recovery.Step[] memory steps_ = new Recovery.Step[](3);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedClaim, 3, 0, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedClaim, 26, 0, 0);
        steps_[2] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 26));
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC721(WEIGHTED).ownerOf(3), detf);
        assertEq(keccak256(abi.encode(IMigrationWeightedNft(WEIGHTED).positionOf(3))), source_);
        assertEq(_weightedAmount(), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(detf), 0);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        assertGt(_weightedAmount(), 0);
    }

    function test_completedClaimSurvivesLaterConversionFailureAndRetry() public {
        _take(WEIGHTED, 3);
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        uint256 amount_ = _weightedAmount();
        _run(Recovery.Stage.WeightedUnstake, 0, amount_, 0);
        bytes32 claimed_ = keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3)));
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.WeightedConvert, 0, amount_, type(uint256).max);
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Recovery.recoverMigrationNfts, (steps_, block.timestamp)));
        assertFalse(ok_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), amount_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), amount_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3))), claimed_);
        _run(Recovery.Stage.WeightedConvert, 0, amount_, 1);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_DETF, amount_, 0
        ));
        _run(Recovery.Stage.WeightedConvert, 0, amount_, 1);
    }

    function test_currentOwnerBeforeAfterAcceptanceAndActivation() public {
        _take(WEIGHTED, 4);
        _configureNft(WEIGHTED, 26);
        address next_ = makeAddr("next recovery owner");
        vm.prank(migrationOwner);
        IMultiStepOwnable(detf).initiateOwnershipTransfer(next_);
        Recovery.Step[] memory steps_ = _step(Recovery.Stage.WeightedRewards, 4, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        vm.prank(next_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        _run(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        address old_ = migrationOwner;
        vm.prank(next_);
        IMultiStepOwnable(detf).acceptOwnershipTransfer();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, old_));
        vm.prank(old_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        migrationOwner = next_;
        _run(Recovery.Stage.WeightedRewards, 4, 0, 0);
        vm.prank(next_);
        allocation.activateMigration();
        _returnToOriginal(WEIGHTED, 26);
        _surrender(WEIGHTED, 26);
        _run(Recovery.Stage.WeightedClaim, 26, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, old_));
        vm.prank(old_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertGt(_weightedAmount(), 0);
        address last_ = makeAddr("postactivation recovery owner");
        vm.prank(next_);
        IMultiStepOwnable(detf).initiateOwnershipTransfer(last_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, last_));
        vm.prank(last_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        vm.prank(last_);
        IMultiStepOwnable(detf).acceptOwnershipTransfer();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        vm.prank(next_);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        migrationOwner = last_;
        _run(Recovery.Stage.WeightedRewards, 4, 0, 0);
    }

    function test_unsolicitedNftNeverBecomesRecoveryCustody() public {
        _configureNft(WEIGHTED, 26);
        address holder_ = IERC721(WEIGHTED).ownerOf(26);
        vm.prank(holder_);
        IERC721(WEIGHTED).transferFrom(holder_, detf, 26);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 26));
        _run(Recovery.Stage.WeightedClaim, 26, 0, 0);
        assertFalse(migration.nftSurrender(WEIGHTED, 26).consumed);
        assertEq(_weightedAmount(), 0);
    }

    function test_existingReceiptAndIndexMovementAreNotFreshClaimInventory() public {
        _take(WEIGHTED, 4);
        address holder_ = IERC721(WEIGHTED).ownerOf(3);
        vm.prank(holder_);
        IMigrationWeightedClaims(WEIGHTED).claimBond(3, detf);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 unbooked_ = old_.gonsOf(detf);
        uint256 k0_ = old_.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        uint256 k1_ = old_.stakingState().gonsPerUnit;
        assertLt(k1_, k0_);
        uint256 booked_ = _weightedAmount();
        assertEq(old_.gonsOf(detf), unbooked_ + recovery.migrationRecoveryGons());
        assertEq(recovery.migrationRecoveryGons(), booked_ * k1_);
        _run(Recovery.Stage.WeightedUnstake, 0, booked_ / 2, 0);
        _run(Recovery.Stage.WeightedUnstake, 0, booked_ - booked_ / 2, 0);
        assertEq(old_.gonsOf(detf), unbooked_);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
    }
}
