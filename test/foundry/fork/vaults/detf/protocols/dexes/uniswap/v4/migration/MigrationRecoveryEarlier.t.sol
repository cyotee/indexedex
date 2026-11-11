// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
import {IMigrationEarlierClaims, IMigrationEarlierSale, IMigrationEarlierReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {IEarlierParent} from "./MigrationNftForkBase.sol";
import {MigrationRecoveryForkBase} from "./MigrationRecoveryForkBase.sol";

/// @notice Earlier claim/holding and optional mature sale are independent of disabled liquidation.
contract MigrationRecoveryEarlierTest is MigrationRecoveryForkBase {
    function test_lockedEarlierClaimRepeatsAndRecoversGenuineNewAccrual() public {
        uint256 bond_ = _take(EARLIER, 3);
        bytes32 protected_ = _protected(bond_);
        IMigrationEarlierNft.Position memory position_ = IMigrationEarlierNft(EARLIER).getPosition(3);
        assertGt(position_.unlockTime, block.timestamp);
        uint256 start_ = gasleft();
        _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
        emit RecoveryGas("ER1", 1, 1, start_ - gasleft());
        uint256 first_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
        assertEq(first_, 124873542679524901);
        _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), first_);
        // A real unrelated holder contributes actually claimed old rewards to the source.
        address donor_ = IERC721(EARLIER).ownerOf(12);
        vm.startPrank(donor_);
        uint256 received_ = IMigrationEarlierClaims(EARLIER).claimRewards(12, donor_);
        IERC20(Legacy.EARLIER_DETF).transfer(EARLIER, received_);
        vm.stopPrank();
        assertGt(received_, 0);
        _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
        uint256 next_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
        assertGt(next_, first_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), next_);
        assertEq(IMigrationEarlierNft(EARLIER).getPosition(3).originalShares, position_.originalShares);
        assertEq(IERC721(EARLIER).ownerOf(3), detf);
        assertEq(_protected(bond_), protected_);
    }

    function test_matureSaleMeasuresExternalSharesAndNeverRecountsPriorHoldings() public {
        uint256 bond_ = _take(EARLIER, 4);
        bytes32 protected_ = _protected(bond_);
        // Genuine unrelated holder sells another source NFT to this fixed custody address.
        address donor_ = IERC721(EARLIER).ownerOf(12);
        vm.prank(donor_);
        IMigrationEarlierSale(Legacy.EARLIER_DETF).sellPositionToDetfNft(12, detf);
        uint256 shares0_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(detf);
        uint256 rewards0_ = IERC20(Legacy.EARLIER_DETF).balanceOf(detf);
        uint256 lp0_ = IERC20(0x923877336b14662cFb5B3A60b14e7d716d54A888).balanceOf(EARLIER);
        uint256 start_ = gasleft();
        _run(Recovery.Stage.EarlierSale, 4, 0, 1);
        emit RecoveryGas("ER2", 1, 1, start_ - gasleft());
        uint256 shares_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(detf) - shares0_;
        uint256 rewards_ = IERC20(Legacy.EARLIER_DETF).balanceOf(detf) - rewards0_;
        assertGt(shares_, 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT), shares_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), rewards_);
        Recovery.NftRecovery memory record_ = recovery.migrationNftRecovery(EARLIER, 4);
        assertTrue(record_.sold);
        assertEq(record_.receiptShares, shares_);
        assertEq(record_.rewardsClaimed, rewards_);
        assertEq(IERC721(EARLIER).ownerOf(4), address(0));
        IMigrationEarlierNft.Position memory empty_;
        assertEq(abi.encode(IMigrationEarlierNft(EARLIER).getPosition(4)), abi.encode(empty_));
        assertEq(IERC20(0x923877336b14662cFb5B3A60b14e7d716d54A888).balanceOf(EARLIER), lp0_);
        assertEq(_protected(bond_), protected_);
        assertTrue(migration.nftSurrender(EARLIER, 4).consumed);
        vm.expectRevert(abi.encodeWithSelector(Recovery.InvalidRecoveryCustody.selector, EARLIER, 4));
        _run(Recovery.Stage.EarlierSale, 4, 0, 1);
    }

    function test_middleLockedSaleRollsBackEarlierClaimAndPermitsSmallerRetry() public {
        _take(EARLIER, 4);
        _take(EARLIER, 3);
        bytes32 before_ = keccak256(abi.encode(IMigrationEarlierNft(EARLIER).getPosition(4)));
        Recovery.Step[] memory steps_ = new Recovery.Step[](3);
        steps_[0] = Recovery.Step(Recovery.Stage.EarlierClaim, 4, 0, 0);
        steps_[1] = Recovery.Step(Recovery.Stage.EarlierSale, 3, 0, 1);
        steps_[2] = Recovery.Step(Recovery.Stage.EarlierSale, 4, 0, 1);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryPositionLocked.selector, 3, IMigrationEarlierNft(EARLIER).getPosition(3).unlockTime
        ));
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(keccak256(abi.encode(IMigrationEarlierNft(EARLIER).getPosition(4))), before_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 0);
        _run(Recovery.Stage.EarlierClaim, 4, 0, 0);
        uint256 committed_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
        assertEq(committed_, 309005608995105);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryDeltaMismatch.selector, Legacy.EARLIER_RECEIPT));
        _run(Recovery.Stage.EarlierSale, 4, 0, type(uint256).max);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), committed_);
        assertEq(IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).sharesOf(detf), 0);
        assertEq(IERC721(EARLIER).ownerOf(4), detf);
        _run(Recovery.Stage.EarlierSale, 4, 0, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), committed_);
        assertTrue(recovery.migrationNftRecovery(EARLIER, 4).sold);
    }

    function test_earlierClaimAndSaleRemainAvailableAfterActivation() public {
        uint256 bond_ = _take(EARLIER, 4);
        bytes32 before_ = _protected(bond_);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        _run(Recovery.Stage.EarlierClaim, 4, 0, 0);
        _run(Recovery.Stage.EarlierSale, 4, 0, 1);
        assertEq(_protected(bond_), before_);
        assertTrue(recovery.migrationNftRecovery(EARLIER, 4).sold);
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(detf, Legacy.EARLIER_DETF), 0);
        assertEq(IERC20(Legacy.EARLIER_RECEIPT).allowance(detf, Legacy.EARLIER_DETF), 0);
    }

    function test_externalWrongOwnerCloseRemainsDisabledAndCannotEraseCommittedClaim() public {
        uint256 bond_ = _take(EARLIER, 4);
        _run(Recovery.Stage.EarlierClaim, 4, 0, 0);
        bytes32 protected_ = _protected(bond_);
        uint256 rewards_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", 0xb7D4Bb379D361AD442CddEE53eA71a33957826A7));
        IEarlierParent(EARLIER_PARENT).closeBondMature(4, new uint256[](2), address(this), block.timestamp);
        assertEq(IERC721(EARLIER).ownerOf(4), detf);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), rewards_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), rewards_);
        assertEq(_protected(bond_), protected_);
        // This is a disabled dependency, not proof of a safe legacy ownership check.
    }
}
