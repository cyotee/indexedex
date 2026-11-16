// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {MigrationDtfCustodySeForkBase, IDtfCustodySeAcquisition} from "./MigrationDtfCustodySeForkBase.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Controlled acquiring contract wallet, not a replacement source or subject.
contract DtfCustodySeReceiver is IERC721Receiver {
    Migration immutable parent;
    bytes32 immutable origin;
    bool public rejectBond;
    bool public surrenderReentered;
    bool public activationReentered;
    constructor(Migration parent_, bytes32 origin_) { parent = parent_; origin = origin_; }
    function acquire(uint256 assets_) external returns (uint256) {
        IERC20(Legacy.DTF).approve(Legacy.DTF_CUSTODY_SE, assets_);
        return IDtfCustodySeAcquisition(Legacy.DTF_CUSTODY_SE).deposit(assets_, address(this));
    }
    function reject(bool value_) external { rejectBond = value_; }
    function acceptOwnership() external { parent.acceptOwnershipTransfer(); }
    function surrender(uint256 q_) external returns (uint256, uint256) {
        IERC20(Legacy.DTF_CUSTODY_SE).approve(address(parent), q_);
        return parent.surrenderMigrationDtfCustodySe(origin, q_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (surrenderReentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationDtfCustodySe, (origin, 1, 0, block.timestamp)
        ));
        (activationReentered,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

contract MigrationDtfCustodySeTest is MigrationDtfCustodySeForkBase {
    function test_actualPartialFinalSharesConserveFrozenCreditAndFreshFunding() public {
        uint256 q0_ = acquiredShares - 7;
        uint256 c0_ = _configureSe(seHolder, q0_);
        _activate();
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 start_ = vm.getBlockTimestamp();
        uint256 q1_ = q0_ / 3;
        (uint256 first_, uint256 c1_) = _surrenderSe(q1_);
        assertEq(c1_, c0_ * q1_ / q0_);
        Migration.DtfCustodySeSurrender memory s_ = migration.dtfCustodySeSurrender(SE_ORIGIN);
        assertEq(s_.remainingUnits, q0_ - q1_);
        assertEq(s_.remainingCredit, c0_ - c1_);
        assertEq(s_.consumedUnits, q1_);
        vm.warp(start_ + 30 days);
        uint256 expansion_ = migration.synchronizeRewards();
        (uint256 final_, uint256 c2_) = _surrenderSe(q0_ - q1_);
        assertEq(c1_ + c2_, c0_);
        assertNotEq(first_, final_);
        assertEq(bonds.positionOf(first_).startTimestamp, start_);
        assertEq(bonds.positionOf(final_).startTimestamp, start_ + 30 days);
        assertEq(migration.dtfCustodySeEntitlement(SE_ORIGIN).credit, c0_);
        s_ = migration.dtfCustodySeSurrender(SE_ORIGIN);
        assertEq(s_.remainingUnits, 0);
        assertEq(s_.remainingCredit, 0);
        assertEq(s_.consumedUnits, q0_);
        assertEq(s_.deliveredCredit, c0_);
        assertEq(IERC20(detf).totalSupply(), supply_ + c0_ + expansion_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + c0_ + expansion_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), 7);
        vm.prank(seHolder);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeQuantity.selector, 1, 0));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, 1, 0, block.timestamp);
    }

    function test_stageOneRejectsConfiguredAndMissingBeforeAnyMovement() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(seHolder);
        IERC20(Legacy.DTF_CUSTODY_SE).approve(detf, acquiredShares);
        for (uint256 i_; i_ < 2; ++i_) {
            if (i_ == 1) _configureSe(seHolder, acquiredShares);
            bytes memory before_ = abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN));
            vm.prank(seHolder);
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, acquiredShares, 0, block.timestamp);
            assertEq(abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN)), before_);
            assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), acquiredShares);
            assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), 0);
            assertEq(IERC20(Legacy.DTF_CUSTODY_SE).allowance(seHolder, detf), acquiredShares);
            assertEq(IERC20(detf).totalSupply(), supply_);
            assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
            assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), 0);
        }
        _activate();
        _surrenderSe(acquiredShares);
    }

    function test_walletTransferReturnAndRemovedLoaderPreserveRemainingRecord() public {
        _configureSe(seHolder, acquiredShares);
        _activate();
        vm.prank(seHolder);
        IERC20(Legacy.DTF_CUSTODY_SE).transfer(address(this), acquiredShares);
        IERC20(Legacy.DTF_CUSTODY_SE).approve(detf, acquiredShares);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalDtfCustodySeWallet.selector, address(this), seHolder));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, acquiredShares, 0, block.timestamp);
        IERC20(Legacy.DTF_CUSTODY_SE).transfer(seHolder, acquiredShares);
        _surrenderSe(acquiredShares / 2);
        bytes memory before_ = abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureDtfCustodySeEntitlements.selector), address(0));
        Migration.DtfCustodySeEntitlementInput[] memory inputs_ = _seInputs(seHolder, acquiredShares);
        for (uint256 i_; i_ < 2; ++i_) {
            if (i_ == 1) { inputs_[0].originalWallet = address(this); inputs_[0].originalDtf = 1 ether; }
            vm.prank(migrationOwner);
            (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureDtfCustodySeEntitlements, (inputs_, pricingId)));
            assertFalse(ok_);
        }
        assertEq(abi.encode(migration.dtfCustodySeSurrender(SE_ORIGIN)), before_);
        _surrenderSe(acquiredShares - acquiredShares / 2);
    }

    function test_badAmountMinimumDeadlineApprovalAndBalanceRollback() public {
        uint256 c0_ = _configureSe(seHolder, acquiredShares);
        Migration.DtfCustodySeEntitlementInput[] memory inputs_ = _seInputs(seHolder, acquiredShares + 1);
        inputs_[0].originalId = bytes32("too much");
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(inputs_, pricingId);
        _activate();
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(seHolder);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationDtfCustodySe(bytes32("absent"), 1, 0, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeQuantity.selector, 0, acquiredShares));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, 0, 0, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeQuantity.selector, acquiredShares + 1, acquiredShares));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, acquiredShares + 1, 0, block.timestamp);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, acquiredShares, 0, block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", c0_ + 1, c0_));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, acquiredShares, c0_ + 1, block.timestamp);
        vm.expectCall(Legacy.DTF_CUSTODY_SE, abi.encodeCall(IERC20.transferFrom, (seHolder, detf, acquiredShares)));
        (bool allowance_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationDtfCustodySe,
            (SE_ORIGIN, acquiredShares, 0, block.timestamp)));
        assertFalse(allowance_);
        IERC20(Legacy.DTF_CUSTODY_SE).approve(detf, type(uint256).max);
        vm.expectCall(Legacy.DTF_CUSTODY_SE, abi.encodeCall(IERC20.transferFrom, (seHolder, detf, acquiredShares + 1)));
        (bool balance_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationDtfCustodySe,
            (bytes32("too much"), acquiredShares + 1, 0, block.timestamp)));
        assertFalse(balance_);
        vm.stopPrank();
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), acquiredShares);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), 0);
        assertEq(migration.dtfCustodySeSurrender(SE_ORIGIN).remainingCredit, c0_);
        assertEq(migration.dtfCustodySeSurrender(bytes32("too much")).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
    }

    function test_zeroCreditNativeShareDustCannotBeConfiscated() public {
        _configureSe(seHolder, acquiredShares);
        _activate();
        vm.prank(seHolder);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeEntitlement.selector, SE_ORIGIN));
        migration.surrenderMigrationDtfCustodySe(SE_ORIGIN, 1, 0, block.timestamp);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(seHolder), acquiredShares);
        assertEq(migration.dtfCustodySeSurrender(SE_ORIGIN).consumedUnits, 0);
    }

    function test_actualContractAcquisitionAndRejectedBondRollBackPullFundingAndCallback() public {
        DtfCustodySeReceiver wallet_ = new DtfCustodySeReceiver(migration, SE_ORIGIN);
        IERC20(Legacy.DTF).transfer(address(wallet_), 1 ether);
        uint256 q_ = wallet_.acquire(1 ether);
        assertEq(IERC20(Legacy.DTF).balanceOf(address(wallet_)), 0);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(address(wallet_)), q_);
        uint256 c0_ = _configureSe(address(wallet_), q_);
        _activate();
        wallet_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(address(wallet_)), q_);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).balanceOf(detf), 0);
        assertEq(IERC20(Legacy.DTF_CUSTODY_SE).allowance(address(wallet_), detf), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF_CUSTODY_SE), 0);
        assertEq(migration.dtfCustodySeSurrender(SE_ORIGIN).deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        wallet_.reject(false);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(wallet_));
        wallet_.acceptOwnership();
        (uint256 id_, uint256 delivered_) = wallet_.surrender(q_);
        assertEq(delivered_, c0_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(wallet_));
        assertFalse(wallet_.surrenderReentered());
        assertFalse(wallet_.activationReentered());
    }
}
