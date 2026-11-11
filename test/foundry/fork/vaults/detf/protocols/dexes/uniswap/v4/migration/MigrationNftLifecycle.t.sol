// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
    bool public reentrySucceeded;
    bool public activationSucceeded;
    bool public replaySucceeded;
    bool public observedFunded;
    address public source;
    uint256 public sourceId;

    constructor(Migration parent_) { parent = parent_; }
    function reject(bool value_) external { rejectBond = value_; }
    function acceptOwnership() external { parent.acceptOwnershipTransfer(); }
    function surrender(address collection_, uint256 id_) external returns (uint256, uint256) {
        source = collection_; sourceId = id_;
        IERC721(collection_).approve(address(parent), id_);
        return parent.surrenderMigrationNft(collection_, id_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256 id_, bytes calldata) external returns (bytes4) {
        if (msg.sender == parent.bondNftVault()) {
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
            if (rejectBond) return bytes4(0);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MigrationNftLifecycleTest is MigrationNftForkBase {
    function test_replacementAfterConsumptionCannotResizeReopenOrCreateDescendantCredit() public {
        uint256 c0_ = _configureNft(WEIGHTED, 32);
        (uint256 id_, uint256 paid_) = _surrender(WEIGHTED, 32);
        assertLt(paid_, c0_);
        bytes memory history_ = abi.encode(migration.nftSurrender(WEIGHTED, 32));
        bytes memory custody_ = abi.encode(migration.nftCustody(WEIGHTED, 32));
        bytes memory bond_ = abi.encode(bonds.positionOf(id_));
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
        a_[0] = _original(WEIGHTED, 32);
        a_[0].originalDtf *= 2;
        vm.startPrank(migrationOwner);
        allocation.configureNftEntitlements(a_);
        allocation.configureNftEntitlements(a_);
        vm.stopPrank();
        assertEq(abi.encode(migration.nftSurrender(WEIGHTED, 32)), history_);
        assertEq(abi.encode(migration.nftCustody(WEIGHTED, 32)), custody_);
        assertEq(abi.encode(bonds.positionOf(id_)), bond_);
        assertEq(IERC721(WEIGHTED).ownerOf(32), detf);
        vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, WEIGHTED, 32));
        migration.surrenderMigrationNft(WEIGHTED, 32, 0, block.timestamp);
        bytes32 origin_ = migration.migrationNftOriginalId(WEIGHTED, 32);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
        _configure(address(this), 1 ether, origin_);
        assertFalse(migration.independentIssuance(address(this)).issued);
    }

    function test_bothRoutesRemainUsableAfterActivationWithFreshLateClocks() public {
        _configureNft(WEIGHTED, 4);
        _configureNft(EARLIER, 4);
        _configureNft(WEIGHTED, 26);
        _configureNft(EARLIER, 3);
        uint256 firstStart_ = vm.getBlockTimestamp();
        (uint256 first_,) = _surrender(WEIGHTED, 4);
        (uint256 second_,) = _surrender(EARLIER, 4);
        vm.warp(firstStart_ + 120 days);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureNftEntitlements.selector), address(0));
        (uint256 third_,) = _surrender(WEIGHTED, 26);
        (uint256 fourth_,) = _surrender(EARLIER, 3);
        assertNotEq(first_, second_); assertNotEq(second_, third_); assertNotEq(third_, fourth_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstStart_);
        assertEq(bonds.positionOf(second_).startTimestamp, firstStart_);
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
        _configureNft(WEIGHTED, 4);
        MigrationNftHolder holder_ = new MigrationNftHolder(migration);
        address old_ = IERC721(WEIGHTED).ownerOf(4);
        vm.prank(old_);
        IERC721(WEIGHTED).safeTransferFrom(old_, address(holder_), 4);
        holder_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        bytes memory config_ = abi.encode(migration.nftEntitlement(WEIGHTED, 4));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(holder_)));
        holder_.surrender(WEIGHTED, 4);
        _assertNotConsumed(WEIGHTED, 4, address(holder_), supply_);
        assertEq(IERC721(address(bonds)).ownerOf(3), address(0));
        assertEq(abi.encode(migration.nftEntitlement(WEIGHTED, 4)), config_);
        assertEq(IERC721(WEIGHTED).getApproved(4), address(0));
        holder_.reject(false);
        (uint256 id_, uint256 paid_) = holder_.surrender(WEIGHTED, 4);
        assertEq(id_, 3);
        assertEq(bonds.positionOf(id_).principal, paid_);
        assertTrue(holder_.observedFunded());
        assertEq(IERC721(WEIGHTED).ownerOf(4), detf);
    }

    function test_insufficientExecutionGasInsideRealFundingRollsBackWholeSurrender() public {
        uint256 c0_ = _configureNft(EARLIER, 4);
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
        assertEq(IERC721(address(bonds)).ownerOf(3), address(0));
        assertEq(IERC20(detf).balanceOf(address(bonds)), 0);
        assertEq(IERC721(EARLIER).getApproved(4), detf);
        _surrender(EARLIER, 4);
    }

    function test_earlierContractHolderCallbackCannotReenterReplayOrActivate() public {
        _configureNft(EARLIER, 3);
        MigrationNftHolder holder_ = new MigrationNftHolder(migration);
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
        assertFalse(migration.migrationActivated());
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(holder_));
        assertEq(bonds.positionOf(id_).principal, paid_);
        assertEq(migration.nftSurrender(EARLIER, 3).holder, address(holder_));
    }

    function test_separateRealInstancesHaveSeparateDomainsButCannotTakeHeldIdentityTwice() public {
        _configureNft(EARLIER, 3);
        Migration first_ = migration;
        address holder_ = IERC721(EARLIER).ownerOf(3);
        bytes32 firstOrigin_ = migration.migrationNftOriginalId(EARLIER, 3);
        _surrender(EARLIER, 3);
        address secondOwner_ = makeAddr("second migration owner");
        address second_ = _deployMigration(_migrationArgs(secondOwner_));
        migration = Migration(second_); allocation = Allocation(second_);
        migrationOwner = secondOwner_; detf = second_;
        receipt = MigrationReceipt(migration.rebasingClaimToken());
        bonds = Bonds(migration.bondNftVault());
        _fundHistoricalBook();
        _configureNft(EARLIER, 3);
        assertNotEq(migration.migrationNftOriginalId(EARLIER, 3), firstOrigin_);
        assertFalse(migration.nftSurrender(EARLIER, 3).consumed);
        vm.prank(holder_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotNftHolder.selector, holder_, address(first_)));
        migration.surrenderMigrationNft(EARLIER, 3, 0, block.timestamp);
        assertEq(IERC721(EARLIER).ownerOf(3), address(first_));
        assertTrue(first_.nftSurrender(EARLIER, 3).consumed);
        assertFalse(migration.nftSurrender(EARLIER, 3).consumed);
        assertEq(receipt.stakingState().totalGons, 0);
    }
}
