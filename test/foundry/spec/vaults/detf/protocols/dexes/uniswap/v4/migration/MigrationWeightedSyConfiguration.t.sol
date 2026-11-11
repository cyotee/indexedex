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

/// @notice Synthetic original allocations; actual WY custody is tested against pinned legacy bytecode.
contract MigrationWeightedSyConfigurationTest is TestBase_UniswapV4DetfMigration {
    address constant WY = 0xB55604CF4dcdABB362078e106D20F98512391EdF;
    address constant NFT = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    bytes32 constant ORIGIN = bytes32("synthetic W-Y original");

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _inputs() private view returns (Migration.WeightedSyEntitlementInput[] memory a_) {
        a_ = new Migration.WeightedSyEntitlementInput[](1);
        a_[0] = Migration.WeightedSyEntitlementInput(
            ORIGIN, address(this), WY, 3, 1 ether, 0, bytes32("synthetic original inputs"), true
        );
    }

    function test_unconsumedReplacementFreezesQuoteAndMintsNothing() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.WeightedSyEntitlementInput[] memory a_ = _inputs();
        a_[0].originalUnits = 5;
        vm.startPrank(migrationOwner);
        allocation.configureWeightedSyEntitlements(a_);
        a_[0].originalEth = 0.6 ether;
        a_[0].originalUnits = 3;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureWeightedSyEntitlements(a_);
        allocation.configureWeightedSyEntitlements(a_);
        vm.stopPrank();
        Migration.WeightedSyEntitlement memory c_ = migration.weightedSyEntitlement(ORIGIN);
        uint256 credit_ = migration.previewOriginalCredit(0.6 ether, 0);
        assertTrue(c_.configured);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, credit_);
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
        assertEq(migration.previewWeightedSySurrender(ORIGIN, 1), credit_ / 3);
        assertEq(migration.previewWeightedSySurrender(ORIGIN, 3), credit_);
        Migration.WeightedSySurrender memory s_ = migration.weightedSySurrender(ORIGIN);
        assertEq(s_.remainingUnits, 3);
        assertEq(s_.remainingCredit, credit_);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        vm.warp(block.timestamp + 1 days);
        assertEq(migration.previewWeightedSySurrender(ORIGIN, 3), credit_);
    }

    function test_missingOriginalInputsAndWrongAuthorityRejectAtomically() public {
        Migration.WeightedSyEntitlementInput[] memory a_ = _inputs();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureWeightedSyEntitlements(a_);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _inputs();
            if (i_ == 0) a_[0].originalWallet = address(0);
            else if (i_ == 1) a_[0].originalUnits = 0;
            else if (i_ == 2) a_[0].contributionsKnown = false;
            else if (i_ == 3) a_[0].evidenceId = bytes32(0);
            else a_[0].originalId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, a_[0].originalId));
            allocation.configureWeightedSyEntitlements(a_);
        }
        assertFalse(migration.weightedSyEntitlement(ORIGIN).configured);
        a_ = _inputs();
        a_[0].source = address(0xBAD);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedSySource.selector, 4663, address(0xBAD)));
        allocation.configureWeightedSyEntitlements(a_);
        a_[0].source = WY;
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedSySource.selector, 1, WY));
        allocation.configureWeightedSyEntitlements(a_);
    }

    function test_currentOwnerAndBadSecondRowPreserveCompleteConfiguration() public {
        Migration.WeightedSyEntitlementInput[] memory a_ = _inputs();
        address next_ = makeAddr("next weighted owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureWeightedSyEntitlements(a_);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureWeightedSyEntitlements(a_);
        vm.prank(next_);
        allocation.configureWeightedSyEntitlements(a_);
        bytes memory before_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.weightedSySurrender(ORIGIN));
        Migration.WeightedSyEntitlementInput[] memory batch_ = new Migration.WeightedSyEntitlementInput[](2);
        batch_[0] = a_[0];
        batch_[0].originalUnits = 8;
        batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0];
        batch_[1].originalId = bytes32("bad second");
        batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, batch_[1].originalId));
        allocation.configureWeightedSyEntitlements(batch_);
        assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), before_);
        assertEq(abi.encode(migration.weightedSySurrender(ORIGIN)), remaining_);
        assertFalse(migration.weightedSyEntitlement(batch_[1].originalId).configured);
    }

    function test_sameCanonicalOriginCannotBeNftOrIndependentInEitherDirection() public {
        Migration.WeightedSyEntitlementInput[] memory a_ = _inputs();
        a_[0].originalId = migration.migrationNftOriginalId(NFT, 3);
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(a_);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        _configure(address(this), 1 ether, a_[0].originalId);
        Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
        n_[0] = Migration.NftEntitlementInput(NFT, 3, address(this), 1, 1 ether, 0, bytes32("fixture"), true);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        allocation.configureNftEntitlements(n_);
        n_[0].tokenId = 4;
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(n_);
        a_[0].originalId = migration.migrationNftOriginalId(NFT, 4);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, a_[0].originalId));
        allocation.configureWeightedSyEntitlements(a_);
        _configure(address(this), 1 ether, ORIGIN);
        _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        a_[0].originalId = ORIGIN;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedSyEntitlements(a_);
    }

    function test_activationRemovesNewLoadingAndRetainsExplicitMissingRecordRejection() public {
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(_inputs());
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedSyEntitlements.selector), address(0));
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationWeightedSy.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.weightedSyEntitlement.selector), address(0));
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureWeightedSyEntitlements, (_inputs())));
        assertFalse(ok_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationWeightedSy(bytes32("absent"), 1, 0, block.timestamp);
        assertTrue(migration.weightedSyEntitlement(ORIGIN).configured);
        assertEq(migration.weightedSySurrender(ORIGIN).consumedUnits, 0);
    }

    function test_canonicalCollisionWithWdAndEarlierNftSurvivesWalletCorrection() public {
        Migration.WeightedSyEntitlementInput[] memory y_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(y_);
        y_[0].originalWallet = address(0xBEEF);
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(y_);
        Migration.WeightedLiquidEntitlementInput[] memory d_ = new Migration.WeightedLiquidEntitlementInput[](1);
        d_[0] = Migration.WeightedLiquidEntitlementInput(
            ORIGIN, address(this), 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7, 3, 1 ether, 0, bytes32("WD"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedLiquidEntitlements(d_);
        d_[0].originalId = bytes32("other origin");
        vm.prank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(d_);
        y_[0].originalId = d_[0].originalId;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, d_[0].originalId));
        allocation.configureWeightedSyEntitlements(y_);

        address earlier_ = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
        Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
        n_[0] = Migration.NftEntitlementInput(earlier_, 3, address(this), 3, 1 ether, 0, bytes32("earlier"), true);
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(n_);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 3);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureWeightedSyEntitlements(y_);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 4);
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(y_);
        n_[0].tokenId = 4;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureNftEntitlements(n_);
    }
}
