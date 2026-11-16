// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Synthetic original allocations; actual SE custody is tested against pinned legacy bytecode.
contract MigrationDtfCustodySeConfigurationTest is TestBase_UniswapV4DetfMigration {
    address constant SE = 0x2E9C1F705aB967c5Af59249203d7495bDabb223b;
    address constant NFT = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    bytes32 constant ORIGIN = bytes32("synthetic W-SD original");

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _inputs() private view returns (Migration.DtfCustodySeEntitlementInput[] memory a_) {
        a_ = new Migration.DtfCustodySeEntitlementInput[](1);
        a_[0] = Migration.DtfCustodySeEntitlementInput(
            ORIGIN, address(this), SE, 3e28, 1 ether, 0, bytes32("synthetic original inputs"), true
        );
    }

    function test_unconsumedReplacementFreezesQuoteAndMintsNothing() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.DtfCustodySeEntitlementInput[] memory a_ = _inputs();
        a_[0].originalUnits = 5e28;
        vm.startPrank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        a_[0].originalEth = 0.6 ether;
        a_[0].originalUnits = 3e28;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        vm.stopPrank();
        Migration.DtfCustodySeEntitlement memory c_ = migration.dtfCustodySeEntitlement(ORIGIN);
        uint256 credit_ = migration.previewOriginalCredit(0.6 ether, 0);
        assertTrue(c_.configured);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, credit_);
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationWeightedPricing().id, a_[0])));
        assertEq(migration.previewDtfCustodySeSurrender(ORIGIN, 1e28), credit_ / 3);
        assertEq(migration.previewDtfCustodySeSurrender(ORIGIN, 3e28), credit_);
        Migration.DtfCustodySeSurrender memory s_ = migration.dtfCustodySeSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 3e28);
        assertEq(s_.remainingCredit, credit_);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        vm.warp(block.timestamp + 1 days);
        assertEq(migration.previewDtfCustodySeSurrender(ORIGIN, 3e28), credit_);
    }

    function test_missingOriginalInputsAndWrongAuthorityRejectAtomically() public {
        Migration.DtfCustodySeEntitlementInput[] memory a_ = _inputs();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _inputs();
            if (i_ == 0) a_[0].originalWallet = address(0);
            else if (i_ == 1) a_[0].originalUnits = 0;
            else if (i_ == 2) a_[0].contributionsKnown = false;
            else if (i_ == 3) a_[0].evidenceId = bytes32(0);
            else a_[0].originalId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeEntitlement.selector, a_[0].originalId));
            allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        }
        assertFalse(migration.dtfCustodySeEntitlement(ORIGIN).configured);
        a_ = _inputs();
        a_[0].source = address(0xBAD);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedDtfCustodySeSource.selector, 4663, address(0xBAD)));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        a_[0].source = SE;
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedDtfCustodySeSource.selector, 1, SE));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
    }

    function test_currentOwnerAndBadSecondRowPreserveCompleteConfiguration() public {
        Migration.DtfCustodySeEntitlementInput[] memory a_ = _inputs();
        address next_ = makeAddr("next weighted owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        vm.prank(next_);
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        bytes memory before_ = abi.encode(migration.dtfCustodySeEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.dtfCustodySeSurrender(ORIGIN));
        Migration.DtfCustodySeEntitlementInput[] memory batch_ = new Migration.DtfCustodySeEntitlementInput[](2);
        batch_[0] = a_[0];
        batch_[0].originalUnits = 8e28;
        batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0];
        batch_[1].originalId = bytes32("bad second");
        batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeEntitlement.selector, batch_[1].originalId));
        allocation.configureDtfCustodySeEntitlements(batch_, pricingId);
        assertEq(abi.encode(migration.dtfCustodySeEntitlement(ORIGIN)), before_);
        assertEq(abi.encode(migration.dtfCustodySeSurrender(ORIGIN)), remaining_);
        assertFalse(migration.dtfCustodySeEntitlement(batch_[1].originalId).configured);
    }

    function test_sameCanonicalOriginCannotBeNftOrIndependentInEitherDirection() public {
        Migration.DtfCustodySeEntitlementInput[] memory a_ = _inputs();
        a_[0].originalId = migration.migrationNftOriginalId(NFT, 3);
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        _configure(address(this), 1 ether, a_[0].originalId);
        Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
        n_[0] = Migration.NftEntitlementInput(NFT, 3, address(this), 1, 1 ether, 0, bytes32("fixture"), true);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        allocation.configureNftEntitlements(n_, pricingId);
        n_[0].tokenId = 4;
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(n_, pricingId);
        a_[0].originalId = migration.migrationNftOriginalId(NFT, 4);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        _configure(address(this), 1 ether, ORIGIN);
        _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        a_[0].originalId = ORIGIN;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureDtfCustodySeEntitlements(a_, pricingId);
    }

    function test_activationRemovesNewLoadingAndRetainsExplicitMissingRecordRejection() public {
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(_inputs(), pricingId);
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureDtfCustodySeEntitlements.selector), address(0));
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationDtfCustodySe.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.dtfCustodySeEntitlement.selector), address(0));
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureDtfCustodySeEntitlements, (_inputs(), pricingId)));
        assertFalse(ok_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidDtfCustodySeEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationDtfCustodySe(bytes32("absent"), 1, 0, block.timestamp);
        assertTrue(migration.dtfCustodySeEntitlement(ORIGIN).configured);
        assertEq(migration.dtfCustodySeSurrender(ORIGIN).consumedUnits, 0);
    }

    function test_canonicalCollisionWithWdAndEarlierNftSurvivesWalletCorrection() public {
        Migration.DtfCustodySeEntitlementInput[] memory y_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(y_, pricingId);
        y_[0].originalWallet = address(0xBEEF);
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(y_, pricingId);
        Migration.WeightedLiquidEntitlementInput[] memory d_ = new Migration.WeightedLiquidEntitlementInput[](1);
        d_[0] = Migration.WeightedLiquidEntitlementInput(
            ORIGIN, address(this), 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7, 3, 1 ether, 0, bytes32("WD"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedLiquidEntitlements(d_, pricingId);
        d_[0].originalId = bytes32("other origin");
        vm.prank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(d_, pricingId);
        y_[0].originalId = d_[0].originalId;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, d_[0].originalId));
        allocation.configureDtfCustodySeEntitlements(y_, pricingId);

        address earlier_ = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
        Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
        n_[0] = Migration.NftEntitlementInput(earlier_, 3, address(this), 3, 1 ether, 0, bytes32("earlier"), true);
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(n_, pricingId);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 3);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureDtfCustodySeEntitlements(y_, pricingId);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 4);
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(y_, pricingId);
        n_[0].tokenId = 4;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureNftEntitlements(n_, pricingId);
    }
    function test_canonicalOriginCannotBeSyOrBackingAliasInEitherDirection() public {
        Migration.DtfCustodySeEntitlementInput[] memory s_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(s_, pricingId);
        Migration.WeightedSyEntitlementInput[] memory y_ = new Migration.WeightedSyEntitlementInput[](1);
        y_[0] = Migration.WeightedSyEntitlementInput(
            ORIGIN, address(0xBEEF), 0xB55604CF4dcdABB362078e106D20F98512391EdF,
            3, 1 ether, 0, bytes32("synthetic same origin"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedSyEntitlements(y_, pricingId);
        y_[0].originalId = bytes32("other SY origin");
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(y_, pricingId);
        s_[0].originalId = y_[0].originalId;
        s_[0].originalWallet = address(0xCAFE);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureDtfCustodySeEntitlements(s_, pricingId);
    }


    /// @notice A-prepared rows cannot clear or reprice storage after installing B; explicit B reload replaces only configuration.
    function test_StaleBook_DtfCustodySeReplacementPreservesRecords() public {
        Migration.DtfCustodySeEntitlementInput[] memory a_ = _inputs();
        bytes32 old_ = pricingId;
        vm.prank(migrationOwner); allocation.configureDtfCustodySeEntitlements(a_, old_);
        bytes memory record_ = abi.encode(migration.dtfCustodySeEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.dtfCustodySeSurrender(ORIGIN));
        uint256 supply_ = IERC20(detf).totalSupply();
        Pricing.Inputs memory next_ = migration.migrationWeightedPricing().inputs;
        next_.swapFeeWad = 1e17;
        vm.prank(migrationOwner); pricingId = allocation.setMigrationWeightedPricing(next_);
        assertEq(abi.encode(migration.dtfCustodySeEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.dtfCustodySeSurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, old_, pricingId));
        allocation.configureDtfCustodySeEntitlements(a_, old_);
        assertEq(abi.encode(migration.dtfCustodySeEntitlement(ORIGIN)), record_);
        assertEq(abi.encode(migration.dtfCustodySeSurrender(ORIGIN)), remaining_);
        vm.prank(migrationOwner); allocation.configureDtfCustodySeEntitlements(a_, pricingId);
        assertEq(migration.dtfCustodySeEntitlement(ORIGIN).configurationId, keccak256(abi.encode(block.chainid, detf, pricingId, a_[0])));
        assertNotEq(abi.encode(migration.dtfCustodySeEntitlement(ORIGIN)), record_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }
}
