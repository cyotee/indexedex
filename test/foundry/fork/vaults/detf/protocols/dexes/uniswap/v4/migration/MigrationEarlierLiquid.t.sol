// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";

/// @notice Synthetic acquiring contract wallet; the source and funding system remain real.
contract EarlierLiquidReceiver is IERC721Receiver {
    Migration immutable parent;
    IERC20 immutable source;
    bytes32 immutable origin;
    bool public rejectBond;
    bool public surrenderReentered;
    bool public activationReentered;
    constructor(Migration parent_, IERC20 source_, bytes32 origin_) {
        parent = parent_; source = source_; origin = origin_;
    }
    function reject(bool value_) external { rejectBond = value_; }
    function approve(uint256 q_) external { source.approve(address(parent), q_); }
    function acceptOwnership() external { parent.acceptOwnershipTransfer(); }
    function surrender(uint256 q_) external returns (uint256, uint256) {
        source.approve(address(parent), q_);
        return parent.surrenderMigrationEarlierLiquid(origin, q_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (surrenderReentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationEarlierLiquid, (origin, 1, 0, block.timestamp)
        ));
        (activationReentered,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice ED original quantities/components are synthetic, never derived from the holder's balance.
contract MigrationEarlierLiquidTest is MigrationRecoveryDonationForkBase {
    address constant HOLDER = address(0xED);
    bytes32 constant ORIGIN = keccak256("synthetic earlier liquid original");
    uint256 constant QUANTITY = 21225531;

    function setUp() public override {
        super.setUp();
        address donor_ = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
        uint256 before_ = IERC20(Legacy.EARLIER_DETF).balanceOf(donor_);
        vm.prank(donor_); IERC20(Legacy.EARLIER_DETF).transfer(HOLDER, 1e24);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(donor_), before_ - 1e24);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER), 1e24);
    }

    function _liquidInput(address wallet_, uint256 q_, uint256 eth_)
        private pure returns (Migration.EarlierLiquidEntitlementInput[] memory a_)
    {
        a_ = new Migration.EarlierLiquidEntitlementInput[](1);
        a_[0] = Migration.EarlierLiquidEntitlementInput(
            ORIGIN, wallet_, Legacy.EARLIER_DETF, q_, eth_, 0, keccak256("synthetic ED input evidence"), true
        );
    }

    function _configureLiquid(address wallet_, uint256 q_) private returns (uint256) {
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _liquidInput(wallet_, q_, 0.01 ether);
        vm.prank(migrationOwner);
        allocation.configureEarlierLiquidEntitlements(a_);
        return migration.earlierLiquidEntitlement(ORIGIN).credit;
    }

    function _surrenderLiquid(uint256 q_) private returns (uint256 id_, uint256 credit_) {
        uint256 now_ = vm.getBlockTimestamp();
        vm.startPrank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationEarlierLiquid(ORIGIN, q_, 1, now_);
        vm.stopPrank();
        assertEq(IERC721(address(bonds)).ownerOf(id_), HOLDER);
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).startTimestamp, now_);
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * receipt.stakingState().gonsPerUnit);
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    function test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds() public {
        uint256 c0_ = _configureLiquid(HOLDER, 3);
        _activate();
        uint256 sourceBefore_ = IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 firstTime_ = vm.getBlockTimestamp();
        (uint256 first_, uint256 c1_) = _surrenderLiquid(1);
        assertEq(c1_, c0_ / 3);
        Migration.EarlierLiquidSurrender memory s_ = migration.earlierLiquidSurrender(ORIGIN);
        assertEq(s_.consumedUnits, 1);
        assertEq(s_.deliveredCredit, c1_);
        assertEq(s_.remainingUnits, 2);
        assertEq(s_.remainingCredit, c0_ - c1_);
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _liquidInput(HOLDER, 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureEarlierLiquidEntitlements, (a_)));
        assertFalse(replayed_);
        a_[0].originalUnits = 8;
        a_[0].originalEth = 0.02 ether;
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureEarlierLiquidEntitlements, (a_)));
        assertFalse(corrected_);
        assertEq(abi.encode(migration.earlierLiquidSurrender(ORIGIN)), abi.encode(s_));
        vm.warp(firstTime_ + 30 days);
        uint256 expansion_ = migration.pendingExpansionDetf();
        assertEq(migration.synchronizeRewards(), expansion_);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c1_ + expansion_);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureEarlierLiquidEntitlements.selector), address(0));
        (uint256 second_, uint256 c2_) = _surrenderLiquid(1);
        assertEq(c2_, (c0_ - c1_) / 2);
        (uint256 third_, uint256 c3_) = _surrenderLiquid(1);
        assertEq(c1_ + c2_ + c3_, c0_);
        assertNotEq(first_, second_);
        assertNotEq(second_, third_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstTime_);
        assertEq(bonds.positionOf(third_).startTimestamp, firstTime_ + 30 days);
        assertEq(migration.earlierLiquidEntitlement(ORIGIN).credit, c0_);
        s_ = migration.earlierLiquidSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 0);
        assertEq(s_.remainingCredit, 0);
        assertEq(s_.consumedUnits, 3);
        assertEq(s_.deliveredCredit, c0_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER), sourceBefore_ - 3);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 3);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 3);
        // Account for actual elapsed expansion separately from surrender's exact delivered credit.
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c0_ + expansion_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + c0_ + expansion_);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidQuantity.selector, 1, 0));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp);
    }

    function test_absentWrongWalletApprovalBalanceAndLimitsLeaveEverythingUnspent() public {
        uint256 balance_ = IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER);
        uint256 supply_ = IERC20(detf).totalSupply();
        _configureLiquid(HOLDER, 3);
        Migration.EarlierLiquidEntitlementInput[] memory large_ = _liquidInput(HOLDER, balance_ + 1, 0.01 ether);
        large_[0].originalId = bytes32("balance");
        vm.prank(migrationOwner);
        allocation.configureEarlierLiquidEntitlements(large_);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationEarlierLiquid(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).approve(detf, 0);
        vm.expectCall(Legacy.EARLIER_DETF, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, 1)));
        vm.prank(HOLDER);
        (bool approvalOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationEarlierLiquid, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(approvalOk_);
        vm.prank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).approve(detf, type(uint256).max);
        vm.expectCall(Legacy.EARLIER_DETF, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, balance_ + 1)));
        vm.prank(HOLDER);
        (bool balanceOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationEarlierLiquid, (bytes32("balance"), balance_ + 1, 0, block.timestamp)));
        assertFalse(balanceOk_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalEarlierLiquidWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidQuantity.selector, 0, 3));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 0, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp - 1);
        uint256 quoted_ = migration.previewEarlierLiquidSurrender(ORIGIN, 1);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", quoted_ + 1, quoted_));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, quoted_ + 1, block.timestamp);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER), balance_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
        assertEq(migration.earlierLiquidSurrender(ORIGIN).consumedUnits, 0);
        assertEq(migration.earlierLiquidSurrender(bytes32("balance")).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
    }

    function test_transfersDoNotMoveCreditAndReturnNeedsNoHistory() public {
        _configureLiquid(HOLDER, 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).transfer(address(this), 3);
        IERC20(Legacy.EARLIER_DETF).approve(detf, 3);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalEarlierLiquidWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 3, 0, block.timestamp);
        IERC20(Legacy.EARLIER_DETF).transfer(HOLDER, 3);
        _surrenderLiquid(1);
        Migration.EarlierLiquidEntitlementInput[] memory a_ = _liquidInput(address(this), 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureEarlierLiquidEntitlements, (a_)));
        assertFalse(corrected_);
        assertEq(migration.earlierLiquidEntitlement(ORIGIN).original.originalWallet, HOLDER);
        assertEq(migration.earlierLiquidSurrender(ORIGIN).consumedUnits, 1);
        _surrenderLiquid(2);
    }

    function test_zeroCreditDustRejectsWithoutConfiscation() public {
        _configureLiquid(HOLDER, type(uint256).max);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierLiquidEntitlement.selector, ORIGIN));
        migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp);
        assertEq(migration.earlierLiquidSurrender(ORIGIN).consumedUnits, 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
    }

    function test_bondReceiverRejectionRollsBackActualPullFundingAndInventory() public {
        EarlierLiquidReceiver wallet_ = new EarlierLiquidReceiver(migration, IERC20(Legacy.EARLIER_DETF), ORIGIN);
        uint256 credit_ = _configureLiquid(address(wallet_), 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).transfer(address(wallet_), 3);
        wallet_.approve(3);
        wallet_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(3);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(address(wallet_)), 3);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
        // The earlier completed approval persists; only operation effects roll back.
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(address(wallet_), detf), 3);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 0);
        assertEq(migration.earlierLiquidSurrender(ORIGIN).deliveredCredit, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        wallet_.reject(false);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(wallet_));
        wallet_.acceptOwnership();
        (uint256 id_, uint256 delivered_) = wallet_.surrender(3);
        assertEq(delivered_, credit_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(wallet_));
        assertFalse(wallet_.surrenderReentered());
        assertFalse(wallet_.activationReentered());
        assertTrue(migration.migrationActivated());
    }

    function test_stageOneRejectsBeforeAllowanceCustodyConsumptionOrFunding() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 held_ = IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER);
        vm.prank(HOLDER);
        IERC20(Legacy.EARLIER_DETF).approve(detf, 3);
        for (uint256 stage_; stage_ < 2; ++stage_) {
            if (stage_ == 1) _configureLiquid(HOLDER, 3);
            bytes memory config_ = abi.encode(migration.earlierLiquidEntitlement(ORIGIN));
            bytes memory state_ = abi.encode(migration.earlierLiquidSurrender(ORIGIN));
            vm.prank(HOLDER);
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            migration.surrenderMigrationEarlierLiquid(ORIGIN, 1, 0, block.timestamp);
            assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(HOLDER), held_);
            assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
            assertEq(IERC20(Legacy.EARLIER_DETF).allowance(HOLDER, detf), 3);
            assertEq(abi.encode(migration.earlierLiquidEntitlement(ORIGIN)), config_);
            assertEq(abi.encode(migration.earlierLiquidSurrender(ORIGIN)), state_);
            assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 0);
            assertEq(IERC20(detf).totalSupply(), supply_);
            assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
            assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
            assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        }
        _activate();
        _surrenderLiquid(3);
    }

    function test_nftRewardEdUnrelatedEdAndBothErLedgersRemainProtected() public {
        _configureLiquid(HOLDER, 3);
        _configureNft(EARLIER, 3);
        vm.prank(address(0xBEdf78eB17A054D972c85cE222E2175F19899CD6));
        IERC20(Legacy.EARLIER_RECEIPT).transfer(HOLDER, 10000);
        Migration.EarlierReceiptEntitlementInput[] memory er_ = new Migration.EarlierReceiptEntitlementInput[](1);
        er_[0] = Migration.EarlierReceiptEntitlementInput(
            bytes32("distinct ER original"), HOLDER, Legacy.EARLIER_RECEIPT,
            uint256(10000) * 1e27 / 2197, 0.01 ether, 0, bytes32("synthetic ER components"), true
        );
        vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(er_);
        _activate();
        _surrender(EARLIER, 3);
        _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
        uint256 nftEd_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF);
        assertGt(nftEd_, 0);
        vm.startPrank(HOLDER);
        IERC20(Legacy.EARLIER_RECEIPT).approve(detf, 4);
        migration.surrenderMigrationEarlierReceipt(bytes32("distinct ER original"), 4, 1, block.timestamp);
        IERC20(Legacy.EARLIER_DETF).transfer(detf, 7);
        vm.stopPrank();
        vm.warp(IMigrationEarlierNft(EARLIER).getPosition(3).unlockTime);
        _run(Recovery.Stage.EarlierSale, 3, 0, 1);
        uint256 e_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT);
        uint256 b_ = recovery.migrationEarlierReceiptInternalShares();
        uint256 erHeld_ = IERC20(Legacy.EARLIER_RECEIPT).balanceOf(detf);
        assertGt(e_, 0); assertGt(b_, 0);
        (uint256 id_,) = _surrenderLiquid(3);
        bytes32 protected_ = _protected(id_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), nftEd_ + 3);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), nftEd_ + 10);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT), e_);
        assertEq(recovery.migrationEarlierReceiptInternalShares(), b_);
        assertEq(IERC20(Legacy.EARLIER_RECEIPT).balanceOf(detf), erHeld_);
        // Weighted conversion cannot spend the separate ED recovery budget.
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.WEIGHTED_DETF, 1, 0));
        _run(Recovery.Stage.WeightedConvert, 0, 1, 1);
        assertEq(_protected(id_), protected_);
    }

    function test_actualEdBondsReleasePrincipalOnlyAtTheirFreshCliff() public {
        _configureLiquid(HOLDER, 3);
        _activate();
        (uint256 id_, uint256 credit_) = _surrenderLiquid(3);
        uint256 unlock_ = bonds.positionOf(id_).startTimestamp + 90 days;
        vm.warp(unlock_ - 1);
        vm.prank(HOLDER);
        assertEq(bonds.claimPrincipal(id_, HOLDER), 0);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        vm.warp(unlock_);
        vm.prank(HOLDER);
        assertEq(bonds.claimPrincipal(id_, HOLDER), credit_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, credit_);
    }

    function test_typedEarlierConversionReachesDisabledSourceAndRollsBack() public {
        uint256 q_ = 1e24;
        _configureLiquid(HOLDER, q_);
        _activate();
        (uint256 id_,) = _surrenderLiquid(q_);
        bytes32 protected_ = _protected(id_);
        uint256 held_ = IERC20(Legacy.EARLIER_DETF).balanceOf(detf);
        uint256 dtf_ = IERC20(Legacy.DTF).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", Legacy.EARLIER_SE));
        _run(Recovery.Stage.EarlierConvert, 0, q_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), q_);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), held_);
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(detf, Legacy.EARLIER_DETF), 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(detf, Legacy.EARLIER_LP), 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), dtf_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(id_), protected_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.EARLIER_DETF, q_ + 1, q_
        ));
        _run(Recovery.Stage.EarlierConvert, 0, q_ + 1, 0);
    }

    /// @dev Conditional local-fork witness only. The real legacy administrator enables
    /// its source through the real registry API; Migration receives no such authority.
    function test_typedEarlierConversionAfterLocalLegacyEnablement() public {
        uint256 q_ = 1e24;
        _configureLiquid(HOLDER, q_);
        _activate();
        (uint256 id_,) = _surrenderLiquid(q_);
        bytes32 protected_ = _protected(id_);
        address registry_ = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(registry_);
        (bool disabled_, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(Legacy.EARLIER_SE);
        assertTrue(disabled_);
        address administrator_ = IMultiStepOwnable(registry_).owner();
        assertNotEq(administrator_, detf);
        vm.startPrank(administrator_);
        if (byVault_) IVaultRegistryDisableManager(registry_).setVaultAddressDisabled(Legacy.EARLIER_SE, false);
        if (byPackage_) {
            IVaultRegistryDisableManager(registry_).setPackageDisabled(query_.packageOfVault(Legacy.EARLIER_SE), false);
        }
        vm.stopPrank();
        assertFalse(query_.isDisabled(Legacy.EARLIER_SE));
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 supply_ = IERC20(Legacy.EARLIER_DETF).totalSupply();
        _run(Recovery.Stage.EarlierConvert, 0, q_, 1);
        uint256 out_ = IERC20(Legacy.DTF).balanceOf(detf) - before_;
        assertGt(out_, 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).balanceOf(detf), 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(detf, Legacy.EARLIER_DETF), 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).allowance(detf, Legacy.EARLIER_LP), 0);
        assertEq(IERC20(Legacy.EARLIER_DETF).totalSupply(), supply_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        assertEq(_protected(id_), protected_);
        _run(Recovery.Stage.Donate, 0, out_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(id_), protected_);
    }
}
