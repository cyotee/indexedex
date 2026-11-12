// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice ER original records are synthetic; real-source custody is covered in the pinned forks.
contract MigrationEarlierReceiptConfigurationTest is TestBase_UniswapV4DetfMigration {
    bytes32 constant ORIGIN = keccak256("synthetic original ER internal shares");

    function setUp() public override { vm.chainId(4663); super.setUp(); _fundAndCapture(); }

    function _input(bytes32 origin_) private view returns (Migration.EarlierReceiptEntitlementInput[] memory a_) {
        a_ = new Migration.EarlierReceiptEntitlementInput[](1);
        a_[0] = Migration.EarlierReceiptEntitlementInput(
            origin_, address(this), Legacy.EARLIER_RECEIPT, 2e27, 1 ether, 0, bytes32("original allocation"), true
        );
    }

    function test_completeReplacementReplayAndFrozenOriginalGroupingNeverIssue() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.EarlierReceiptEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.startPrank(migrationOwner);
        allocation.configureEarlierReceiptEntitlements(a_);
        a_[0].originalUnits = 1e27;
        a_[0].originalEth = 0.6 ether;
        a_[0].originalDtf = 0.1 ether;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureEarlierReceiptEntitlements(a_);
        allocation.configureEarlierReceiptEntitlements(a_);
        vm.stopPrank();
        Migration.EarlierReceiptEntitlement memory c_ = migration.earlierReceiptEntitlement(ORIGIN);
        assertEq(c_.original.originalUnits, 1e27);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, migration.previewOriginalCredit(0.6 ether, 0.1 ether));
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
        Migration.EarlierReceiptSurrender memory s_ = migration.earlierReceiptSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 1e27);
        assertEq(s_.remainingCredit, c_.credit);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function test_invalidFieldsSourceChainAndOwnerRejectWholeBatch() public {
        Migration.EarlierReceiptEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureEarlierReceiptEntitlements(a_);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _input(ORIGIN);
            if (i_ == 0) a_[0].originalId = bytes32(0);
            else if (i_ == 1) a_[0].originalWallet = address(0);
            else if (i_ == 2) a_[0].originalUnits = 0;
            else if (i_ == 3) a_[0].contributionsKnown = false;
            else a_[0].evidenceId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierReceiptEntitlement.selector, a_[0].originalId));
            allocation.configureEarlierReceiptEntitlements(a_);
        }
        a_ = _input(ORIGIN);
        a_[0].source = Legacy.WEIGHTED_RECEIPT;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedEarlierReceiptSource.selector, 4663, a_[0].source));
        allocation.configureEarlierReceiptEntitlements(a_);
        a_ = _input(ORIGIN);
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedEarlierReceiptSource.selector, 1, a_[0].source));
        allocation.configureEarlierReceiptEntitlements(a_);
        vm.chainId(4663);
        address next_ = makeAddr("ER next owner");
        vm.prank(migrationOwner); migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureEarlierReceiptEntitlements(a_);
        vm.prank(next_); migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureEarlierReceiptEntitlements(a_);
        vm.prank(next_); allocation.configureEarlierReceiptEntitlements(a_);
        bytes memory before_ = abi.encode(migration.earlierReceiptEntitlement(ORIGIN), migration.earlierReceiptSurrender(ORIGIN));
        Migration.EarlierReceiptEntitlementInput[] memory batch_ = new Migration.EarlierReceiptEntitlementInput[](2);
        batch_[0] = a_[0]; batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0]; batch_[1].originalId = bytes32("bad"); batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierReceiptEntitlement.selector, bytes32("bad")));
        allocation.configureEarlierReceiptEntitlements(batch_);
        assertEq(abi.encode(migration.earlierReceiptEntitlement(ORIGIN), migration.earlierReceiptSurrender(ORIGIN)), before_);
    }

    function _other(uint256 category_, bytes32 origin_) private {
        if (category_ == 0) { _configure(address(this), 1 ether, origin_); return; }
        if (category_ < 3) {
            Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
            n_[0] = Migration.NftEntitlementInput(
                category_ == 1 ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                    : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391),
                3, address(this), 3, 1 ether, 0, bytes32("NFT"), true
            );
            vm.prank(migrationOwner); allocation.configureNftEntitlements(n_); return;
        }
        bytes4[5] memory selectors_ = [
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureWeightedSyEntitlements.selector,
            Allocation.configureDtfCustodySeEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector
        ];
        address[5] memory sources_ = [
            Legacy.WEIGHTED_DETF, Legacy.WEIGHTED_SY, Legacy.DTF_CUSTODY_SE, Legacy.CLAIM_VAULT, Legacy.WEIGHTED_RECEIPT
        ];
        // These interface-owned original structs share an ABI tuple, not a unit.
        Migration.EarlierReceiptEntitlementInput[] memory a_ = _input(origin_);
        a_[0].source = sources_[category_ - 3];
        vm.prank(migrationOwner);
        (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(selectors_[category_ - 3], a_));
        if (!ok_) assembly { revert(add(reason_, 32), mload(reason_)) }
    }

    function test_allCanonicalOriginsExcludeBothDirectionsAfterWalletCorrection() public {
        for (uint256 category_; category_ < 8; ++category_) {
            for (uint256 direction_; direction_ < 2; ++direction_) {
                uint256 snap_ = vm.snapshotState();
                bytes32 origin_ = category_ == 1 || category_ == 2
                    ? migration.migrationNftOriginalId(category_ == 1
                        ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                        : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391), 3) : ORIGIN;
                Migration.EarlierReceiptEntitlementInput[] memory a_ = _input(origin_);
                if (direction_ == 0) {
                    vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(a_);
                    a_[0].originalWallet = address(0xBEEF);
                    vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(a_);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    _other(category_, origin_);
                } else {
                    _other(category_, origin_);
                    vm.prank(migrationOwner);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    allocation.configureEarlierReceiptEntitlements(a_);
                }
                assertTrue(vm.revertToStateAndDelete(snap_));
            }
        }
        _configure(address(this), 1 ether, ORIGIN); _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureEarlierReceiptEntitlements(_input(ORIGIN));
    }

    function test_paidOwnerBondActivationRemovesLoaderAndRetainsRecordsAndQueries() public {
        vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(_input(ORIGIN));
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp);
        vm.prank(migrationOwner); vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner); allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureEarlierReceiptEntitlements.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationEarlierReceipt.selector), address(0));
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureEarlierReceiptEntitlements, (_input(ORIGIN))));
        assertFalse(ok_);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingUnits, 2e27);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierReceiptEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationEarlierReceipt(bytes32("absent"), 1, 0, block.timestamp);
    }
}
