// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationWeightedReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice A later selected failure reverts revaluation, source debit, conversion and donation.
contract MigrationRecoveryAccrualRollbackTest is MigrationRecoveryDonationForkBase {
    function test_laterSelectedFailureRevertsAccrualAndDonationButPreservesCommittedClaim() public {
        uint256 bond_ = _take(WEIGHTED, 4);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        uint256 original_ = _weightedAmount();
        uint256 gons_ = recovery.migrationRecoveryGons();
        bytes32 claimed_ = keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4)));
        bytes32 protected_ = _protected(bond_);
        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        bytes32 sourceState_ = keccak256(abi.encode(old_.stakingState()));
        uint256 dtf_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 lp_ = IERC20(reserveHook).balanceOf(address(bonds));
        vm.warp(vm.getBlockTimestamp() + 8 hours);

        Recovery.Step[] memory steps_ = new Recovery.Step[](4);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedUnstake, 0, original_, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.WeightedConvert, 0, original_, 1);
        steps_[2] = Recovery.Step(Recovery.Stage.Donate, 0, 1 ether, 1);
        steps_[3] = Recovery.Step(Recovery.Stage.WeightedClaim, 26, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 26));
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(_weightedAmount(), original_);
        assertEq(recovery.migrationRecoveryGons(), gons_);
        assertEq(old_.gonsOf(detf), gons_);
        assertEq(keccak256(abi.encode(old_.stakingState())), sourceState_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), dtf_);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)), lp_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        assertEq(IERC20(Legacy.DTF).allowance(detf, reserveHook), 0);
        assertEq(IERC20(Legacy.DTF).allowance(detf, se1), 0);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4))), claimed_);
        assertEq(_protected(bond_), protected_);
        assertEq(IERC721(WEIGHTED).ownerOf(4), detf);

        Recovery.Step[] memory retry_ = new Recovery.Step[](3);
        for (uint256 i_; i_ < retry_.length; ++i_) retry_[i_] = steps_[i_];
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(retry_, block.timestamp);
        uint256 k_ = old_.stakingState().gonsPerUnit;
        assertGt(gons_ / k_, original_);
        assertEq(_weightedAmount(), gons_ / k_ - original_);
        assertEq(recovery.migrationRecoveryGons(), gons_ - original_ * k_);
        assertEq(old_.gonsOf(detf), recovery.migrationRecoveryGons());
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), lp_);
        assertGt(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(keccak256(abi.encode(recovery.migrationNftRecovery(WEIGHTED, 4))), claimed_);
        assertEq(_protected(bond_), protected_);
    }
}
