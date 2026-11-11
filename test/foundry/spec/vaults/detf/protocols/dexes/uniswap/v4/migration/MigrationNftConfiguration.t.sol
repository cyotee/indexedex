// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Hermetic configuration/authority tests; actual legacy custody is tested only on pinned bytecode.
contract MigrationNftConfigurationTest is TestBase_UniswapV4DetfMigration {
    address constant WEIGHTED = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    address constant EARLIER = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _input(address collection_) private pure returns (Migration.NftEntitlementInput[] memory a_) {
        a_ = new Migration.NftEntitlementInput[](1);
        // Deliberately bounded quote fixtures, not operational historical allocations.
        a_[0] = Migration.NftEntitlementInput(
            collection_, 3, collection_ == WEIGHTED ? 3772281649 : 562524912595035608166,
            1 ether, 0, bytes32("configuration fixture"), true
        );
    }

    function test_fullReplacementIsIdempotentAndDoesNotMint() public {
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(migrationOwner);
        allocation.configureNftEntitlements(a_);
        a_[0].originalEth = 0.6 ether;
        allocation.configureNftEntitlements(a_);
        bytes32 id_ = migration.nftEntitlement(WEIGHTED, 3).configurationId;
        allocation.configureNftEntitlements(a_);
        vm.stopPrank();
        assertEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, id_);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).credit, migration.previewOriginalCredit(0.6 ether, 0));
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        assertFalse(migration.nftSurrender(WEIGHTED, 3).consumed);
        assertEq(migration.nftCustody(WEIGHTED, 3).collection, address(0));
    }

    function test_sameNumericIdentityHasDistinctSourceAndDomain() public {
        vm.startPrank(migrationOwner);
        allocation.configureNftEntitlements(_input(WEIGHTED));
        allocation.configureNftEntitlements(_input(EARLIER));
        vm.stopPrank();
        assertNotEq(migration.nftEntitlement(WEIGHTED, 3).originalId, migration.nftEntitlement(EARLIER, 3).originalId);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).original.originalUnits, 3772281649);
        assertEq(migration.nftEntitlement(EARLIER, 3).original.originalUnits, 562524912595035608166);
        assertEq(migration.migrationNftOriginalId(WEIGHTED, 3),
            keccak256(abi.encode("migration.nft", uint256(4663), detf, migration.migrationSnapshot().id, WEIGHTED, uint256(3))));
    }

    function test_unknownComponentsAndReservedUnitsRejectWholeBatch() public {
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](2);
        a_[0] = _input(WEIGHTED)[0];
        a_[1] = _input(EARLIER)[0];
        a_[1].contributionsKnown = false;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, EARLIER, 3));
        allocation.configureNftEntitlements(a_);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, bytes32(0));
        for (uint256 i_; i_ < 3; ++i_) {
            Migration.NftEntitlementInput[] memory reserved_ = _input(EARLIER);
            reserved_[0].tokenId = i_;
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, EARLIER, i_));
            allocation.configureNftEntitlements(reserved_);
        }
    }

    function test_fixedSourceAndCurrentOwnerBoundaries() public {
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureNftEntitlements(a_);
        a_[0].collection = address(0xBAD);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedMigrationNft.selector, 4663, address(0xBAD)));
        allocation.configureNftEntitlements(a_);
        a_[0].collection = WEIGHTED;
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedMigrationNft.selector, 1, WEIGHTED));
        allocation.configureNftEntitlements(a_);
    }

    function test_knownOriginalCollisionRejectsIndependentAfterNftConfiguration() public {
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(_input(WEIGHTED));
        bytes32 origin_ = migration.migrationNftOriginalId(WEIGHTED, 3);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
        _configure(address(this), 1 ether, origin_);
        assertEq(migration.independentAllocation(address(this)).configurationId, bytes32(0));
    }

    function test_knownOriginalCollisionRejectsNftBeforeAndAfterIndependentIssuance() public {
        bytes32 origin_ = migration.migrationNftOriginalId(WEIGHTED, 3);
        _configure(address(this), 1 ether, origin_);
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
        allocation.configureNftEntitlements(a_);
        uint256 bond_ = _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement independent"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
        allocation.configureNftEntitlements(a_);
        assertEq(migration.independentIssuance(address(this)).bondTokenId, bond_);
    }

    function test_unsolicitedAndReplayedReceiverCallsRejectBeforeAndAfterActivation() public {
        for (uint256 stage_; stage_ < 2; ++stage_) {
            vm.expectRevert(Migration.UnexpectedNftCallback.selector);
            IERC721Receiver(detf).onERC721Received(detf, address(this), 3, "");
            vm.prank(WEIGHTED);
            vm.expectRevert(Migration.UnexpectedNftCallback.selector);
            IERC721Receiver(detf).onERC721Received(detf, address(this), 3, "");
            if (stage_ == 0) {
                vm.prank(migrationOwner);
                allocation.activateMigration();
            }
        }
        assertFalse(migration.nftSurrender(WEIGHTED, 3).consumed);
    }

    function test_retainedDeclarationIncludesEveryProductSelector() public {
        bytes4[] memory expected_ = new bytes4[](17);
        expected_[0] = Migration.migrationActivated.selector;
        expected_[1] = Migration.migrationSyRewardToken.selector;
        expected_[2] = Migration.migrationSnapshotSource.selector;
        expected_[3] = Migration.migrationSnapshot.selector;
        expected_[4] = Migration.previewOriginalCredit.selector;
        expected_[5] = Migration.independentAllocation.selector;
        expected_[6] = Migration.independentIssuance.selector;
        expected_[7] = Migration.migrationDonationInventory.selector;
        expected_[8] = Migration.migrationBootstrapSelfMinted.selector;
        expected_[9] = Migration.donateMigrationCapital.selector;
        expected_[10] = Migration.migrationNftOriginalId.selector;
        expected_[11] = Migration.nftEntitlement.selector;
        expected_[12] = Migration.nftSurrender.selector;
        expected_[13] = Migration.nftCustody.selector;
        expected_[14] = Migration.previewNftSurrender.selector;
        expected_[15] = Migration.surrenderMigrationNft.selector;
        expected_[16] = IERC721Receiver.onERC721Received.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(expected_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, expected_, facet_.facetFuncs()));
        vm.prank(migrationOwner);
        allocation.activateMigration();
        for (uint256 i_; i_ < expected_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(expected_[i_]), address(facet_));
        }
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureNftEntitlements.selector), address(0));
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (a_)));
        assertFalse(ok_);
    }
}
