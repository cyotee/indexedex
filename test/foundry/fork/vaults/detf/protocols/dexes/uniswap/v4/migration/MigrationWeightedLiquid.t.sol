// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Synthetic acquiring contract wallet; the source and funding system remain real.
contract WeightedLiquidReceiver is IERC721Receiver {
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
    function acceptOwnership() external { parent.acceptOwnershipTransfer(); }
    function surrender(uint256 q_) external returns (uint256, uint256) {
        source.approve(address(parent), q_);
        return parent.surrenderMigrationWeightedLiquid(origin, q_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (surrenderReentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationWeightedLiquid, (origin, 1, 0, block.timestamp)
        ));
        (activationReentered,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice W-L original quantities/components are synthetic, never derived from the holder's balance.
contract MigrationWeightedLiquidTest is MigrationRecoveryDonationForkBase {
    address constant HOLDER = address(bytes20(hex"082cb14f04d9c485473dedc00d604d7e9abca303"));
    bytes32 constant ORIGIN = keccak256("synthetic weighted liquid original");
    uint256 constant QUANTITY = 21225531;

    function _liquidInput(address wallet_, uint256 q_, uint256 eth_)
        private pure returns (Migration.WeightedLiquidEntitlementInput[] memory a_)
    {
        a_ = new Migration.WeightedLiquidEntitlementInput[](1);
        a_[0] = Migration.WeightedLiquidEntitlementInput(
            ORIGIN, wallet_, Legacy.WEIGHTED_DETF, q_, eth_, 0, keccak256("synthetic W-L input evidence"), true
        );
    }

    function _configureLiquid(address wallet_, uint256 q_) private returns (uint256) {
        Migration.WeightedLiquidEntitlementInput[] memory a_ = _liquidInput(wallet_, q_, 0.01 ether);
        vm.prank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(a_, pricingId);
        return migration.weightedLiquidEntitlement(ORIGIN).credit;
    }

    function _surrenderLiquid(uint256 q_) private returns (uint256 id_, uint256 credit_) {
        uint256 now_ = vm.getBlockTimestamp();
        vm.startPrank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationWeightedLiquid(ORIGIN, q_, 1, now_);
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
        uint256 sourceBefore_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 firstTime_ = vm.getBlockTimestamp();
        (uint256 first_, uint256 c1_) = _surrenderLiquid(1);
        assertEq(c1_, c0_ / 3);
        Migration.WeightedLiquidSurrender memory s_ = migration.weightedLiquidSurrender(ORIGIN);
        assertEq(s_.consumedUnits, 1);
        assertEq(s_.deliveredCredit, c1_);
        assertEq(s_.remainingUnits, 2);
        assertEq(s_.remainingCredit, c0_ - c1_);
        Migration.WeightedLiquidEntitlementInput[] memory a_ = _liquidInput(HOLDER, 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureWeightedLiquidEntitlements, (a_, pricingId)));
        assertFalse(replayed_);
        a_[0].originalUnits = 8;
        a_[0].originalEth = 0.02 ether;
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureWeightedLiquidEntitlements, (a_, pricingId)));
        assertFalse(corrected_);
        assertEq(abi.encode(migration.weightedLiquidSurrender(ORIGIN)), abi.encode(s_));
        vm.warp(firstTime_ + 30 days);
        uint256 expansion_ = migration.pendingExpansionDetf();
        assertEq(migration.synchronizeRewards(), expansion_);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c1_ + expansion_);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedLiquidEntitlements.selector), address(0));
        (uint256 second_, uint256 c2_) = _surrenderLiquid(1);
        assertEq(c2_, (c0_ - c1_) / 2);
        (uint256 third_, uint256 c3_) = _surrenderLiquid(1);
        assertEq(c1_ + c2_ + c3_, c0_);
        assertNotEq(first_, second_);
        assertNotEq(second_, third_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstTime_);
        assertEq(bonds.positionOf(third_).startTimestamp, firstTime_ + 30 days);
        assertEq(migration.weightedLiquidEntitlement(ORIGIN).credit, c0_);
        s_ = migration.weightedLiquidSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 0);
        assertEq(s_.remainingCredit, 0);
        assertEq(s_.consumedUnits, 3);
        assertEq(s_.deliveredCredit, c0_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER), sourceBefore_ - 3);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 3);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 3);
        // Account for actual elapsed expansion separately from surrender's exact delivered credit.
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c0_ + expansion_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + c0_ + expansion_);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedLiquidQuantity.selector, 1, 0));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, 0, block.timestamp);
    }

    function test_absentWrongWalletApprovalBalanceAndLimitsLeaveEverythingUnspent() public {
        uint256 balance_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER);
        uint256 supply_ = IERC20(detf).totalSupply();
        _configureLiquid(HOLDER, 3);
        Migration.WeightedLiquidEntitlementInput[] memory large_ = _liquidInput(HOLDER, balance_ + 1, 0.01 ether);
        large_[0].originalId = bytes32("balance");
        vm.prank(migrationOwner);
        allocation.configureWeightedLiquidEntitlements(large_, pricingId);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedLiquidEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationWeightedLiquid(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, 0);
        vm.expectCall(Legacy.WEIGHTED_DETF, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, 1)));
        vm.prank(HOLDER);
        (bool approvalOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedLiquid, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(approvalOk_);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, type(uint256).max);
        vm.expectCall(Legacy.WEIGHTED_DETF, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, balance_ + 1)));
        vm.prank(HOLDER);
        (bool balanceOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedLiquid, (bytes32("balance"), balance_ + 1, 0, block.timestamp)));
        assertFalse(balanceOk_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedLiquidWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedLiquidQuantity.selector, 0, 3));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 0, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, 0, block.timestamp - 1);
        uint256 quoted_ = migration.previewWeightedLiquidSurrender(ORIGIN, 1);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", quoted_ + 1, quoted_));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, quoted_ + 1, block.timestamp);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER), balance_);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 0);
        assertEq(migration.weightedLiquidSurrender(ORIGIN).consumedUnits, 0);
        assertEq(migration.weightedLiquidSurrender(bytes32("balance")).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
    }

    function test_transfersDoNotMoveCreditAndReturnNeedsNoHistory() public {
        _configureLiquid(HOLDER, 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).transfer(address(this), 3);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, 3);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedLiquidWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 3, 0, block.timestamp);
        IERC20(Legacy.WEIGHTED_DETF).transfer(HOLDER, 3);
        _surrenderLiquid(1);
        Migration.WeightedLiquidEntitlementInput[] memory a_ = _liquidInput(address(this), 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureWeightedLiquidEntitlements, (a_, pricingId)));
        assertFalse(corrected_);
        assertEq(migration.weightedLiquidEntitlement(ORIGIN).original.originalWallet, HOLDER);
        assertEq(migration.weightedLiquidSurrender(ORIGIN).consumedUnits, 1);
        _surrenderLiquid(2);
    }

    function test_zeroCreditDustRejectsWithoutConfiscation() public {
        _configureLiquid(HOLDER, type(uint256).max);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedLiquidEntitlement.selector, ORIGIN));
        migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, 0, block.timestamp);
        assertEq(migration.weightedLiquidSurrender(ORIGIN).consumedUnits, 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 0);
    }

    function test_bondReceiverRejectionRollsBackActualPullFundingAndInventory() public {
        WeightedLiquidReceiver wallet_ = new WeightedLiquidReceiver(migration, IERC20(Legacy.WEIGHTED_DETF), ORIGIN);
        uint256 credit_ = _configureLiquid(address(wallet_), 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).transfer(address(wallet_), 3);
        wallet_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(3);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(address(wallet_)), 3);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(address(wallet_), detf), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(migration.weightedLiquidSurrender(ORIGIN).deliveredCredit, 0);
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

    function test_directInventoryStagedConversionDonationAndUnbookedFloors() public {
        _configureLiquid(HOLDER, QUANTITY);
        _activate();
        (uint256 bond_,) = _surrenderLiquid(QUANTITY);
        bytes32 protected_ = _protected(bond_);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).transfer(detf, 7);
        IERC20(Legacy.DTF).transfer(detf, 7 ether);
        uint256 beforeDtf_ = IERC20(Legacy.DTF).balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector,
            Legacy.WEIGHTED_DETF, QUANTITY + 1, QUANTITY));
        _run(Recovery.Stage.WeightedConvert, 0, QUANTITY + 1, 1);
        _run(Recovery.Stage.WeightedConvert, 0, QUANTITY / 2, 1);
        uint256 output_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertGt(output_, 0);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), QUANTITY - QUANTITY / 2 + 7);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(detf, Legacy.WEIGHTED_DETF), 0);
        _run(Recovery.Stage.WeightedConvert, 0, QUANTITY - QUANTITY / 2, 1);
        output_ = recovery.migrationRecoveryInventory(Legacy.DTF);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 7);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), output_ + beforeDtf_);
        _run(Recovery.Stage.Donate, 0, 1 ether, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), output_ - 1 ether);
        assertGe(IERC20(Legacy.DTF).balanceOf(detf), output_ + 7 ether);
        assertEq(migration.migrationDonationInventory(IERC20(Legacy.DTF)), 1 ether);
        assertEq(_protected(bond_), protected_);
        vm.expectRevert(abi.encodeWithSelector(Recovery.RecoveryInventoryInsufficient.selector, Legacy.WEIGHTED_DETF, 1, 0));
        _run(Recovery.Stage.WeightedConvert, 0, 1, 1);
    }

    function test_stageOneRejectsBeforeAllowanceCustodyConsumptionOrFunding() public {
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 held_ = IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_DETF).approve(detf, 3);
        for (uint256 stage_; stage_ < 2; ++stage_) {
            if (stage_ == 1) _configureLiquid(HOLDER, 3);
            bytes memory config_ = abi.encode(migration.weightedLiquidEntitlement(ORIGIN));
            bytes memory state_ = abi.encode(migration.weightedLiquidSurrender(ORIGIN));
            vm.prank(HOLDER);
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            migration.surrenderMigrationWeightedLiquid(ORIGIN, 1, 0, block.timestamp);
            assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(HOLDER), held_);
            assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(detf), 0);
            assertEq(IERC20(Legacy.WEIGHTED_DETF).allowance(HOLDER, detf), 3);
            assertEq(abi.encode(migration.weightedLiquidEntitlement(ORIGIN)), config_);
            assertEq(abi.encode(migration.weightedLiquidSurrender(ORIGIN)), state_);
            assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), 0);
            assertEq(IERC20(detf).totalSupply(), supply_);
            assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
            assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
            assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        }
        _activate();
        _surrenderLiquid(3);
    }
}
