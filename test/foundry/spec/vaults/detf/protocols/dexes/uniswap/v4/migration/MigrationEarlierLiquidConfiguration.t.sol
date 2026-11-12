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

/// @notice ED original records are synthetic; real-source custody is covered in the pinned forks.
contract MigrationEarlierLiquidConfigurationTest is TestBase_UniswapV4DetfMigration {
    bytes32 constant ORIGIN = keccak256("synthetic original ED native18");

    function setUp() public override { vm.chainId(4663); super.setUp(); _fundAndCapture(); }

    function _input(bytes32 origin_) private view returns (Migration.EarlierLiquidEntitlementInput[] memory a_) {
        a_ = new Migration.EarlierLiquidEntitlementInput[](1);
        a_[0] = Migration.EarlierLiquidEntitlementInput(
            origin_, address(this), Legacy.EARLIER_DETF, 2e18, 1 ether, 0, bytes32("original allocation"), true
        );
    }

    function test_completeReplacementReplayAndFrozenOriginalGroupingNeverIssue() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.startPrank(migrationOwner);
        allocation.configureEarlierLiquidEntitlements(a_);
        a_[0].originalUnits = 1e18;
        a_[0].originalEth = 0.6 ether;
        a_[0].originalDtf = 0.1 ether;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureEarlierLiquidEntitlements(a_);
        allocation.configureEarlierLiquidEntitlements(a_);
        vm.stopPrank();
        Migration.EarlierLiquidEntitlement memory c_ = migration.earlierLiquidEntitlement(ORIGIN);
        assertEq(c_.original.originalUnits, 1e18);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, migration.previewOriginalCredit(0.6 ether, 0.1 ether));
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
        Migration.EarlierLiquidSurrender memory s_ = migration.earlierLiquidSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 1e18);
        assertEq(s_.remainingCredit, c_.credit);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function test_invalidFieldsSourceChainAndOwnerRejectWholeBatch() public {
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureEarlierLiquidEntitlements(a_);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _input(ORIGIN);
            if (i_ == 0) a_[0].originalId = bytes32(0);
            else if (i_ == 1) a_[0].originalWallet = address(0);
            else if (i_ == 2) a_[0].originalUnits = 0;
            else if (i_ == 3) a_[0].contributionsKnown = false;
            else a_[0].evidenceId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidEntitlement.selector, a_[0].originalId));
            allocation.configureEarlierLiquidEntitlements(a_);
        }
        a_ = _input(ORIGIN);
        a_[0].source = Legacy.WEIGHTED_RECEIPT;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedEarlierLiquidSource.selector, 4663, a_[0].source));
        allocation.configureEarlierLiquidEntitlements(a_);
        a_ = _input(ORIGIN);
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedEarlierLiquidSource.selector, 1, a_[0].source));
        allocation.configureEarlierLiquidEntitlements(a_);
        vm.chainId(4663);
        address next_ = makeAddr("ED next owner");
        vm.prank(migrationOwner); migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureEarlierLiquidEntitlements(a_);
        vm.prank(next_); migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureEarlierLiquidEntitlements(a_);
        vm.prank(next_); allocation.configureEarlierLiquidEntitlements(a_);
        bytes memory before_ = abi.encode(migration.earlierLiquidEntitlement(ORIGIN), migration.earlierLiquidSurrender(ORIGIN));
        Migration.EarlierLiquidEntitlementInput[] memory batch_ = new Migration.EarlierLiquidEntitlementInput[](2);
        batch_[0] = a_[0]; batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0]; batch_[1].originalId = bytes32("bad"); batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidEntitlement.selector, bytes32("bad")));
        allocation.configureEarlierLiquidEntitlements(batch_);
        assertEq(abi.encode(migration.earlierLiquidEntitlement(ORIGIN), migration.earlierLiquidSurrender(ORIGIN)), before_);
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
        bytes4[6] memory selectors_ = [
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureWeightedSyEntitlements.selector,
            Allocation.configureDtfCustodySeEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector, Allocation.configureEarlierReceiptEntitlements.selector
        ];
        address[6] memory sources_ = [
            Legacy.WEIGHTED_DETF, Legacy.WEIGHTED_SY, Legacy.DTF_CUSTODY_SE, Legacy.CLAIM_VAULT, Legacy.WEIGHTED_RECEIPT, Legacy.EARLIER_RECEIPT
        ];
        // These interface-owned original structs share an ABI tuple, not a unit.
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _input(origin_);
        a_[0].source = sources_[category_ - 3];
        vm.prank(migrationOwner);
        (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(selectors_[category_ - 3], a_));
        if (!ok_) assembly { revert(add(reason_, 32), mload(reason_)) }
    }

    function test_allCanonicalOriginsExcludeBothDirectionsAfterWalletCorrection() public {
        for (uint256 category_; category_ < 9; ++category_) {
            for (uint256 direction_; direction_ < 2; ++direction_) {
                uint256 snap_ = vm.snapshotState();
                bytes32 origin_ = category_ == 1 || category_ == 2
                    ? migration.migrationNftOriginalId(category_ == 1
                        ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                        : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391), 3) : ORIGIN;
                Migration.EarlierLiquidEntitlementInput[] memory a_ = _input(origin_);
                if (direction_ == 0) {
                    vm.prank(migrationOwner); allocation.configureEarlierLiquidEntitlements(a_);
                    a_[0].originalWallet = address(0xBEEF);
                    vm.prank(migrationOwner); allocation.configureEarlierLiquidEntitlements(a_);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    _other(category_, origin_);
                } else {
                    _other(category_, origin_);
                    vm.prank(migrationOwner);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    allocation.configureEarlierLiquidEntitlements(a_);
                }
                assertTrue(vm.revertToStateAndDelete(snap_));
            }
        }
        _configure(address(this), 1 ether, ORIGIN); _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureEarlierLiquidEntitlements(_input(ORIGIN));
    }

    function test_paidOwnerBondActivationRemovesLoaderAndRetainsRecordsAndQueries() public {
        vm.prank(migrationOwner); allocation.configureEarlierLiquidEntitlements(_input(ORIGIN));
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp);
        vm.prank(migrationOwner); vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner); allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureEarlierLiquidEntitlements.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationEarlierLiquid.selector), address(0));
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureEarlierLiquidEntitlements, (_input(ORIGIN))));
        assertFalse(ok_);
        assertEq(migration.earlierLiquidSurrender(ORIGIN).remainingUnits, 2e18);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationEarlierLiquid(bytes32("absent"), 1, 0, block.timestamp);
    }
}
