// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as MigrationPackage}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";

/// @notice External contract owner/receiver, never a substitute issuer or child.
contract MigrationOwnerReceiver is IERC721Receiver {
    Migration immutable parent;
    bool public activationSucceeded;
    bool public reentrySucceeded;
    address public observedOwner;
    constructor(Migration parent_) { parent = parent_; }
    function accept() external { parent.acceptOwnershipTransfer(); }
    function activate() external { Allocation(address(parent)).activateMigration(); }
    function onERC721Received(address, address, uint256 id_, bytes calldata) external returns (bytes4) {
        observedOwner = IERC721(msg.sender).ownerOf(id_);
        (activationSucceeded,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        (reentrySucceeded,) = parent.rebasingClaimToken().call(abi.encodeCall(IERC20.transfer, (address(this), 0)));
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MigrationAdministrationTest is TestBase_UniswapV4DetfMigration {
    function test_pendingOwnerCannotAdministerButMayAcceptImmediately() public {
        _fundAndCapture();
        address next_ = makeAddr("next");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.activateMigration();
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        assertEq(migration.owner(), next_);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.activateMigration();
        _buyOwnerFirstBond();
        vm.prank(next_);
        allocation.activateMigration();
        assertTrue(migration.migrationActivated());
    }

    function test_zeroOwnerAndNoncanonicalArgumentsReject() public {
        MigrationPackage.PkgArgs memory args_ = _migrationArgs(address(0));
        args_.baseArgs.hook = migration.hook();
        vm.prank(owner);
        vm.expectRevert(MigrationPackage.InvalidMigrationPackageArguments.selector);
        migrationPkg.deployVault(args_);
        bytes memory malformed_ = bytes.concat(abi.encode(_migrationArgs(migrationOwner)), bytes32(uint256(1)));
        vm.expectRevert(MigrationPackage.InvalidMigrationPackageArguments.selector);
        migrationPkg.calcSalt(malformed_);
    }

    function test_eachOriginalQuotedSeparatelyAndStoredWithComponents() public {
        _fundAndCapture();
        Migration.IndependentAllocationInput[] memory input_ = new Migration.IndependentAllocationInput[](1);
        input_[0].recipient = address(this);
        input_[0].entitlements = new Migration.OriginalEntitlement[](2);
        input_[0].entitlements[0] = Migration.OriginalEntitlement(bytes32("a"), 1 ether, 0, bytes32("e1"));
        input_[0].entitlements[1] = Migration.OriginalEntitlement(bytes32("b"), 2 ether, 1 ether, bytes32("e2"));
        uint256 a_ = migration.previewOriginalCredit(1 ether, 0);
        uint256 b_ = migration.previewOriginalCredit(2 ether, 1 ether);
        vm.prank(migrationOwner);
        allocation.configureIndependentAllocations(input_);
        Migration.IndependentAllocation memory stored_ = migration.independentAllocation(address(this));
        assertEq(stored_.entitlements.length, 2);
        assertEq(stored_.entitlements[0].original.originalEth, 1 ether);
        assertEq(stored_.entitlements[1].original.originalDtf, 1 ether);
        assertEq(stored_.entitlements[0].credit, a_);
        assertEq(stored_.entitlements[1].credit, b_);
        assertEq(stored_.totalCredit, a_ + b_);
        assertNotEq(stored_.totalCredit, migration.previewOriginalCredit(3 ether, 1 ether));
    }

    function test_duplicateOriginalCannotMoveToAnotherRecipientAfterIssue() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("original"));
        _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        Migration.IndependentAllocationInput[] memory input_ = new Migration.IndependentAllocationInput[](1);
        input_[0].recipient = address(0xBEEF);
        input_[0].entitlements = new Migration.OriginalEntitlement[](1);
        input_[0].entitlements[0] = Migration.OriginalEntitlement(bytes32("original"), 1 ether, 1 ether, bytes32(0));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, bytes32("original")));
        allocation.configureIndependentAllocations(input_);
        assertEq(migration.independentAllocation(address(0xBEEF)).totalCredit, 0);
    }

    function test_badSecondIssuanceRollsBackWholeBatch() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("a"));
        _configure(address(0xBEEF), 1 ether, bytes32("b"));
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](2);
        requests_[0] = Migration.IndependentIssuanceRequest(address(this), migration.independentAllocation(address(this)).configurationId);
        requests_[1] = Migration.IndependentIssuanceRequest(address(0xBEEF), bytes32("stale"));
        bytes32 current_ = migration.independentAllocation(address(0xBEEF)).configurationId;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(
            Migration.IndependentConfigurationMismatch.selector, address(0xBEEF), bytes32("stale"),
            current_
        ));
        allocation.issueIndependentAllocations(requests_);
        assertFalse(migration.independentIssuance(address(this)).issued);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        assertEq(IERC20(detf).balanceOf(address(receipt)), 0);
    }

    function test_callbackOwnerCannotActivateOrReenterAnotherChild() public {
        _fundAndCapture();
        _buyOwnerFirstBond();
        _configure(address(this), 1 ether, bytes32("callback"));
        uint256 id_ = _issue(address(this));
        MigrationOwnerReceiver receiver_ = new MigrationOwnerReceiver(migration);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(receiver_));
        receiver_.accept();
        uint256 gons_ = receipt.gonsOf(address(bonds));
        IERC721(address(bonds)).safeTransferFrom(address(this), address(receiver_), id_);
        assertEq(receiver_.observedOwner(), address(this));
        assertFalse(receiver_.activationSucceeded());
        assertFalse(receiver_.reentrySucceeded());
        assertFalse(migration.migrationActivated());
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(receiver_));
        assertEq(receipt.gonsOf(address(bonds)), gons_);
        assertNotEq(IDiamondLoupe(detf).facetAddress(Allocation.activateMigration.selector), address(0));
        receiver_.activate();
        assertTrue(migration.migrationActivated());
    }

    function test_newParticipantGetsNoEarlierExpansion() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("first"));
        uint256 first_ = _issue(address(this));
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairA);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 50 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        _configure(address(0xBEEF), 1 ether, bytes32("second"));
        vm.warp(block.timestamp + 8 hours);
        uint256 pending_ = migration.pendingExpansionDetf();
        assertGt(pending_, 0);
        uint256 second_ = _issue(address(0xBEEF));
        assertGt(bonds.previewClaim(first_).rewardsDue, 0);
        assertEq(bonds.previewClaim(second_).rewardsDue, 0);
        assertEq(bonds.positionOf(second_).stakingGons,
            migration.independentIssuance(address(0xBEEF)).credit * receipt.stakingState().gonsPerUnit);
        assertEq(bonds.positionOf(second_).startTimestamp, block.timestamp);
    }
}
