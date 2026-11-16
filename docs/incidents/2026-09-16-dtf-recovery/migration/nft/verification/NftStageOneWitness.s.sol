// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {MigrationNftForkBase} from
    "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol";
import {
    IUniswapV4DetfMigration as Migration,
    IUniswapV4DetfMigrationAllocation as Allocation,
    IUniswapV4DetfMigrationAccounting as Accounting
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Independent pinned-source lifecycle witness; simulation only, never broadcast.
/// @dev Reuses the real registry TestBase, not a subclass or patched instance of the SUT.
/// Extends existing fork coverage with actual mature-principal exits during prolonged Stage 1
/// followed by later real-source surrenders on that same instance.
contract NftStageOneWitness is MigrationNftForkBase {
    event VerifiedNftLifecycle(
        address parent, uint256 firstStart, uint256 laterStart,
        uint256 weightedCredit, uint256 earlierCredit, uint256 laterWeighted, uint256 laterEarlier
    );

    function run() external {
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 originalWeighted_ = _configureNft(WEIGHTED, 32);
        uint256 originalEarlier_ = _configureNft(EARLIER, 4);
        uint256 laterWeighted_ = _configureNft(WEIGHTED, 26);
        uint256 laterEarlier_ = _configureNft(EARLIER, 3);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_);
        assertEq(receipt.stakingState().totalGons, 0);
        address weightedHolder_ = IERC721(WEIGHTED).ownerOf(32);
        address earlierHolder_ = IERC721(EARLIER).ownerOf(4);
        uint256 firstStart_ = vm.getBlockTimestamp();
        (uint256 weightedBond_, uint256 weightedCredit_) = _surrender(WEIGHTED, 32);
        (uint256 earlierBond_, uint256 earlierCredit_) = _surrender(EARLIER, 4);
        // These small fixture products fit uint256; this oracle does not call adapter math.
        assertEq(weightedCredit_, originalWeighted_ * 46365243 / 54436459);
        assertEq(earlierCredit_, originalEarlier_);
        assertEq(IERC20(detf).totalSupply() - supplyBefore_, weightedCredit_ + earlierCredit_);
        assertEq(receipt.stakingState().accountedBacking, weightedCredit_ + earlierCredit_);
        bytes memory weightedHistory_ = abi.encode(migration.nftSurrender(WEIGHTED, 32));
        bytes memory earlierHistory_ = abi.encode(migration.nftSurrender(EARLIER, 4));

        vm.warp(firstStart_ + 90 days - 1);
        vm.prank(weightedHolder_);
        assertEq(bonds.claimPrincipal(weightedBond_, weightedHolder_), 0);
        vm.prank(earlierHolder_);
        assertEq(bonds.claimPrincipal(earlierBond_, earlierHolder_), 0);
        assertEq(receipt.balanceOf(weightedHolder_), 0);
        assertEq(receipt.balanceOf(earlierHolder_), 0);

        vm.warp(firstStart_ + 120 days);
        assertFalse(migration.migrationActivated());
        vm.prank(weightedHolder_);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimRewards(weightedBond_, weightedHolder_);
        vm.prank(earlierHolder_);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimBond(earlierBond_, earlierHolder_);
        vm.prank(weightedHolder_);
        assertEq(bonds.claimPrincipal(weightedBond_, weightedHolder_), weightedCredit_);
        vm.prank(earlierHolder_);
        assertEq(bonds.claimPrincipal(earlierBond_, earlierHolder_), earlierCredit_);
        assertEq(receipt.balanceOf(weightedHolder_), weightedCredit_);
        assertEq(receipt.balanceOf(earlierHolder_), earlierCredit_);
        uint256 weightedBalance_ = IERC20(detf).balanceOf(weightedHolder_);
        uint256 earlierBalance_ = IERC20(detf).balanceOf(earlierHolder_);
        vm.prank(weightedHolder_);
        receipt.exchangeIn(IERC20(address(receipt)), weightedCredit_, IERC20(detf),
            weightedCredit_, weightedHolder_, false, block.timestamp);
        vm.prank(earlierHolder_);
        receipt.exchangeIn(IERC20(address(receipt)), earlierCredit_, IERC20(detf),
            earlierCredit_, earlierHolder_, false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(weightedHolder_) - weightedBalance_, weightedCredit_);
        assertEq(IERC20(detf).balanceOf(earlierHolder_) - earlierBalance_, earlierCredit_);
        assertFalse(migration.migrationActivated());
        assertEq(abi.encode(migration.nftSurrender(WEIGHTED, 32)), weightedHistory_);
        assertEq(abi.encode(migration.nftSurrender(EARLIER, 4)), earlierHistory_);
        assertEq(IERC721(WEIGHTED).ownerOf(32), detf);
        assertEq(IERC721(EARLIER).ownerOf(4), detf);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, WEIGHTED, 32));
        migration.surrenderMigrationNft(WEIGHTED, 32, 0, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, EARLIER, 4));
        migration.surrenderMigrationNft(EARLIER, 4, 0, block.timestamp);

        vm.prank(migrationOwner);
        allocation.activateMigration();
        bytes4[6] memory removed_ = [
            Allocation.bootstrapMigrationReserve.selector, Allocation.captureMigrationSnapshot.selector,
            Allocation.configureIndependentAllocations.selector, Allocation.issueIndependentAllocations.selector,
            Allocation.activateMigration.selector, Allocation.configureNftEntitlements.selector
        ];
        for (uint256 i_; i_ < removed_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(removed_[i_]), address(0));
        }
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        (bool loaded_,) = detf.call(abi.encodeCall(
            Allocation.configureNftEntitlements, (new Migration.NftEntitlementInput[](0))
        ));
        assertFalse(loaded_);
        (uint256 laterWeightedBond_, uint256 actualWeighted_) = _surrender(WEIGHTED, 26);
        (uint256 laterEarlierBond_, uint256 actualEarlier_) = _surrender(EARLIER, 3);
        assertEq(actualWeighted_, laterWeighted_);
        assertEq(actualEarlier_, laterEarlier_);
        assertGt(laterWeightedBond_, earlierBond_);
        assertGt(laterEarlierBond_, laterWeightedBond_);
        assertEq(bonds.positionOf(laterWeightedBond_).startTimestamp, firstStart_ + 120 days);
        assertEq(bonds.positionOf(laterEarlierBond_).startTimestamp, firstStart_ + 120 days);
        vm.warp(firstStart_ + 210 days - 1);
        assertEq(bonds.previewClaim(laterWeightedBond_).principalDue, 0);
        assertEq(bonds.previewClaim(laterEarlierBond_).principalDue, 0);
        vm.warp(firstStart_ + 210 days);
        assertEq(bonds.previewClaim(laterWeightedBond_).principalDue, laterWeighted_);
        assertEq(bonds.previewClaim(laterEarlierBond_).principalDue, laterEarlier_);
        emit VerifiedNftLifecycle(detf, firstStart_, firstStart_ + 120 days,
            weightedCredit_, earlierCredit_, laterWeighted_, laterEarlier_);
    }
}

/// @dev Match the existing phase04 verifier: keep the test fixture off the ephemeral script address.
contract NftStageOneWitnessRunner is Script {
    function run() external {
        NftStageOneWitness witness_ = new NftStageOneWitness();
        vm.allowCheatcodes(address(witness_));
        witness_.setUp();
        witness_.run();
    }
}
