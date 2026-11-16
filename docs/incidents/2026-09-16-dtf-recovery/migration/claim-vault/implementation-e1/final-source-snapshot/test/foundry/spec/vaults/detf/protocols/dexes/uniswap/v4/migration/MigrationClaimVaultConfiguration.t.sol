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

/// @notice Synthetic original allocations; actual direct-share custody is tested against pinned legacy bytecode.
contract MigrationClaimVaultConfigurationTest is TestBase_UniswapV4DetfMigration {
    address constant SE = 0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0;
    address constant NFT = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    bytes32 constant ORIGIN = bytes32("synthetic claim-vault original");

    function setUp() public override {
        vm.chainId(4663);
        super.setUp();
        _fundAndCapture();
    }

    function _inputs() private view returns (Migration.ClaimVaultEntitlementInput[] memory a_) {
        a_ = new Migration.ClaimVaultEntitlementInput[](1);
        a_[0] = Migration.ClaimVaultEntitlementInput(
            ORIGIN, address(this), SE, 3e19, 1 ether, 0, bytes32("synthetic original inputs"), true
        );
    }

    function test_unconsumedReplacementFreezesQuoteAndMintsNothing() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.ClaimVaultEntitlementInput[] memory a_ = _inputs();
        a_[0].originalUnits = 5e19;
        vm.startPrank(migrationOwner);
        allocation.configureClaimVaultEntitlements(a_);
        a_[0].originalEth = 0.6 ether;
        a_[0].originalUnits = 3e19;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureClaimVaultEntitlements(a_);
        allocation.configureClaimVaultEntitlements(a_);
        vm.stopPrank();
        Migration.ClaimVaultEntitlement memory c_ = migration.claimVaultEntitlement(ORIGIN);
        uint256 credit_ = migration.previewOriginalCredit(0.6 ether, 0);
        assertTrue(c_.configured);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, credit_);
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
        assertEq(migration.previewClaimVaultSurrender(ORIGIN, 1e19), credit_ / 3);
        assertEq(migration.previewClaimVaultSurrender(ORIGIN, 3e19), credit_);
        Migration.ClaimVaultSurrender memory s_ = migration.claimVaultSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 3e19);
        assertEq(s_.remainingCredit, credit_);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        vm.warp(block.timestamp + 1 days);
        assertEq(migration.previewClaimVaultSurrender(ORIGIN, 3e19), credit_);
    }

    function test_missingOriginalInputsAndWrongAuthorityRejectAtomically() public {
        Migration.ClaimVaultEntitlementInput[] memory a_ = _inputs();
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureClaimVaultEntitlements(a_);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _inputs();
            if (i_ == 0) a_[0].originalWallet = address(0);
            else if (i_ == 1) a_[0].originalUnits = 0;
            else if (i_ == 2) a_[0].contributionsKnown = false;
            else if (i_ == 3) a_[0].evidenceId = bytes32(0);
            else a_[0].originalId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidClaimVaultEntitlement.selector, a_[0].originalId));
            allocation.configureClaimVaultEntitlements(a_);
        }
        assertFalse(migration.claimVaultEntitlement(ORIGIN).configured);
        a_ = _inputs();
        a_[0].source = address(0xBAD);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedClaimVaultSource.selector, 4663, address(0xBAD)));
        allocation.configureClaimVaultEntitlements(a_);
        a_[0].source = SE;
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedClaimVaultSource.selector, 1, SE));
        allocation.configureClaimVaultEntitlements(a_);
    }

    function test_currentOwnerAndBadSecondRowPreserveCompleteConfiguration() public {
        Migration.ClaimVaultEntitlementInput[] memory a_ = _inputs();
        address next_ = makeAddr("next weighted owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureClaimVaultEntitlements(a_);
        vm.prank(next_);
        migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureClaimVaultEntitlements(a_);
        vm.prank(next_);
        allocation.configureClaimVaultEntitlements(a_);
        bytes memory before_ = abi.encode(migration.claimVaultEntitlement(ORIGIN));
        bytes memory remaining_ = abi.encode(migration.claimVaultSurrender(ORIGIN));
        Migration.ClaimVaultEntitlementInput[] memory batch_ = new Migration.ClaimVaultEntitlementInput[](2);
        batch_[0] = a_[0];
        batch_[0].originalUnits = 8e19;
        batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0];
        batch_[1].originalId = bytes32("bad second");
        batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidClaimVaultEntitlement.selector, batch_[1].originalId));
        allocation.configureClaimVaultEntitlements(batch_);
        assertEq(abi.encode(migration.claimVaultEntitlement(ORIGIN)), before_);
        assertEq(abi.encode(migration.claimVaultSurrender(ORIGIN)), remaining_);
        assertFalse(migration.claimVaultEntitlement(batch_[1].originalId).configured);
    }

    function test_sameCanonicalOriginCannotBeNftOrIndependentInEitherDirection() public {
        Migration.ClaimVaultEntitlementInput[] memory a_ = _inputs();
        a_[0].originalId = migration.migrationNftOriginalId(NFT, 3);
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(a_);
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
        allocation.configureClaimVaultEntitlements(a_);
        _configure(address(this), 1 ether, ORIGIN);
        _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        a_[0].originalId = ORIGIN;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureClaimVaultEntitlements(a_);
    }

    function test_activationRemovesNewLoadingAndRetainsExplicitMissingRecordRejection() public {
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(_inputs());
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureClaimVaultEntitlements.selector), address(0));
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationClaimVault.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.claimVaultEntitlement.selector), address(0));
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureClaimVaultEntitlements, (_inputs())));
        assertFalse(ok_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidClaimVaultEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationClaimVault(bytes32("absent"), 1, 0, block.timestamp);
        assertTrue(migration.claimVaultEntitlement(ORIGIN).configured);
        assertEq(migration.claimVaultSurrender(ORIGIN).consumedUnits, 0);
    }

    function test_canonicalCollisionWithWdAndEarlierNftSurvivesWalletCorrection() public {
        Migration.ClaimVaultEntitlementInput[] memory y_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(y_);
        y_[0].originalWallet = address(0xBEEF);
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(y_);
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
        allocation.configureClaimVaultEntitlements(y_);

        address earlier_ = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
        Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
        n_[0] = Migration.NftEntitlementInput(earlier_, 3, address(this), 3, 1 ether, 0, bytes32("earlier"), true);
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(n_);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 3);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureClaimVaultEntitlements(y_);
        y_[0].originalId = migration.migrationNftOriginalId(earlier_, 4);
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(y_);
        n_[0].tokenId = 4;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureNftEntitlements(n_);
    }
    function test_canonicalOriginCannotBeSyOrBackingAliasInEitherDirection() public {
        Migration.ClaimVaultEntitlementInput[] memory s_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(s_);
        Migration.WeightedSyEntitlementInput[] memory y_ = new Migration.WeightedSyEntitlementInput[](1);
        y_[0] = Migration.WeightedSyEntitlementInput(
            ORIGIN, address(0xBEEF), 0xB55604CF4dcdABB362078e106D20F98512391EdF,
            3, 1 ether, 0, bytes32("synthetic same origin"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureWeightedSyEntitlements(y_);
        y_[0].originalId = bytes32("other SY origin");
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(y_);
        s_[0].originalId = y_[0].originalId;
        s_[0].originalWallet = address(0xCAFE);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, y_[0].originalId));
        allocation.configureClaimVaultEntitlements(s_);
    }

    function test_canonicalOriginCannotBeDtfCustodySeInEitherDirection() public {
        Migration.ClaimVaultEntitlementInput[] memory c_ = _inputs();
        vm.prank(migrationOwner);
        allocation.configureClaimVaultEntitlements(c_);
        Migration.DtfCustodySeEntitlementInput[] memory d_ = new Migration.DtfCustodySeEntitlementInput[](1);
        d_[0] = Migration.DtfCustodySeEntitlementInput(
            ORIGIN, address(this), 0x2E9C1F705aB967c5Af59249203d7495bDabb223b,
            3e28, 1 ether, 0, bytes32("synthetic backing"), true
        );
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureDtfCustodySeEntitlements(d_);
        d_[0].originalId = bytes32("other custody origin");
        vm.prank(migrationOwner);
        allocation.configureDtfCustodySeEntitlements(d_);
        c_[0].originalId = d_[0].originalId;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, d_[0].originalId));
        allocation.configureClaimVaultEntitlements(c_);
    }
}

