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
            collection_, 3, address(0xBEEF), collection_ == WEIGHTED ? 3772281649 : 562524912595035608166,
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

    function test_separateContributionsReplaceCompletelyAndPreserveSingleOriginalMode() public {
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        a_[0].originalDtf = 0.4 ether;
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(migrationOwner);
        allocation.configureNftContributionEntitlements(a_);
        bytes32 splitId_ = migration.nftEntitlement(WEIGHTED, 3).configurationId;
        allocation.configureNftContributionEntitlements(a_);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, splitId_);
        a_[0].originalEth = 0.2 ether;
        a_[0].originalDtf = 0.3 ether;
        allocation.configureNftContributionEntitlements(a_);
        vm.stopPrank();
        Migration.NftContribution[] memory parts_ = migration.nftContributions(WEIGHTED, 3);
        assertEq(parts_.length, 2);
        assertEq(parts_[0].originalEth, 0.2 ether);
        assertEq(parts_[0].originalDtf, 0);
        assertEq(parts_[1].originalEth, 0);
        assertEq(parts_[1].originalDtf, 0.3 ether);
        assertEq(parts_[0].credit, migration.previewOriginalCredit(0.2 ether, 0));
        assertEq(parts_[1].credit, migration.previewOriginalCredit(0, 0.3 ether));
        Migration.NftEntitlement memory config_ = migration.nftEntitlement(WEIGHTED, 3);
        assertEq(config_.credit, parts_[0].credit + parts_[1].credit);
        assertEq(config_.configurationId,
            keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0], true)));
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(a_);
        parts_ = migration.nftContributions(WEIGHTED, 3);
        assertEq(parts_.length, 1);
        assertEq(parts_[0].originalEth, a_[0].originalEth);
        assertEq(parts_[0].originalDtf, a_[0].originalDtf);
        assertEq(parts_[0].credit, config_.credit);
        assertNotEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, config_.configurationId);
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(a_);
        assertEq(migration.nftContributions(WEIGHTED, 3).length, 2);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, config_.configurationId);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        assertEq(migration.nftContributionSurrenders(WEIGHTED, 3).length, 0);
        assertFalse(migration.nftSurrender(WEIGHTED, 3).consumed);
        assertEq(migration.nftCustody(WEIGHTED, 3).collection, address(0));
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationNft(WEIGHTED, 3, 0, block.timestamp);
    }

    function test_separateContributionLoaderRequiresOwnerAndBothNonzeroOriginalsAtomically() public {
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        a_[0].originalDtf = 0.4 ether;
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureNftContributionEntitlements(a_);
        Migration.NftEntitlementInput[] memory batch_ = new Migration.NftEntitlementInput[](2);
        batch_[0] = a_[0];
        batch_[1] = _input(EARLIER)[0];
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, EARLIER, 3));
        allocation.configureNftContributionEntitlements(batch_);
        assertEq(migration.nftEntitlement(WEIGHTED, 3).configurationId, bytes32(0));
        assertEq(migration.nftContributions(WEIGHTED, 3).length, 0);
        a_[0].originalEth = 0;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, WEIGHTED, 3));
        allocation.configureNftContributionEntitlements(a_);
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

    function test_zeroWalletRejectsBothSourcesAndWalletCorrectionPreservesEconomicOrigin() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        for (uint256 i_; i_ < collections_.length; ++i_) {
            Migration.NftEntitlementInput[] memory a_ = _input(collections_[i_]);
            a_[0].originalWallet = address(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collections_[i_], 3));
            allocation.configureNftEntitlements(a_);
            assertEq(migration.nftEntitlement(collections_[i_], 3).configurationId, bytes32(0));
            a_[0].originalWallet = address(0xBEEF);
            vm.prank(migrationOwner);
            allocation.configureNftEntitlements(a_);
            Migration.NftEntitlement memory before_ = migration.nftEntitlement(collections_[i_], 3);
            a_[0].originalWallet = address(0xCAFE);
            vm.prank(migrationOwner);
            allocation.configureNftEntitlements(a_);
            Migration.NftEntitlement memory after_ = migration.nftEntitlement(collections_[i_], 3);
            assertEq(after_.original.originalWallet, address(0xCAFE));
            assertNotEq(before_.configurationId, after_.configurationId);
            assertEq(after_.configurationId,
                keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
            assertEq(before_.originalId, after_.originalId);
            assertEq(before_.credit, after_.credit);
            vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, before_.originalId));
            _configure(address(this), 1 ether, before_.originalId);
        }
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
                _buyOwnerFirstBond();
                vm.prank(migrationOwner);
                allocation.activateMigration();
            }
        }
        assertFalse(migration.nftSurrender(WEIGHTED, 3).consumed);
    }

    function test_retainedDeclarationIncludesEveryProductSelector() public {
        bytes4[] memory expected_ = new bytes4[](29);
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
        expected_[11] = Migration.nftCustody.selector;
        expected_[12] = Migration.previewNftSurrender.selector;
        expected_[13] = Migration.surrenderMigrationNft.selector;
        expected_[14] = IERC721Receiver.onERC721Received.selector;
        expected_[15] = Migration.weightedLiquidEntitlement.selector;
        expected_[16] = Migration.weightedLiquidSurrender.selector;
        expected_[17] = Migration.previewWeightedLiquidSurrender.selector;
        expected_[18] = Migration.surrenderMigrationWeightedLiquid.selector;
        expected_[19] = Migration.migrationOwnerFirstBondTokenId.selector;
        expected_[20] = Migration.weightedSyEntitlement.selector;
        expected_[21] = Migration.weightedSySurrender.selector;
        expected_[22] = Migration.previewWeightedSySurrender.selector;
        expected_[23] = Migration.surrenderMigrationWeightedSy.selector;
        expected_[24] = Migration.dtfCustodySeEntitlement.selector;
        expected_[25] = Migration.dtfCustodySeSurrender.selector;
        expected_[26] = Migration.previewDtfCustodySeSurrender.selector;
        expected_[27] = Migration.surrenderMigrationDtfCustodySe.selector;
        expected_[28] = Migration.claimedSyWeights.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(expected_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, expected_, facet_.facetFuncs()));
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        for (uint256 i_; i_ < expected_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(expected_[i_]), address(facet_));
        }
        address query_ = IDiamondLoupe(detf).facetAddress(Migration.nftContributions.selector);
        assertNotEq(query_, address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Migration.nftEntitlement.selector), query_);
        assertEq(IDiamondLoupe(detf).facetAddress(Migration.nftSurrender.selector), query_);
        assertEq(IDiamondLoupe(detf).facetAddress(Migration.nftContributionSurrenders.selector), query_);
        assertEq(IDiamondLoupe(detf).facetAddress(Migration.previewNftContributionSurrender.selector), query_);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureNftEntitlements.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureNftContributionEntitlements.selector), address(0));
        assertEq(migration.nftContributions(WEIGHTED, 3).length, 0);
        assertEq(migration.nftContributionSurrenders(WEIGHTED, 3).length, 0);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, WEIGHTED, 3));
        migration.previewNftContributionSurrender(WEIGHTED, 3);
        Migration.NftEntitlementInput[] memory a_ = _input(WEIGHTED);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (a_)));
        assertFalse(ok_);
        (ok_,) = detf.call(abi.encodeCall(Allocation.configureNftContributionEntitlements, (a_)));
        assertFalse(ok_);
    }
}
