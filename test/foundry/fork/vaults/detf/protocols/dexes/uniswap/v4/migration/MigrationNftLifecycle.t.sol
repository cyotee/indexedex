// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IMigrationWeightedNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
import {MigrationNftForkBase} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";

/// @notice External current holder, not a replacement source, parent, registry or funding child.
contract MigrationNftHolder is IERC721Receiver {
    Migration immutable parent;
    bool public rejectBond;
    bool public rejectSecondBond;
    uint256 public receivedBonds;
    bool public reentrySucceeded;
    bool public activationSucceeded;
    bool public replaySucceeded;
    bool public observedFunded;
    address public source;
    uint256 public sourceId;

    constructor(Migration parent_) { parent = parent_; }
    function reject(bool value_) external { rejectBond = value_; }
    function rejectSecond(bool value_) external { rejectSecondBond = value_; }
    function acceptOwnership() external { parent.acceptOwnershipTransfer(); }
    function surrender(address collection_, uint256 id_) external returns (uint256, uint256) {
        source = collection_; sourceId = id_;
        IERC721(collection_).approve(address(parent), id_);
        return parent.surrenderMigrationNft(collection_, id_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256 id_, bytes calldata) external returns (bytes4) {
        if (msg.sender == parent.bondNftVault()) {
            ++receivedBonds;
            Bonds bond_ = Bonds(msg.sender);
            MigrationReceipt receipt_ = MigrationReceipt(parent.rebasingClaimToken());
            observedFunded = bond_.isMigrationPosition(id_) && bond_.positionOf(id_).principal != 0
                && receipt_.gonsOf(msg.sender) >= bond_.positionOf(id_).stakingGons;
            require(observedFunded, "receiver must see funded marked position");
            (reentrySucceeded,) = address(parent).call(abi.encodeCall(
                Migration.surrenderMigrationNft, (source, sourceId, 0, block.timestamp)
            ));
            (activationSucceeded,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
            (replaySucceeded,) = address(parent).call(abi.encodeCall(
                IERC721Receiver.onERC721Received, (address(parent), address(this), sourceId, bytes(""))
            ));
            if (rejectBond || (rejectSecondBond && receivedBonds == 2)) return bytes4(0);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MigrationNftLifecycleTest is MigrationNftForkBase {
    function test_weightedNftThreeIssuesTwoIndependentlyFundedBondsOnOneSurrender() public {
        Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
        rows_[0] = _original(WEIGHTED, 3);
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(rows_);
        Migration.NftContribution[] memory parts_ = migration.nftContributions(WEIGHTED, 3);
        assertEq(parts_.length, 2);
        assertEq(parts_[0].originalEth, 999999000000000);
        assertEq(parts_[0].originalDtf, 0);
        assertEq(parts_[1].originalEth, 0);
        assertEq(parts_[1].originalDtf, 362893857600000000000);
        assertEq(parts_[0].credit, migration.previewOriginalCredit(999999000000000, 0));
        assertEq(parts_[1].credit, migration.previewOriginalCredit(0, 362893857600000000000));
        assertNotEq(parts_[0].credit, parts_[1].credit);
        _activate();
        (uint256 remaining_, uint256[] memory credits_) = migration.previewNftContributionSurrender(WEIGHTED, 3);
        assertEq(credits_.length, 2);
        for (uint256 i_; i_ < 2; ++i_) {
            assertEq(credits_[i_], Math.mulDiv(parts_[i_].credit, remaining_, rows_[0].originalUnits));
        }
        (, uint256 scalar_) = migration.previewNftSurrender(WEIGHTED, 3);
        assertEq(scalar_, credits_[0] + credits_[1]);
        address wallet_ = rows_[0].originalWallet;
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(wallet_);
        IERC721(WEIGHTED).approve(detf, 3);
        (uint256 first_, uint256 paid_) = migration.surrenderMigrationNft(WEIGHTED, 3, scalar_, block.timestamp);
        vm.stopPrank();
        Migration.NftContributionSurrender[] memory issued_ = migration.nftContributionSurrenders(WEIGHTED, 3);
        assertEq(issued_.length, 2);
        assertEq(issued_[0].bondTokenId, first_);
        assertEq(issued_[1].bondTokenId, first_ + 1);
        uint256 gons_;
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 id_ = issued_[i_].bondTokenId;
            assertEq(issued_[i_].credit, credits_[i_]);
            assertEq(bonds.positionOf(id_).principal, credits_[i_]);
            assertEq(bonds.positionOf(id_).startTimestamp, block.timestamp);
            assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
            assertTrue(bonds.isMigrationPosition(id_));
            assertEq(IERC721(address(bonds)).ownerOf(id_), wallet_);
            assertEq(bonds.previewClaim(id_).principalDue, 0);
            gons_ += bonds.positionOf(id_).stakingGons;
        }
        assertEq(paid_, scalar_);
        assertEq(IERC20(detf).totalSupply(), supply_ + paid_);
        assertEq(receipt.stakingState().accountedBacking, initialBacking + paid_);
        assertEq(receipt.gonsOf(address(bonds)), initialBondGons + gons_);
        assertEq(receipt.stakingState().totalGons, initialTotalGons + gons_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + paid_);
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
        assertEq(IERC721(WEIGHTED).ownerOf(3), detf);
        assertTrue(migration.nftSurrender(WEIGHTED, 3).consumed);
        assertEq(migration.nftSurrender(WEIGHTED, 3).credit, paid_);
        assertEq(migration.nftSurrender(WEIGHTED, 3).bondTokenId, first_);
        assertEq(migration.nftCustody(WEIGHTED, 3).configurationId,
            migration.nftEntitlement(WEIGHTED, 3).configurationId);
        vm.prank(wallet_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, WEIGHTED, 3));
        migration.surrenderMigrationNft(WEIGHTED, 3, 0, block.timestamp);
        assertEq(migration.nftContributionSurrenders(WEIGHTED, 3).length, 2);
        vm.warp(block.timestamp + 90 days);
        assertEq(bonds.previewClaim(first_).principalDue, credits_[0]);
        assertEq(bonds.previewClaim(first_ + 1).principalDue, credits_[1]);
    }

    function test_twoOriginalsApplyRemainingPrincipalToEachFrozenCredit() public {
        Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
        rows_[0] = _original(WEIGHTED, 32);
        // Synthetic second original isolates fractional arithmetic on a real partially claimed NFT.
        rows_[0].originalEth = 999999000000000;
        rows_[0].evidenceId = keccak256("two-original partial-principal fixture");
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(rows_);
        IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(WEIGHTED).positionOf(32);
        assertGt(p_.claimedPrincipal, 0);
        uint256 remaining_ = p_.principal - p_.claimedPrincipal;
        uint256 eth_ = Math.mulDiv(migration.previewOriginalCredit(rows_[0].originalEth, 0), remaining_, p_.principal);
        uint256 dtf_ = Math.mulDiv(migration.previewOriginalCredit(0, rows_[0].originalDtf), remaining_, p_.principal);
        _activate();
        (uint256 previewRemaining_, uint256[] memory credits_) = migration.previewNftContributionSurrender(WEIGHTED, 32);
        assertEq(previewRemaining_, remaining_);
        assertEq(credits_[0], eth_);
        assertEq(credits_[1], dtf_);
        vm.startPrank(rows_[0].originalWallet);
        IERC721(WEIGHTED).approve(detf, 32);
        (uint256 first_, uint256 paid_) = migration.surrenderMigrationNft(WEIGHTED, 32, eth_ + dtf_, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, eth_ + dtf_);
        assertEq(bonds.positionOf(first_).principal, eth_);
        assertEq(bonds.positionOf(first_ + 1).principal, dtf_);
        assertEq(migration.nftSurrender(WEIGHTED, 32).remainingUnits, remaining_);
    }

    function test_secondContributionReceiverFailureRollsBackBothBondsAndWholeNft() public {
        MigrationNftHolder holder_ = new MigrationNftHolder(migration);
        Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
        rows_[0] = _original(WEIGHTED, 3);
        // Synthetic eligible contract wallet exercises the actual funded NFT receiver boundary.
        rows_[0].originalWallet = address(holder_);
        rows_[0].evidenceId = keccak256("two-original rejecting receiver fixture");
        vm.prank(migrationOwner);
        allocation.configureNftContributionEntitlements(rows_);
        address old_ = IERC721(WEIGHTED).ownerOf(3);
        vm.prank(old_);
        IERC721(WEIGHTED).safeTransferFrom(old_, address(holder_), 3);
        _activate();
        holder_.rejectSecond(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 attributed_ = bonds.attributedBondGons();
        uint256 first_ = migration.migrationOwnerFirstBondTokenId() + 1;
        bytes memory config_ = abi.encode(migration.nftContributions(WEIGHTED, 3));
        // The exact second NFT callback must be reached; a first-issuance failure is not this regression.
        vm.expectCall(address(holder_), abi.encodeCall(
            IERC721Receiver.onERC721Received, (detf, address(0), first_ + 1, bytes(""))
        ));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(holder_)));
        holder_.surrender(WEIGHTED, 3);
        _assertNotConsumed(WEIGHTED, 3, address(holder_), supply_);
        assertEq(holder_.receivedBonds(), 0);
        assertEq(migration.nftContributionSurrenders(WEIGHTED, 3).length, 0);
        assertEq(abi.encode(migration.nftContributions(WEIGHTED, 3)), config_);
        assertEq(bonds.attributedBondGons(), attributed_);
        assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
        assertEq(IERC721(address(bonds)).ownerOf(first_), address(0));
        assertEq(IERC721(address(bonds)).ownerOf(first_ + 1), address(0));
        assertFalse(bonds.isMigrationPosition(first_));
        assertFalse(bonds.isMigrationPosition(first_ + 1));
        assertEq(IERC20(detf).balanceOf(address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
        assertEq(IERC721(WEIGHTED).getApproved(3), address(0));
        holder_.rejectSecond(false);
        (uint256 retried_, uint256 credit_) = holder_.surrender(WEIGHTED, 3);
        assertEq(retried_, first_);
        assertEq(holder_.receivedBonds(), 2);
        assertEq(IERC721(WEIGHTED).ownerOf(3), detf);
        assertEq(bonds.positionOf(first_).principal + bonds.positionOf(first_ + 1).principal, credit_);
        assertFalse(holder_.reentrySucceeded());
        assertFalse(holder_.activationSucceeded());
        assertFalse(holder_.replaySucceeded());
    }

    function test_removedLoadersCannotResizeReopenOrCreateDescendantCredit() public {
        uint256 c0_ = _configureNft(WEIGHTED, 32);
        _activate();
        (uint256 id_, uint256 paid_) = _surrender(WEIGHTED, 32);
        assertLt(paid_, c0_);
        bytes memory history_ = abi.encode(migration.nftSurrender(WEIGHTED, 32));
        bytes memory custody_ = abi.encode(migration.nftCustody(WEIGHTED, 32));
        bytes memory bond_ = abi.encode(bonds.positionOf(id_));
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
        a_[0] = _original(WEIGHTED, 32);
        a_[0].originalDtf *= 2;
        a_[0].originalWallet = makeAddr("corrected consumed wallet");
        bytes32 configuration_ = migration.nftEntitlement(WEIGHTED, 32).configurationId;
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (a_)));
        assertFalse(corrected_);
        a_[0] = _original(WEIGHTED, 32);
        vm.prank(migrationOwner);
        (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureNftEntitlements, (a_)));
        assertFalse(replayed_);
        assertEq(migration.nftEntitlement(WEIGHTED, 32).configurationId, configuration_);
        assertEq(abi.encode(migration.nftSurrender(WEIGHTED, 32)), history_);
        assertEq(abi.encode(migration.nftCustody(WEIGHTED, 32)), custody_);
        assertEq(abi.encode(bonds.positionOf(id_)), bond_);
        assertEq(IERC721(WEIGHTED).ownerOf(32), detf);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, WEIGHTED, 32));
        migration.surrenderMigrationNft(WEIGHTED, 32, 0, block.timestamp);
        bytes32 origin_ = migration.migrationNftOriginalId(WEIGHTED, 32);
        Migration.IndependentAllocationInput[] memory independent_ = new Migration.IndependentAllocationInput[](1);
        independent_[0].recipient = address(this);
        independent_[0].entitlements = new Migration.OriginalEntitlement[](1);
        independent_[0].entitlements[0] = Migration.OriginalEntitlement(origin_, 1 ether, 0, bytes32("duplicate"));
        vm.prank(migrationOwner);
        (bool independentOk_,) = detf.call(abi.encodeCall(Allocation.configureIndependentAllocations, (independent_)));
        assertFalse(independentOk_);
        assertFalse(migration.independentIssuance(address(this)).issued);
    }

    function test_bothRoutesRemainUsableAfterActivationWithFreshLateClocks() public {
        _configureNft(WEIGHTED, 4);
        _configureNft(EARLIER, 4);
        _configureNft(WEIGHTED, 26);
        _configureNft(EARLIER, 3);
        _configure(address(this), 1 ether, bytes32("independent clock"));
        uint256 independent_ = _issue(address(this));
        uint256 firstStart_ = vm.getBlockTimestamp();
        _activate();
        (uint256 first_,) = _surrender(WEIGHTED, 4);
        (uint256 second_,) = _surrender(EARLIER, 4);
        vm.warp(firstStart_ + 120 days);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureNftEntitlements.selector), address(0));
        _returnToOriginal(WEIGHTED, 26);
        (uint256 third_,) = _surrender(WEIGHTED, 26);
        (uint256 fourth_,) = _surrender(EARLIER, 3);
        assertNotEq(first_, second_); assertNotEq(second_, third_); assertNotEq(third_, fourth_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstStart_);
        assertEq(bonds.positionOf(second_).startTimestamp, firstStart_);
        assertEq(bonds.positionOf(independent_).startTimestamp, firstStart_);
        assertEq(bonds.positionOf(third_).startTimestamp, firstStart_ + 120 days);
        assertEq(bonds.positionOf(fourth_).startTimestamp, firstStart_ + 120 days);
        assertEq(bonds.previewClaim(third_).principalDue, 0);
        assertEq(bonds.previewClaim(fourth_).principalDue, 0);
        vm.warp(firstStart_ + 210 days - 1);
        assertEq(bonds.previewClaim(third_).principalDue, 0);
        vm.warp(firstStart_ + 210 days);
        assertEq(bonds.previewClaim(third_).principalDue, bonds.positionOf(third_).principal);
        assertEq(bonds.previewClaim(fourth_).principalDue, bonds.positionOf(fourth_).principal);
    }

    function test_contractReceiverFailureRollsBackCustodySupplyFundingAndConsumption() public {
        _receiverRollback(WEIGHTED);
    }

    function test_earlierContractReceiverFailureRollsBackCustodySupplyFundingAndConsumption() public {
        _receiverRollback(EARLIER);
    }

    function _receiverRollback(address collection_) private {
        MigrationNftHolder holder_ = new MigrationNftHolder(migration);
        _configureReceiver(collection_, 4, address(holder_));
        _activate();
        address old_ = IERC721(collection_).ownerOf(4);
        vm.prank(old_);
        IERC721(collection_).safeTransferFrom(old_, address(holder_), 4);
        holder_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        bytes memory config_ = abi.encode(migration.nftEntitlement(collection_, 4));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(holder_)));
        holder_.surrender(collection_, 4);
        _assertNotConsumed(collection_, 4, address(holder_), supply_);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        assertEq(abi.encode(migration.nftEntitlement(collection_, 4)), config_);
        assertEq(IERC721(collection_).getApproved(4), address(0));
        holder_.reject(false);
        (uint256 id_, uint256 paid_) = holder_.surrender(collection_, 4);
        assertEq(id_, migration.migrationOwnerFirstBondTokenId() + 1);
        assertEq(bonds.positionOf(id_).principal, paid_);
        assertTrue(holder_.observedFunded());
        assertEq(IERC721(collection_).ownerOf(4), detf);
    }

    /// @dev Explicit synthetic receiver entitlement exercises callbacks, not historical purchaser provenance.
    function _configureReceiver(address collection_, uint256 id_, address wallet_) private {
        Migration.NftEntitlementInput[] memory rows_ = new Migration.NftEntitlementInput[](1);
        rows_[0] = _original(collection_, id_);
        rows_[0].originalWallet = wallet_;
        rows_[0].evidenceId = keccak256("synthetic contract-wallet callback fixture");
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(rows_);
    }

    function test_insufficientExecutionGasInsideRealFundingRollsBackWholeSurrender() public {
        uint256 c0_ = _configureNft(EARLIER, 4);
        _activate();
        address holder_ = IERC721(EARLIER).ownerOf(4);
        vm.prank(holder_);
        IERC721(EARLIER).approve(detf, 4);
        uint256 supply_ = IERC20(detf).totalSupply();
        // Exercise actual child acquisition failure, without etching/mocking a child or
        // fabricating a deficient balance. Exact call expectation proves funding was reached.
        vm.expectCall(address(receipt), abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            IERC20(detf), c0_, IERC20(address(receipt)), c0_, address(bonds), false, block.timestamp
        )), uint64(2));
        vm.prank(holder_);
        (bool ok_,) = detf.call{gas: 900000}(abi.encodeCall(
            Migration.surrenderMigrationNft, (EARLIER, 4, 1, block.timestamp)
        ));
        assertFalse(ok_);
        _assertNotConsumed(EARLIER, 4, holder_, supply_);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        assertEq(IERC20(detf).balanceOf(address(bonds)), 0);
        assertEq(IERC721(EARLIER).getApproved(4), detf);
        _surrender(EARLIER, 4);
    }

    function test_earlierContractHolderCallbackCannotReenterReplayOrActivate() public {
        MigrationNftHolder holder_ = new MigrationNftHolder(migration);
        _configureReceiver(EARLIER, 3, address(holder_));
        _activate();
        address old_ = IERC721(EARLIER).ownerOf(3);
        vm.prank(old_);
        IERC721(EARLIER).safeTransferFrom(old_, address(holder_), 3);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(holder_));
        holder_.acceptOwnership();
        (uint256 id_, uint256 paid_) = holder_.surrender(EARLIER, 3);
        assertTrue(holder_.observedFunded());
        assertFalse(holder_.reentrySucceeded());
        assertFalse(holder_.activationSucceeded());
        assertFalse(holder_.replaySucceeded());
        assertTrue(migration.migrationActivated());
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(holder_));
        assertEq(bonds.positionOf(id_).principal, paid_);
        assertEq(migration.nftSurrender(EARLIER, 3).holder, address(holder_));
    }

    function test_separateRealInstancesHaveSeparateDomainsButCannotTakeHeldIdentityTwice() public {
        _configureNft(EARLIER, 3);
        Migration first_ = migration;
        address holder_ = IERC721(EARLIER).ownerOf(3);
        bytes32 firstOrigin_ = migration.migrationNftOriginalId(EARLIER, 3);
        _activate();
        _surrender(EARLIER, 3);
        address secondOwner_ = makeAddr("second migration owner");
        address second_ = _deployMigration(_migrationArgs(secondOwner_));
        migration = Migration(second_); allocation = Allocation(second_);
        migrationOwner = secondOwner_; detf = second_;
        receipt = MigrationReceipt(migration.rebasingClaimToken());
        bonds = Bonds(migration.bondNftVault());
        _fundHistoricalBook();
        _configureNft(EARLIER, 3);
        _activate();
        assertNotEq(migration.migrationNftOriginalId(EARLIER, 3), firstOrigin_);
        assertFalse(migration.nftSurrender(EARLIER, 3).consumed);
        vm.prank(holder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotNftHolder.selector, holder_, address(first_)));
        migration.surrenderMigrationNft(EARLIER, 3, 0, block.timestamp);
        assertEq(IERC721(EARLIER).ownerOf(3), address(first_));
        assertTrue(first_.nftSurrender(EARLIER, 3).consumed);
        assertFalse(migration.nftSurrender(EARLIER, 3).consumed);
        assertEq(receipt.stakingState().totalGons, initialTotalGons);
    }
}
