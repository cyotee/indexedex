// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Each admitted source uses synthetic original records; real-source custody is covered in the pinned forks.
abstract contract MigrationHeldSeLpConfigurationTest is TestBase_UniswapV4DetfMigration {
    function _source() internal pure virtual returns (address);

    bytes32 constant ORIGIN = keccak256("synthetic original held SE LP native18");

    function setUp() public override { vm.chainId(4663); super.setUp(); _fundAndCapture(); }

    function _input(bytes32 origin_) private view returns (Migration.HeldSeLpEntitlementInput[] memory a_) {
        a_ = new Migration.HeldSeLpEntitlementInput[](1);
        a_[0] = Migration.HeldSeLpEntitlementInput(
            origin_, address(this), _source(), 2e18, 1 ether, 0, bytes32("original allocation"), true
        );
    }

    function test_completeReplacementReplayAndFrozenOriginalGroupingNeverIssue() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        Migration.HeldSeLpEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.startPrank(migrationOwner);
        allocation.configureHeldSeLpEntitlements(a_);
        a_[0].originalUnits = 1e18;
        a_[0].originalEth = 0.6 ether;
        a_[0].originalDtf = 0.1 ether;
        a_[0].originalWallet = address(0xBEEF);
        allocation.configureHeldSeLpEntitlements(a_);
        allocation.configureHeldSeLpEntitlements(a_);
        vm.stopPrank();
        Migration.HeldSeLpEntitlement memory c_ = migration.heldSeLpEntitlement(ORIGIN);
        assertEq(c_.original.originalUnits, 1e18);
        assertEq(c_.original.originalWallet, address(0xBEEF));
        assertEq(c_.credit, migration.previewOriginalCredit(0.6 ether, 0.1 ether));
        assertEq(c_.configurationId, keccak256(abi.encode(block.chainid, detf, migration.migrationSnapshot().id, a_[0])));
        Migration.HeldSeLpSurrender memory s_ = migration.heldSeLpSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 1e18);
        assertEq(s_.remainingCredit, c_.credit);
        assertEq(s_.consumedUnits, 0);
        assertEq(s_.deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    function test_invalidFieldsSourceChainAndOwnerRejectWholeBatch() public {
        Migration.HeldSeLpEntitlementInput[] memory a_ = _input(ORIGIN);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, address(this)));
        allocation.configureHeldSeLpEntitlements(a_);
        for (uint256 i_; i_ < 5; ++i_) {
            a_ = _input(ORIGIN);
            if (i_ == 0) a_[0].originalId = bytes32(0);
            else if (i_ == 1) a_[0].originalWallet = address(0);
            else if (i_ == 2) a_[0].originalUnits = 0;
            else if (i_ == 3) a_[0].contributionsKnown = false;
            else a_[0].evidenceId = bytes32(0);
            vm.prank(migrationOwner);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, a_[0].originalId));
            allocation.configureHeldSeLpEntitlements(a_);
        }
        a_ = _input(ORIGIN);
        a_[0].source = Legacy.WEIGHTED_RECEIPT;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedHeldSeLpSource.selector, 4663, a_[0].source));
        allocation.configureHeldSeLpEntitlements(a_);
        a_ = _input(ORIGIN);
        vm.chainId(1);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedHeldSeLpSource.selector, 1, a_[0].source));
        allocation.configureHeldSeLpEntitlements(a_);
        vm.chainId(4663);
        address next_ = makeAddr("ED next owner");
        vm.prank(migrationOwner); migration.initiateOwnershipTransfer(next_);
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, next_));
        allocation.configureHeldSeLpEntitlements(a_);
        vm.prank(next_); migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.configureHeldSeLpEntitlements(a_);
        vm.prank(next_); allocation.configureHeldSeLpEntitlements(a_);
        bytes memory before_ = abi.encode(migration.heldSeLpEntitlement(ORIGIN), migration.heldSeLpSurrender(ORIGIN));
        Migration.HeldSeLpEntitlementInput[] memory batch_ = new Migration.HeldSeLpEntitlementInput[](2);
        batch_[0] = a_[0]; batch_[0].originalEth = 2 ether;
        batch_[1] = a_[0]; batch_[1].originalId = bytes32("bad"); batch_[1].contributionsKnown = false;
        vm.prank(next_);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, bytes32("bad")));
        allocation.configureHeldSeLpEntitlements(batch_);
        assertEq(abi.encode(migration.heldSeLpEntitlement(ORIGIN), migration.heldSeLpSurrender(ORIGIN)), before_);
    }

    function _other(uint256 category_, bytes32 origin_) private {
        if (category_ == 0) { _configure(address(this), 1 ether, origin_); return; }
        if (category_ < 3) {
            Migration.NftEntitlementInput[] memory n_ = new Migration.NftEntitlementInput[](1);
            n_[0] = Migration.NftEntitlementInput(
                category_ == 1 ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                    : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391),
                3, address(this), 3, 1 ether, 0, bytes32("NFT"), true
            );
            vm.prank(migrationOwner); allocation.configureNftEntitlements(n_); return;
        }
        if (category_ >= 9) {
            Migration.HeldSeLpEntitlementInput[] memory held_ = _input(origin_);
            bytes4 selector_ = Allocation.configureEarlierLiquidEntitlements.selector;
            if (category_ == 9) held_[0].source = Legacy.EARLIER_DETF;
            else {
                address[3] memory fixed_ = [Legacy.WEIGHTED_WETH_SE, Legacy.EARLIER_LP, Legacy.WEIGHTED_LP];
                uint256 seen_;
                for (uint256 i_; i_ < 3; ++i_) if (fixed_[i_] != _source()) {
                    if (seen_++ == category_ - 10) { held_[0].source = fixed_[i_]; break; }
                }
                selector_ = Allocation.configureHeldSeLpEntitlements.selector;
            }
            vm.prank(migrationOwner);
            (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(selector_, held_));
            if (!ok_) assembly { revert(add(reason_, 32), mload(reason_)) }
            return;
        }
        bytes4[6] memory selectors_ = [
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureWeightedSyEntitlements.selector,
            Allocation.configureDtfCustodySeEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector, Allocation.configureEarlierReceiptEntitlements.selector
        ];
        address[6] memory sources_ = [
            Legacy.WEIGHTED_DETF, Legacy.WEIGHTED_SY, Legacy.DTF_CUSTODY_SE, Legacy.CLAIM_VAULT, Legacy.WEIGHTED_RECEIPT, Legacy.EARLIER_RECEIPT
        ];
        // These interface-owned original structs share an ABI tuple, not a unit.
        Migration.HeldSeLpEntitlementInput[] memory a_ = _input(origin_);
        a_[0].source = sources_[category_ - 3];
        vm.prank(migrationOwner);
        (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(selectors_[category_ - 3], a_));
        if (!ok_) assembly { revert(add(reason_, 32), mload(reason_)) }
    }

    function test_allCanonicalOriginsExcludeBothDirectionsAfterWalletCorrection() public {
        for (uint256 category_; category_ < 12; ++category_) {
            for (uint256 direction_; direction_ < 2; ++direction_) {
                uint256 snap_ = vm.snapshotState();
                bytes32 origin_ = category_ == 1 || category_ == 2
                    ? migration.migrationNftOriginalId(category_ == 1
                        ? address(0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E)
                        : address(0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391), 3) : ORIGIN;
                Migration.HeldSeLpEntitlementInput[] memory a_ = _input(origin_);
                if (direction_ == 0) {
                    vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(a_);
                    a_[0].originalWallet = address(0xBEEF);
                    vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(a_);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    _other(category_, origin_);
                } else {
                    _other(category_, origin_);
                    vm.prank(migrationOwner);
                    vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
                    allocation.configureHeldSeLpEntitlements(a_);
                }
                assertTrue(vm.revertToStateAndDelete(snap_));
            }
        }
        _configure(address(this), 1 ether, ORIGIN); _issue(address(this));
        _configure(address(this), 2 ether, bytes32("replacement"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, ORIGIN));
        allocation.configureHeldSeLpEntitlements(_input(ORIGIN));
    }

    function test_paidOwnerBondActivationRemovesLoaderAndRetainsRecordsAndQueries() public {
        vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(_input(ORIGIN));
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp);
        vm.prank(migrationOwner); vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner); allocation.activateMigration();
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureHeldSeLpEntitlements.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.surrenderMigrationHeldSeLp.selector), address(0));
        vm.prank(migrationOwner);
        (bool ok_,) = detf.call(abi.encodeCall(Allocation.configureHeldSeLpEntitlements, (_input(ORIGIN))));
        assertFalse(ok_);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingUnits, 2e18);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationHeldSeLp(bytes32("absent"), 1, 0, block.timestamp);
    }
    function test_fullPrecisionPreviewRetainsTerminalResidue() public {
        Migration.HeldSeLpEntitlementInput[] memory a_ = _input(ORIGIN);
        a_[0].originalUnits = type(uint256).max;
        vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(a_);
        uint256 c_ = migration.heldSeLpEntitlement(ORIGIN).credit;
        assertEq(migration.previewHeldSeLpSurrender(ORIGIN, type(uint256).max / 2), (c_ - 1) / 2);
        assertEq(migration.previewHeldSeLpSurrender(ORIGIN, type(uint256).max), c_);
    }

    function test_mixedFixedSourcesQuoteOriginalsSeparatelyAndRollbackInvalidLastRow() public {
        address[3] memory fixed_ = [Legacy.WEIGHTED_WETH_SE, Legacy.EARLIER_LP, Legacy.WEIGHTED_LP];
        Migration.HeldSeLpEntitlementInput[] memory a_ = new Migration.HeldSeLpEntitlementInput[](3);
        uint256 supply_ = IERC20(detf).totalSupply();
        for (uint256 i_; i_ < 3; ++i_) {
            a_[i_] = _input(bytes32(i_ + 1))[0];
            a_[i_].source = fixed_[i_];
            a_[i_].originalEth = (i_ + 1) * 0.1 ether;
        }
        a_[2].contributionsKnown = false;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, bytes32(uint256(3))));
        allocation.configureHeldSeLpEntitlements(a_);
        for (uint256 i_; i_ < 3; ++i_) assertFalse(migration.heldSeLpEntitlement(bytes32(i_ + 1)).configured);
        a_[2].contributionsKnown = true;
        vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(a_);
        uint256 credits_;
        for (uint256 i_; i_ < 3; ++i_) {
            uint256 c_ = migration.heldSeLpEntitlement(bytes32(i_ + 1)).credit;
            assertEq(c_, migration.previewOriginalCredit(a_[i_].originalEth, 0));
            credits_ += c_;
        }
        assertNotEq(credits_, migration.previewOriginalCredit(0.6 ether, 0));
        assertEq(IERC20(detf).totalSupply(), supply_);
    }

    function test_earlierSeIsUnsupportedNotAnotherAdmittedNative18Source() public {
        Migration.HeldSeLpEntitlementInput[] memory a_ = _input(ORIGIN);
        a_[0].source = address(bytes20(hex"b7d4bb379d361ad442cddee53ea71a33957826a7"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedHeldSeLpSource.selector, 4663, a_[0].source));
        allocation.configureHeldSeLpEntitlements(a_);
        assertFalse(migration.heldSeLpEntitlement(ORIGIN).configured);
    }
}

contract MigrationWeightedWethSeConfigurationTest is MigrationHeldSeLpConfigurationTest {
    function _source() internal pure override returns (address) { return Legacy.WEIGHTED_WETH_SE; }
}
contract MigrationEarlierLpConfigurationTest is MigrationHeldSeLpConfigurationTest {
    function _source() internal pure override returns (address) { return Legacy.EARLIER_LP; }
}
contract MigrationWeightedLpConfigurationTest is MigrationHeldSeLpConfigurationTest {
    function _source() internal pure override returns (address) { return Legacy.WEIGHTED_LP; }
}
