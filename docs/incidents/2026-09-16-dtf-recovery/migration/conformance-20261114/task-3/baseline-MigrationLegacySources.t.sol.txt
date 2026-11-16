// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {MigrationNftForkBase, IWeightedClaims, IEarlierClaims, IEarlierParent} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IMigrationWeightedNft, IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";

contract MigrationLegacySourcesTest is MigrationNftForkBase {
    function test_wrongCurrentHolderCannotUseRecordedPurchaserEntitlement() public {
        _configureNft(WEIGHTED, 26);
        _activate();
        address holder_ = IERC721(WEIGHTED).ownerOf(26);
        address purchaser_ = address(bytes20(hex"c379feb4182211abe71a34858265e4bf5ff35e06"));
        assertNotEq(holder_, purchaser_);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(holder_);
        IERC721(WEIGHTED).approve(detf, 26);
        vm.expectRevert(abi.encodeWithSignature("NotOriginalNftWallet(address,address)", holder_, purchaser_));
        migration.surrenderMigrationNft(WEIGHTED, 26, 1, block.timestamp);
        vm.stopPrank();
        _assertNotConsumed(WEIGHTED, 26, holder_, supply_);
    }

    function test_weightedPartialUsesWholeRemainingPrincipalAndFrozenOriginalQuote() public {
        IMigrationWeightedNft.Position memory before_ = IMigrationWeightedNft(WEIGHTED).positionOf(32);
        assertEq(before_.principal, 54436459);
        assertEq(before_.claimedPrincipal, 8071216);
        uint256 c0_ = _configureNft(WEIGHTED, 32);
        _activate();
        uint256 expected_ = Math.mulDiv(c0_, 46365243, 54436459);
        uint256 supply_ = IERC20(detf).totalSupply();
        (uint256 units_, uint256 preview_) = migration.previewNftSurrender(WEIGHTED, 32);
        assertEq(units_, 46365243); assertEq(preview_, expected_);
        assertNotEq(expected_, migration.previewOriginalCredit(0,
            Math.mulDiv(56017714220190058289217, 46365243, 54436459)));
        (uint256 id_, uint256 actual_) = _surrender(WEIGHTED, 32);
        assertEq(actual_, expected_);
        assertEq(IERC20(detf).totalSupply() - supply_, expected_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + expected_);
        assertEq(receipt.stakingState().accountedBacking, initialBacking + expected_);
        assertEq(bonds.positionOf(id_).stakingGons, expected_ * receipt.stakingState().gonsPerUnit);
        assertEq(abi.encode(IMigrationWeightedNft(WEIGHTED).positionOf(32)), abi.encode(before_));
        Migration.NftSurrender memory s_ = migration.nftSurrender(WEIGHTED, 32);
        assertEq(s_.originalUnits, 54436459); assertEq(s_.remainingUnits, 46365243);
        assertEq(s_.credit, expected_); assertTrue(s_.consumed);
    }

    function test_transferredWeightedHolderMustReturnToPurchaserBeforeSurrender() public {
        _configureNft(WEIGHTED, 26);
        _activate();
        address holder_ = IERC721(WEIGHTED).ownerOf(26);
        assertEq(holder_, 0x2e69E40C4a4Ab5CA6826850F347acf8076a8063e);
        address next_ = makeAddr("new actual holder");
        vm.prank(holder_);
        IERC721(WEIGHTED).transferFrom(holder_, next_, 26);
        vm.prank(next_);
        IERC721(WEIGHTED).setApprovalForAll(holder_, true);
        address original_ = _original(WEIGHTED, 26).originalWallet;
        vm.prank(holder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, holder_, original_));
        migration.surrenderMigrationNft(WEIGHTED, 26, 0, block.timestamp);
        _returnToOriginal(WEIGHTED, 26);
        (uint256 id_,) = _surrender(WEIGHTED, 26);
        assertEq(IERC721(address(bonds)).ownerOf(id_), original_);
        assertFalse(IERC721(WEIGHTED).isApprovedForAll(detf, holder_));
    }

    function test_earlierRewardsAndHolderTransferPreserveOriginalSharesAndDisabledHarvest() public {
        uint256 c0_ = _configureNft(EARLIER, 4);
        _activate();
        address holder_ = IERC721(EARLIER).ownerOf(4);
        address next_ = makeAddr("earlier transferred holder");
        vm.prank(holder_);
        IERC721(EARLIER).transferFrom(holder_, next_, 4);
        uint256 balance_ = IERC20(EARLIER_PARENT).balanceOf(next_);
        vm.prank(next_);
        uint256 rewards_ = IEarlierClaims(EARLIER).claimRewards(4, next_);
        assertEq(rewards_, 309005608995105);
        assertEq(IERC20(EARLIER_PARENT).balanceOf(next_) - balance_, rewards_);
        assertEq(IMigrationEarlierNft(EARLIER).getPosition(4).originalShares, 2281854312954086546);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", 0xb7D4Bb379D361AD442CddEE53eA71a33957826A7));
        IEarlierParent(EARLIER_PARENT).closeBondMature(4, new uint256[](2), next_, block.timestamp);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, next_, holder_));
        migration.surrenderMigrationNft(EARLIER, 4, 1, block.timestamp);
        _returnToOriginal(EARLIER, 4);
        (uint256 id_, uint256 credit_) = _surrender(EARLIER, 4);
        assertEq(credit_, c0_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), holder_);
        assertEq(migration.nftSurrender(EARLIER, 4).remainingUnits, 2281854312954086546);
        assertEq(IERC20(EARLIER_PARENT).balanceOf(detf), 0);
    }

    function test_earlierAccountingSharesAreNeitherEffectiveWeightNorPhysicalLp() public {
        IMigrationEarlierNft.Position memory p_ = IMigrationEarlierNft(EARLIER).getPosition(12);
        assertEq(p_.originalShares, 47848240999749918187208884);
        assertEq(IEarlierClaims(EARLIER).convertToAssets(p_.originalShares), 47848240999749918187208985);
        uint256 c0_ = _configureNft(EARLIER, 12);
        _activate();
        (, uint256 credit_) = _surrender(EARLIER, 12);
        assertEq(credit_, c0_);
        assertEq(migration.nftSurrender(EARLIER, 12).remainingUnits, p_.originalShares);
        assertEq(IMigrationEarlierNft(EARLIER).getPosition(12).originalShares, p_.originalShares);
    }

    function test_sameIdInTwoCollectionsIncludesStillLockedEarlierPrincipal() public {
        uint256 weighted_ = _configureNft(WEIGHTED, 3);
        uint256 earlier_ = _configureNft(EARLIER, 3);
        _activate();
        IMigrationEarlierNft.Position memory p_ = IMigrationEarlierNft(EARLIER).getPosition(3);
        assertGt(p_.unlockTime, block.timestamp);
        assertNotEq(p_.effectiveShares, p_.originalShares);
        (uint256 first_, uint256 firstCredit_) = _surrender(WEIGHTED, 3);
        (uint256 second_, uint256 secondCredit_) = _surrender(EARLIER, 3);
        assertNotEq(first_, second_);
        assertEq(firstCredit_, weighted_); assertEq(secondCredit_, earlier_);
        assertEq(receipt.stakingState().accountedBacking, initialBacking + weighted_ + earlier_);
        assertEq(migration.nftCustody(WEIGHTED, 3).collection, WEIGHTED);
        assertEq(migration.nftCustody(EARLIER, 3).collection, EARLIER);
    }

    function test_claimBeforeSurrenderRaceUsesLiveFractionAndRejectsStaleMinimum() public {
        _configureNft(WEIGHTED, 32);
        _activate();
        (, uint256 previous_) = migration.previewNftSurrender(WEIGHTED, 32);
        address holder_ = IERC721(WEIGHTED).ownerOf(32);
        vm.prank(holder_);
        uint256 paid_ = IWeightedClaims(WEIGHTED).claimPrincipal(32, holder_);
        assertGt(paid_, 0);
        (uint256 remaining_, uint256 current_) = migration.previewNftSurrender(WEIGHTED, 32);
        assertEq(remaining_, 46365243 - paid_);
        assertLt(current_, previous_);
        vm.prank(holder_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, previous_, current_));
        migration.surrenderMigrationNft(WEIGHTED, 32, previous_, block.timestamp);
        assertFalse(migration.nftSurrender(WEIGHTED, 32).consumed);
        (, uint256 delivered_) = _surrender(WEIGHTED, 32);
        assertEq(delivered_, current_);
    }

    function test_rewardOnlyWeightedAndBurnedEarlierEarnNoCredit() public {
        _configureNft(WEIGHTED, 3);
        _configureNft(EARLIER, 4);
        _activate();
        address weightedHolder_ = IERC721(WEIGHTED).ownerOf(3);
        vm.prank(weightedHolder_);
        IWeightedClaims(WEIGHTED).claimPrincipal(3, weightedHolder_);
        IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(WEIGHTED).positionOf(3);
        assertEq(p_.principal, p_.claimedPrincipal); assertGt(p_.stakingGons, 0);
        assertEq(IERC721(WEIGHTED).ownerOf(3), weightedHolder_);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(weightedHolder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, WEIGHTED, 3));
        migration.surrenderMigrationNft(WEIGHTED, 3, 0, block.timestamp);
        _assertNotConsumed(WEIGHTED, 3, weightedHolder_, supply_);
        address earlierHolder_ = IERC721(EARLIER).ownerOf(4);
        vm.prank(earlierHolder_);
        IEarlierParent(EARLIER_PARENT).sellPositionToDetfNft(4, earlierHolder_);
        assertEq(IERC721(EARLIER).ownerOf(4), address(0));
        assertEq(IMigrationEarlierNft(EARLIER).getPosition(4).originalShares, 0);
        vm.prank(earlierHolder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, EARLIER, 4));
        migration.surrenderMigrationNft(EARLIER, 4, 0, block.timestamp);
        assertFalse(migration.nftSurrender(EARLIER, 4).consumed);
        assertEq(IERC20(detf).totalSupply(), supply_);
        // No descendant representation is assigned a new claim by either operation.
        assertFalse(migration.independentIssuance(earlierHolder_).issued);
    }

    function test_burnedNonexistentReservedAndZeroCreditRejectWithoutCustody() public {
        _configureNft(WEIGHTED, 25);
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
        a_[0] = _original(WEIGHTED, 4);
        a_[0].originalEth = 0;
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(a_);
        _activate();
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, WEIGHTED, 25));
        migration.surrenderMigrationNft(WEIGHTED, 25, 0, block.timestamp);
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        for (uint256 i_; i_ < 2; ++i_) {
            for (uint256 id_; id_ < 3; ++id_) {
                vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collections_[i_], id_));
                migration.surrenderMigrationNft(collections_[i_], id_, 0, block.timestamp);
            }
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collections_[i_], 999999));
            migration.surrenderMigrationNft(collections_[i_], 999999, 0, block.timestamp);
        }
        address holder_ = IERC721(WEIGHTED).ownerOf(4);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(holder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, WEIGHTED, 4));
        migration.surrenderMigrationNft(WEIGHTED, 4, 0, block.timestamp);
        _assertNotConsumed(WEIGHTED, 4, holder_, supply_);
    }

    function test_missingApprovalRollsBackPretransferAcceptanceForBothSources() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        _configureNft(WEIGHTED, 3);
        _configureNft(EARLIER, 3);
        _activate();
        for (uint256 i_; i_ < 2; ++i_) {
            address collection_ = collections_[i_];
            address holder_ = IERC721(collection_).ownerOf(3);
            uint256 supply_ = IERC20(detf).totalSupply();
            vm.prank(holder_);
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, detf, 3));
            migration.surrenderMigrationNft(collection_, 3, 1, block.timestamp);
            _assertNotConsumed(collection_, 3, holder_, supply_);
        }
        _surrender(WEIGHTED, 3);
        _surrender(EARLIER, 3);
    }

    function test_inconsistentOriginalUnitsRejectBothSourcesWithoutChangingRealPositions() public {
        address[2] memory collections_ = [WEIGHTED, EARLIER];
        for (uint256 i_; i_ < 2; ++i_) {
            address collection_ = collections_[i_];
            Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
            a_[0] = _original(collection_, 3);
            // Deliberately invalid loader metadata, not a mutation of the legacy position.
            a_[0].originalUnits += 1;
            vm.prank(migrationOwner);
            allocation.configureNftEntitlements(a_);
        }
        _activate();
        for (uint256 i_; i_ < 2; ++i_) {
            address collection_ = collections_[i_];
            address holder_ = IERC721(collection_).ownerOf(3);
            uint256 supply_ = IERC20(detf).totalSupply();
            vm.prank(holder_);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collection_, 3));
            migration.surrenderMigrationNft(collection_, 3, 0, block.timestamp);
            _assertNotConsumed(collection_, 3, holder_, supply_);
        }
    }
}
