// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
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

/// @notice Reproduces an acceptance failure, not a passing harvestability contract.
/// @dev No Migration/source impersonation, storage injection, policy change or SUT mutation.
contract RecoveryAccrualWitness is MigrationRecoveryForkBase {
    event RecoveryGrowthStranded(
        address parent, uint256 originalClaim, uint256 gons, uint256 divisor,
        uint256 redeemableNative, uint256 nativeBudget, uint256 controlGrowthRedeemed
    );

    function run() external {
        uint256 bond_ = _take(WEIGHTED, 3);
        bytes32 protected_ = _protected(bond_);
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        uint256 original_ = _weightedAmount();
        assertEq(original_, 4308806205);
        assertEq(IERC721(WEIGHTED).ownerOf(3), address(0));

        // A separate genuine source holder supplies the ordinary direct-unstake control.
        address holder_ = IERC721(WEIGHTED).ownerOf(4);
        vm.prank(holder_);
        (uint256 principal_, uint256 rewards_) =
            IMigrationWeightedClaims(WEIGHTED).claimBond(4, holder_);
        uint256 controlBefore_ = IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(holder_);
        assertGe(controlBefore_, principal_ + rewards_);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        _run(Recovery.Stage.WeightedUnstake, 0, original_, 0);

        IMigrationWeightedReceipt old_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT);
        uint256 gons_ = old_.gonsOf(detf);
        uint256 divisor_ = old_.stakingState().gonsPerUnit;
        uint256 redeemable_ = IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(detf);
        assertEq(gons_, recovery.migrationRecoveryGons());
        assertGt(redeemable_, 1);
        assertEq(redeemable_, gons_ / divisor_);
        assertEq(_weightedAmount(), 0);
        // The entire balance is attributed; a one-unit debit would preserve unbooked gons (zero).
        assertLe(divisor_, gons_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_RECEIPT, 1, 0
        ));
        _run(Recovery.Stage.WeightedUnstake, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, WEIGHTED, 3));
        _run(Recovery.Stage.WeightedClaim, 3, 0, 0);
        assertEq(old_.gonsOf(detf), gons_);
        assertEq(_protected(bond_), protected_);

        uint256 controlNow_ = IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(holder_);
        assertGt(controlNow_, controlBefore_);
        uint256 wdBefore_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(holder_);
        vm.prank(holder_);
        uint256 paid_ = old_.exchangeIn(
            Legacy.WEIGHTED_RECEIPT, controlNow_, Legacy.WEIGHTED_DETF,
            controlNow_, holder_, false, block.timestamp
        );
        assertEq(paid_, controlNow_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(holder_) - wdBefore_, controlNow_);
        assertEq(old_.gonsOf(holder_), 0);
        emit RecoveryGrowthStranded(detf, original_, gons_, divisor_, redeemable_,
            _weightedAmount(), controlNow_ - controlBefore_);
    }
}

contract RecoveryAccrualWitnessRunner is Script {
    function run() external {
        RecoveryAccrualWitness witness_ = new RecoveryAccrualWitness();
        vm.allowCheatcodes(address(witness_));
        witness_.setUp();
        witness_.run();
    }
}
