// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {MigrationRecoveryForkBase} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedReceipt, IMigrationEarlierReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Independent sequence: booked receipt revaluation between stages, immutable
/// custody after configuration replacement, and both source models in one selected call.
/// @dev Simulation only. The fixture inherits the real registry TestBase, never the SUT.
contract RecoverySequenceWitness is MigrationRecoveryForkBase {
    event VerifiedRecoverySequence(
        address parent, uint256 firstReceipt, uint256 secondReceipt,
        uint256 heldGons, uint256 dtf, uint256 earlierShares
    );

    function run() external {
        uint256 weightedBond_ = _take(WEIGHTED, 4);
        uint256 earlierBond_ = _take(EARLIER, 4);
        bytes32 protectedWeighted_ = _protected(weightedBond_);
        bytes32 protectedEarlier_ = _protected(earlierBond_);
        bytes32 history_ = keccak256(abi.encode(
            migration.nftSurrender(WEIGHTED, 4), migration.nftSurrender(EARLIER, 4),
            migration.nftCustody(WEIGHTED, 4), migration.nftCustody(EARLIER, 4)
        ));
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedPrincipal, 4, 0, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.EarlierClaim, 4, 0, 0);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        uint256 first_ = _weightedAmount();
        assertEq(first_, 86292556);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 309005608995105);

        // Replacement deliberately disagrees with source units. Recovery must use execution
        // history, not the now-replaced entitlement, and may not create corrective credit.
        Migration.NftEntitlementInput[] memory replacement_ = new Migration.NftEntitlementInput[](2);
        replacement_[0] = _original(WEIGHTED, 4);
        replacement_[1] = _original(EARLIER, 4);
        replacement_[0].originalUnits += 1;
        replacement_[1].originalUnits += 1;
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(replacement_);
        assertTrue(migration.nftEntitlement(WEIGHTED, 4).configurationId
            != migration.nftCustody(WEIGHTED, 4).configurationId);

        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 indexBefore_ = old_.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        // W2 synchronizes AFTER a booked W1: appreciation is held gons, not new native budget.
        uint256 gonsBefore_ = old_.gonsOf(detf);
        _run(Recovery.Stage.WeightedUnstake, 0, first_, 0);
        uint256 indexAfter_ = old_.stakingState().gonsPerUnit;
        assertLt(indexAfter_, indexBefore_);
        assertEq(old_.gonsOf(detf), gonsBefore_ - first_ * indexAfter_);
        assertEq(recovery.migrationRecoveryGons(), old_.gonsOf(detf));
        assertGt(recovery.migrationRecoveryGons(), 0);
        assertEq(_weightedAmount(), 0);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);

        uint256 heldGons_ = recovery.migrationRecoveryGons();
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedClaim, 4, 0, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.EarlierSale, 4, 0, 1);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        uint256 second_ = _weightedAmount();
        assertGt(second_, 0);
        assertEq(recovery.migrationRecoveryGons(), heldGons_ + second_ * old_.stakingState().gonsPerUnit);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF),
            IERC20(Legacy.EARLIER_DETF).balanceOf(detf));
        assertEq(recovery.migrationNftRecovery(EARLIER, 4).rewardsClaimed,
            recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF));
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT),
            IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(detf));
        assertEq(IERC721(EARLIER).ownerOf(4), address(0));
        assertTrue(recovery.migrationNftRecovery(EARLIER, 4).sold);
        _run(Recovery.Stage.WeightedConvert, 0, first_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), IERC20(Legacy.DTF).balanceOf(detf));
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        assertEq(_protected(weightedBond_), protectedWeighted_);
        assertEq(_protected(earlierBond_), protectedEarlier_);
        assertEq(keccak256(abi.encode(
            migration.nftSurrender(WEIGHTED, 4), migration.nftSurrender(EARLIER, 4),
            migration.nftCustody(WEIGHTED, 4), migration.nftCustody(EARLIER, 4)
        )), history_);
        emit VerifiedRecoverySequence(detf, first_, second_, heldGons_,
            recovery.migrationRecoveryInventory(Legacy.DTF),
            recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT));
    }
}

contract RecoverySequenceWitnessRunner is Script {
    function run() external {
        RecoverySequenceWitness witness_ = new RecoverySequenceWitness();
        vm.allowCheatcodes(address(witness_));
        witness_.setUp();
        witness_.run();
    }
}
