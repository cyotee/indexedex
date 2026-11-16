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

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Synthetic documented original gon allocations; actual source custody belongs to the forks.
contract MigrationWeightedReceiptConfigurationTest is TestBase_UniswapV4DetfMigration {
    bytes32 constant ORIGIN = keccak256("synthetic original eligible WS gons");

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _input(bytes32 origin_) private view returns (Migration.WeightedReceiptEntitlementInput[] memory a_) {
        a_ = new Migration.WeightedReceiptEntitlementInput[](1);
        a_[0] = Migration.WeightedReceiptEntitlementInput(
            origin_, address(this), Legacy.WEIGHTED_RECEIPT, 101e36, 1 ether, 0, bytes32("original allocation"), true
        );
    }

    function test_completeReplacementAndReplayPreserveGroupingAndNeverIssue() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.WeightedReceiptEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.startPrank(migrationOwner);
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        a_[0].originalUnits = 60e36;
        a_[0].originalEth = 0.6 ether;
        a_[0].originalDtf = 0.1 ether;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        vm.stopPrank();
        Migration.WeightedReceiptEntitlement memory c_ = migration.weightedReceiptEntitlement(ORIGIN);
        assertEq(c_.original.originalUnits, 60e36);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, migration.previewOriginalCredit(0.6 ether, 0.1 ether));
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationWeightedPricing().id, a_[0])));
        Migration.WeightedReceiptSurrender memory s_ = migration.weightedReceiptSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 60e36);
        assertEq(s_.remainingCredit, c_.credit);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function test_missingFieldsWrongChainAndCurrentOwnerOnlyRejectAtomically() public {
        Migration.WeightedReceiptEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _input(ORIGIN);
            if (i_ == 0) a_[0].originalId = bytes32(0);
            else if (i_ == 1) a_[0].originalWallet = address(0);
            else if (i_ == 2) a_[0].originalUnits = 0;
            else if (i_ == 3) a_[0].contributionsKnown = false;
            else a_[0].evidenceId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, a_[0].originalId));
            allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        }
        a_ = _input(ORIGIN);
        a_[0].source = Legacy.WEIGHTED_SY;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedReceiptSource.selector, 4663, a_[0].source));
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        a_[0].source = Legacy.WEIGHTED_RECEIPT;
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedReceiptSource.selector, 1, a_[0].source));
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        vm.chainId(4663);
        address next_ = makeAddr("weighted receipt next owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        vm.prank(next_);
        allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        bytes memory before_ = abi.encode(migration.weightedReceiptEntitlement(ORIGIN), migration.weightedReceiptSurrender(ORIGIN));
        Migration.WeightedReceiptEntitlementInput[] memory batch_ = new Migration.WeightedReceiptEntitlementInput[](2);
        batch_[0] = a_[0]; batch_[0].originalUnits = 8e36;
        batch_[1] = a_[0]; batch_[1].originalId = bytes32("bad"); batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, bytes32("bad")));
        allocation.configureWeightedReceiptEntitlements(batch_, pricingId);
        assertEq(abi.encode(migration.weightedReceiptEntitlement(ORIGIN), migration.weightedReceiptSurrender(ORIGIN)), before_);
    }

    function _other(uint256 category_, bytes32 origin_, uint256 nftId_) private {
        if (category_ == 0) {
            _configure(address(this), 1 ether, origin_);
        } else if (category_ < 3) {
            Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
            a_[0] = Migration.NftEntitlementInput(
                category_ == 1 ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                    : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391),
                nftId_, address(this), 3, 1 ether, 0, bytes32("NFT"), true
            );
            vm.prank(migrationOwner);
            allocation.configureNftEntitlements(a_, pricingId);
        } else if (category_ == 3) {
            Migration.WeightedLiquidEntitlementInput[] memory a_ = new Migration.WeightedLiquidEntitlementInput[](1);
            a_[0] = Migration.WeightedLiquidEntitlementInput(origin_, address(this), Legacy.WEIGHTED_DETF, 3, 1 ether, 0, bytes32("WD"), true);
            vm.prank(migrationOwner); allocation.configureWeightedLiquidEntitlements(a_, pricingId);
        } else if (category_ == 4) {
            Migration.WeightedSyEntitlementInput[] memory a_ = new Migration.WeightedSyEntitlementInput[](1);
            a_[0] = Migration.WeightedSyEntitlementInput(origin_, address(this), Legacy.WEIGHTED_SY, 3, 1 ether, 0, bytes32("WY"), true);
            vm.prank(migrationOwner); allocation.configureWeightedSyEntitlements(a_, pricingId);
        } else if (category_ == 5) {
            Migration.DtfCustodySeEntitlementInput[] memory a_ = new Migration.DtfCustodySeEntitlementInput[](1);
            a_[0] = Migration.DtfCustodySeEntitlementInput(origin_, address(this), Legacy.DTF_CUSTODY_SE, 3, 1 ether, 0, bytes32("SE"), true);
            vm.prank(migrationOwner); allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        } else {
            Migration.ClaimVaultEntitlementInput[] memory a_ = new Migration.ClaimVaultEntitlementInput[](1);
            a_[0] = Migration.ClaimVaultEntitlementInput(origin_, address(this), Legacy.CLAIM_VAULT, 3, 1 ether, 0, bytes32("CV"), true);
            vm.prank(migrationOwner); allocation.configureClaimVaultEntitlements(a_, pricingId);
        }
    }

    function test_everyCanonicalOriginExclusionWorksBothDirectionsIncludingWalletCorrections() public {
        for (uint256 category_; category_ < 7; ++category_) {
            for (uint256 direction_; direction_ < 2; ++direction_) {
                uint256 snap_ = vm.snapshotState();
                bytes32 origin_ = ORIGIN;
                if (category_ == 1 || category_ == 2) {
                    origin_ = migration.migrationNftOriginalId(category_ == 1
                        ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                        : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391), 3);
                }
                Migration.WeightedReceiptEntitlementInput[] memory a_ = _input(origin_);
                if (direction_ == 0) {
                    vm.prank(migrationOwner); allocation.configureWeightedReceiptEntitlements(a_, pricingId);
                    a_[0].originalWallet = address(0xBEEF);
                    vm.prank(migrationOwner); allocation.configureWeightedReceiptEntitlements(a_, pricingId);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    _other(category_, origin_, 3);
                } else {
                    _other(category_, origin_, 3);
                    vm.prank(migrationOwner);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    allocation.configureWeightedReceiptEntitlements(a_, pricingId);
                }
                assertTrue(vm.revertToStateAndDelete(snap_));
            }
        }
        _configure(address(this), 1 ether, ORIGIN);
        _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement independent"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedReceiptEntitlements(_input(ORIGIN), pricingId);
    }

    function test_activationPermanentlyRemovesLoaderAndRetainsFrozenRecord() public {
        vm.prank(migrationOwner);
        allocation.configureWeightedReceiptEntitlements(_input(ORIGIN), pricingId);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationWeightedReceipt(ORIGIN, 1, 0, block.timestamp);
        _buyOwnerFirstBond();
        vm.prank(migrationOwner); allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedReceiptEntitlements.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationWeightedReceipt.selector), address(0));
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureWeightedReceiptEntitlements, (_input(ORIGIN), pricingId)));
        assertFalse(ok_);
        assertEq(migration.weightedReceiptSurrender(ORIGIN).remainingUnits, 101e36);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationWeightedReceipt(bytes32("absent"), 1, 0, block.timestamp);
    }

    /// @notice A-prepared rows cannot clear or reprice storage after installing B; explicit B reload replaces only configuration.
    function test_StaleBook_WeightedReceiptReplacementPreservesRecords() public {
        Migration.WeightedReceiptEntitlementInput[] memory a_ = _input(ORIGIN);
        bytes32 old_ = pricingId;
        vm.prank(migrationOwner); allocation.configureWeightedReceiptEntitlements(a_, old_);
        bytes memory record_ = abi.encode(migration.weightedReceiptEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.weightedReceiptSurrender(ORIGIN));
        uint256 supply_ = IERC20(detf).totalSupply();
        Pricing.Inputs memory next_ = migration.migrationWeightedPricing().inputs;
        next_.swapFeeWad = 1e17;
        vm.prank(migrationOwner); pricingId = allocation.setMigrationWeightedPricing(next_);
        assertEq(abi.encode(migration.weightedReceiptEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.weightedReceiptSurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, old_, pricingId));
        allocation.configureWeightedReceiptEntitlements(a_, old_);
        assertEq(abi.encode(migration.weightedReceiptEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.weightedReceiptSurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner); allocation.configureWeightedReceiptEntitlements(a_, pricingId);
        assertEq(migration.weightedReceiptEntitlement(ORIGIN).configurationId, keccak256(abi.encode(block.chainid, detf, pricingId, a_[0])));
        assertNotEq(abi.encode(migration.weightedReceiptEntitlement(ORIGIN)), record_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }
}
