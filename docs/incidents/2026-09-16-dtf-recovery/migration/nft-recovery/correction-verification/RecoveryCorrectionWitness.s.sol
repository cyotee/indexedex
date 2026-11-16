// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {MigrationRecoveryForkBase} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryForkBase.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedClaims, IMigrationWeightedReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Independent execution of direct over-stored-budget recovery and late unbooked inventory.
/// @dev Simulation only; the inherited fixture is not the SUT. Snapshot branches restore
/// an actual reached state, never fabricate balances, gons, custody or source bytecode.
contract RecoveryCorrectionWitness is MigrationRecoveryForkBase {
    event DirectAccrualAuthorized(
        address parent, uint256 oldNativeBudget, uint256 selected, uint256 synchronizedValue,
        uint256 heldGons, uint256 divisor
    );
    event FullAttributedRetirement(uint256 exactWd, uint256 retiredGons);
    event MixedInventoryProtected(uint256 unbookedGons, uint256 attributableFraction, uint256 exactWd);

    function run() external {
        uint256 bond_ = _take(WEIGHTED, 3);
        bytes32 protected_ = _protected(bond_);
        bytes32 history_ = keccak256(abi.encode(
            migration.nftSurrender(WEIGHTED, 3), migration.nftCustody(WEIGHTED, 3)
        ));
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        assertEq(IERC721(WEIGHTED).ownerOf(3), address(0));
        uint256 original_ = _weightedAmount();
        assertEq(original_, 4308806205);
        bytes32 claims_ = keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3)));
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 attributedBefore_ = recovery.migrationRecoveryGons();
        assertEq(old_.gonsOf(detf), attributedBefore_);

        // Same genuine holder activity as the immutable terminal witness, not a new MIG claim.
        address donor_ = IERC721(WEIGHTED).ownerOf(4);
        vm.prank(donor_);
        IMigrationWeightedClaims(WEIGHTED).claimBond(4, donor_);
        uint256 donorWd_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(donor_);
        uint256 ownerWd_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(migrationOwner);
        uint256 k0_ = old_.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        assertEq(_weightedAmount(), original_);

        // Request more than the stored claim budget on the FIRST synchronization.
        // A pre-source native cap or an extra required priming call fails this witness.
        vm.recordLogs();
        _run(Recovery.Stage.WeightedUnstake, 0, original_ + 1, 0);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 k_ = old_.stakingState().gonsPerUnit;
        assertLt(k_, k0_);
        assertEq(k_, 875382550842670612356981754173735900);
        uint256 synchronized_ = attributedBefore_ / k_;
        assertEq(synchronized_, original_ + 488794);
        assertEq(_weightedAmount(), 488793);
        assertEq(old_.gonsOf(detf), attributedBefore_ - (original_ + 1) * k_);
        assertEq(recovery.migrationRecoveryGons(), old_.gonsOf(detf));
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), original_ + 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), original_ + 1);
        uint256 adjustments_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != detf) continue;
            assertTrue(logs_[i_].topics[0] != Recovery.MigrationRecoveryClaimed.selector);
            if (logs_[i_].topics[0] == Recovery.MigrationRecoveryRevalued.selector) {
                assertEq(logs_[i_].topics[1], bytes32(uint256(uint160(Legacy.WEIGHTED_RECEIPT))));
                assertEq(logs_[i_].data, abi.encode(original_, synchronized_, attributedBefore_, k_));
                ++adjustments_;
            }
        }
        assertEq(adjustments_, 1);
        emit DirectAccrualAuthorized(detf, original_, original_ + 1, synchronized_, old_.gonsOf(detf), k_);

        uint256 checkpoint_ = vm.snapshotState();
        uint256 held_ = recovery.migrationRecoveryGons();
        _run(Recovery.Stage.WeightedUnstake, 0, 488793, 0);
        assertEq(old_.gonsOf(detf), 0);
        assertEq(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), synchronized_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), synchronized_);
        assertEq(_protected(bond_), protected_);
        emit FullAttributedRetirement(synchronized_, held_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        assertTrue(vm.revertToStateAndDelete(checkpoint_));

        // A late real transfer is never classified as recovery, even after the NFT is burned.
        vm.prank(donor_);
        assertTrue(IERC20(Legacy.WEIGHTED_RECEIPT).transfer(detf, 17));
        uint256 unbooked_ = old_.gonsOf(detf) - recovery.migrationRecoveryGons();
        assertEq(unbooked_, 17 * k_);
        uint256 allBefore_ = old_.gonsOf(detf);
        bytes32 sourceBefore_ = keccak256(abi.encode(old_.stakingState()));
        uint256 wdBefore_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf);
        // The source can pay this because of unbooked inventory. MIG must revert that
        // source debit/output rather than permit even one extra native recovery unit.
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 488794, 488793
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 488794, 0);
        assertEq(old_.gonsOf(detf), allBefore_);
        assertEq(recovery.migrationRecoveryGons(), held_);
        assertEq(_weightedAmount(), 488793);
        assertEq(keccak256(abi.encode(old_.stakingState())), sourceBefore_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), wdBefore_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), wdBefore_);

        _run(Recovery.Stage.WeightedUnstake, 0, 7, 0);
        assertEq(old_.gonsOf(detf), allBefore_ - 7 * k_);
        assertEq(old_.gonsOf(detf) - recovery.migrationRecoveryGons(), unbooked_);
        _run(Recovery.Stage.WeightedUnstake, 0, 488786, 0);
        uint256 fraction_ = held_ - 488793 * k_;
        assertGt(fraction_, 0);
        assertLt(fraction_, k_);
        assertEq(_weightedAmount(), 0);
        assertEq(old_.gonsOf(detf), unbooked_ + fraction_);
        assertEq(recovery.migrationRecoveryGons(), fraction_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        assertEq(old_.gonsOf(detf), unbooked_ + fraction_);
        assertEq(recovery.migrationRecoveryGons(), fraction_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), synchronized_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), synchronized_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(donor_), donorWd_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(migrationOwner), ownerWd_);
        assertEq(IERC20(Legacy.WEIGHTED_RECEIPT).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 3))), claims_);
        assertEq(_protected(bond_), protected_);
        assertEq(keccak256(abi.encode(
            migration.nftSurrender(WEIGHTED, 3), migration.nftCustody(WEIGHTED, 3)
        )), history_);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 3));
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        emit MixedInventoryProtected(unbooked_, fraction_, synchronized_);
    }
}

contract RecoveryCorrectionWitnessRunner is Script {
    function run() external {
        RecoveryCorrectionWitness witness_ = new RecoveryCorrectionWitness();
        vm.allowCheatcodes(address(witness_));
        witness_.setUp();
        witness_.run();
    }
}
