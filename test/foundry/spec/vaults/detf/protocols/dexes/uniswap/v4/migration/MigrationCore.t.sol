// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation, IUniswapV4DetfMigrationAccounting as Accounting}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigrationDFPkg as MigrationPackage}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationRewardToken as RT}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";

/// @notice Actual registry package, measured genesis, immutable configuration and funded cliff witnesses.
contract MigrationCoreTest is TestBase_UniswapV4DetfMigration {
    function test_deployBindsRealChildrenAndNoPrincipal() public view {
        assertEq(migration.owner(), migrationOwner);
        assertEq(receipt.detf(), detf);
        assertEq(bonds.detf(), detf);
        assertEq(rawSy.yieldToken(), detf);
        assertEq(stakingSy.yieldToken(), address(receipt));
        assertEq(RT(migration.migrationSyRewardToken()).receipt(), address(receipt));
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(receipt.stakingState().totalGons, 0);
        assertFalse(migration.migrationActivated());
    }

    function test_ownerSaltCreatesIsolatedHooks() public {
        address secondOwner_ = makeAddr("second-owner");
        address second_ = _deployMigration(_migrationArgs(secondOwner_));
        assertNotEq(second_, detf);
        assertNotEq(Migration(second_).hook(), migration.hook());
        assertEq(Migration(second_).owner(), secondOwner_);
        assertEq(migration.owner(), migrationOwner);
        assertNotEq(Migration(second_).rebasingClaimToken(), address(receipt));
    }

    function test_partialCapitalCannotAuthorizeNonOwnerGenesis() public {
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        assertEq(IERC20(detf).totalSupply(), 0);
        assertFalse(migration.isReserveLive());
        migration.donateMigrationCapital{value: 100 ether}(new IERC20[](0), new uint256[](0), 100 ether, 0, block.timestamp);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 50 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 50 ether, 1);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.bootstrapMigrationReserve(legs_, 1, 1, block.timestamp);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), 100 ether);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 100 ether);
        assertEq(IERC20(detf).totalSupply(), 0);
        vm.prank(migrationOwner);
        allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        assertTrue(migration.isReserveLive());
        assertEq(IERC20(detf).totalSupply(), migration.migrationBootstrapSelfMinted());
        assertEq(receipt.stakingState().accountedBacking, 0);
        assertEq(receipt.totalSupply(), 0);
        assertGt(IERC20(migration.hook()).balanceOf(address(bonds)), 0);
        IERC20 lp_ = IERC20(migration.hook());
        assertEq(lp_.totalSupply(), lp_.balanceOf(address(bonds)) + lp_.balanceOf(address(0))
            + lp_.balanceOf(address(feeCollector)) + lp_.balanceOf(detf));
        assertEq(receipt.stakingState().feeWeight, 0);
        assertEq(receipt.stakingState().creatorWeight, 0);
    }

    function test_configurationDoesNotMintAndReplacementPreservesIssue() public {
        _fundAndCapture();
        address recipient_ = makeAddr("recipient");
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 first_ = _configure(recipient_, 1 ether, bytes32("original"));
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.totalSupply(), 0);
        uint256 smaller_ = _configure(recipient_, 0.6 ether, bytes32("original"));
        assertLt(smaller_, first_);
        bytes32 config_ = migration.independentAllocation(recipient_).configurationId;
        _configure(recipient_, 0.6 ether, bytes32("original"));
        assertEq(migration.independentAllocation(recipient_).configurationId, config_);
        uint256 id_ = _issue(recipient_);
        assertEq(bonds.positionOf(id_).principal, smaller_);
        assertEq(receipt.stakingState().accountedBacking, smaller_);
        assertEq(IERC20(detf).totalSupply(), supply_ + smaller_);
        _configure(recipient_, 2 ether, bytes32("correction"));
        assertEq(migration.independentIssuance(recipient_).credit, smaller_);
        assertEq(bonds.positionOf(id_).principal, smaller_);
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(recipient_, migration.independentAllocation(recipient_).configurationId);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.IndependentAllocationAlreadyIssued.selector, recipient_));
        allocation.issueIndependentAllocations(requests_);
    }

    function test_snapshotCannotRecaptureOrChangeAfterDonation() public {
        _fundAndCapture();
        uint256 quote_ = migration.previewOriginalCredit(1 ether, 1 ether);
        bytes32 id_ = migration.migrationSnapshot().id;
        vm.prank(migrationOwner);
        vm.expectRevert(Snapshot.SnapshotAlreadyCaptured.selector);
        allocation.captureMigrationSnapshot();
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        assertEq(migration.migrationSnapshot().id, id_);
        assertEq(migration.previewOriginalCredit(1 ether, 1 ether), quote_);
    }

    function test_delayedFirstIssueHasFreshClockAndNoRetroactiveRewards() public {
        _fundAndCapture();
        uint256 credit_ = _configure(address(this), 1 ether, bytes32("first"));
        vm.warp(block.timestamp + 7 days);
        assertEq(migration.pendingExpansionDetf(), 0);
        uint256 id_ = _issue(address(this));
        assertEq(bonds.positionOf(id_).startTimestamp, block.timestamp);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * 1e36);
        assertEq(bonds.previewClaim(id_).rewardsDue, 0);
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    function test_cliffBoundaryMaturePrincipalWorksWhileRewardsClosed() public {
        _fundAndCapture();
        uint256 credit_ = _configure(address(this), 1 ether, bytes32("first"));
        uint256 id_ = _issue(address(this));
        uint256 start_ = block.timestamp;
        vm.warp(start_ + 90 days - 1);
        assertEq(bonds.previewClaim(id_).principalDue, 0);
        assertEq(bonds.claimPrincipal(id_, address(this)), 0);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimBond(id_, address(this));
        vm.warp(start_ + 90 days);
        assertEq(bonds.previewClaim(id_).principalDue, credit_);
        assertEq(bonds.claimPrincipal(id_, address(this)), credit_);
        assertEq(receipt.balanceOf(address(this)), credit_);
        uint256 before_ = IERC20(detf).balanceOf(address(this));
        receipt.exchangeIn(IERC20(address(receipt)), credit_, IERC20(detf), credit_, address(this), false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(address(this)) - before_, credit_);
        assertFalse(migration.migrationActivated());
        assertEq(RT(migration.migrationSyRewardToken()).totalSupply(), 0);
    }

    function test_ordinaryAcquisitionAndBondClosedBeforeBranchSelection() public {
        _fundAndCapture();
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        detfExchangeIn.exchangeIn(IERC20(pairA), 1 ether, IERC20(detf), 0, address(this), false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        (uint256 quote_,) = detfExchangeIn.previewExchangeIn(IERC20(pairA), 1 ether, IERC20(detf));
        assertEq(quote_, 0);
    }

    function test_ordinaryDepositOpensWithFundedIndependentParticipation() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("ordinary activation participant"));
        uint256 id_ = _issue(address(this));
        uint256 started_ = bonds.positionOf(id_).startTimestamp;
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        detfExchangeIn.exchangeIn(IERC20(pairA), 1 ether, IERC20(detf), 1, address(this), false, block.timestamp);
        vm.prank(migrationOwner);
        vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        assertFalse(migration.migrationActivated());
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        uint256 before_ = IERC20(detf).balanceOf(address(this));
        (uint256 out_,) = detfExchangeIn.exchangeIn(
            IERC20(pairA), 1 ether, IERC20(detf), 1, address(this), false, block.timestamp
        );
        assertGt(out_, 0);
        assertEq(IERC20(detf).balanceOf(address(this)) - before_, out_);
        assertEq(bonds.positionOf(id_).startTimestamp, started_);
    }

    function test_activationRemovesEntireAdministrationAndKeepsQueries() public {
        _fundAndCapture();
        bytes4[10] memory selectors_ = [
            Allocation.bootstrapMigrationReserve.selector, Allocation.captureMigrationSnapshot.selector,
            Allocation.configureIndependentAllocations.selector, Allocation.issueIndependentAllocations.selector,
            Allocation.activateMigration.selector, Allocation.configureNftEntitlements.selector,
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureWeightedSyEntitlements.selector,
            Allocation.configureDtfCustodySeEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector
        ];
        address[] memory facets_ = new address[](selectors_.length);
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            facets_[i_] = IDiamondLoupe(detf).facetAddress(selectors_[i_]);
            assertNotEq(facets_[i_], address(0));
        }
        vm.prank(migrationOwner);
        vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        assertFalse(migration.migrationActivated());
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(selectors_[i_]), facets_[i_]);
        }
        _buyOwnerFirstBond();
        // Exhaust execution gas inside the actual cut, not a mocked or storage-corrupted proxy.
        vm.prank(migrationOwner);
        (bool cut_, bytes memory reason_) = detf.call{gas: 150000}(abi.encodeCall(Allocation.activateMigration, ()));
        assertFalse(cut_);
        assertEq(reason_.length, 0);
        assertFalse(migration.migrationActivated());
        assertTrue(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(selectors_[i_]), facets_[i_]);
        }
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        detfExchangeIn.exchangeIn(IERC20(pairA), 1 ether, IERC20(detf), 0, address(this), false, block.timestamp);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationNft(address(0), 3, 0, block.timestamp);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationWeightedLiquid(bytes32(0), 1, 0, block.timestamp);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertTrue(migration.migrationActivated());
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        for (uint256 i_; i_ < selectors_.length; ++i_) assertEq(IDiamondLoupe(detf).facetAddress(selectors_[i_]), address(0));
        assertEq(migration.owner(), migrationOwner);
        assertNotEq(migration.migrationSnapshot().id, bytes32(0));
        assertGt(migration.previewOriginalCredit(1 ether, 0), 0);
        uint256 before_ = IERC20(detf).balanceOf(address(this));
        (uint256 out_,) = detfExchangeIn.exchangeIn(
            IERC20(pairA), 1 ether, IERC20(detf), 1, address(this), false, block.timestamp
        );
        assertGt(out_, 0);
        assertEq(IERC20(detf).balanceOf(address(this)) - before_, out_);
    }
}
