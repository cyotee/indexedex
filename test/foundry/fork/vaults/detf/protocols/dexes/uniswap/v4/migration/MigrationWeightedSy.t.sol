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
contract WeightedSyReceiver is IERC721Receiver {
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
        return parent.surrenderMigrationWeightedSy(origin, q_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (surrenderReentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationWeightedSy, (origin, 1, 0, block.timestamp)
        ));
        (activationReentered,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice W-Y original quantities/components are synthetic, never derived from the holder's balance.
contract MigrationWeightedSyTest is MigrationRecoveryDonationForkBase {
    address constant HOLDER = address(bytes20(hex"11c17f25e958e4637dd26ca362adeae12e24ed5b"));
    bytes32 constant ORIGIN = keccak256("synthetic weighted SY original");
    uint256 constant QUANTITY = 8094;

    function _syInput(address wallet_, uint256 q_, uint256 eth_)
        private pure returns (Migration.WeightedSyEntitlementInput[] memory a_)
    {
        a_ = new Migration.WeightedSyEntitlementInput[](1);
        a_[0] = Migration.WeightedSyEntitlementInput(
            ORIGIN, wallet_, Legacy.WEIGHTED_SY, q_, eth_, 0, keccak256("synthetic W-Y input evidence"), true
        );
    }

    function _configureSy(address wallet_, uint256 q_) private returns (uint256) {
        Migration.WeightedSyEntitlementInput[] memory a_ = _syInput(wallet_, q_, 0.01 ether);
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(a_);
        return migration.weightedSyEntitlement(ORIGIN).credit;
    }

    function _surrenderSy(uint256 q_) private returns (uint256 id_, uint256 credit_) {
        uint256 now_ = vm.getBlockTimestamp();
        vm.startPrank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationWeightedSy(ORIGIN, q_, 1, now_);
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
        uint256 c0_ = _configureSy(HOLDER, 3);
        _activate();
        uint256 sourceBefore_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 firstTime_ = vm.getBlockTimestamp();
        (uint256 first_, uint256 c1_) = _surrenderSy(1);
        assertEq(c1_, c0_ / 3);
        Migration.WeightedSySurrender memory s_ = migration.weightedSySurrender(ORIGIN);
        assertEq(s_.consumedUnits, 1);
        assertEq(s_.deliveredCredit, c1_);
        assertEq(s_.remainingUnits, 2);
        assertEq(s_.remainingCredit, c0_ - c1_);
        Migration.WeightedSyEntitlementInput[] memory a_ = _syInput(HOLDER, 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureWeightedSyEntitlements, (a_)));
        assertFalse(replayed_);
        a_[0].originalUnits = 8;
        a_[0].originalEth = 0.02 ether;
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureWeightedSyEntitlements, (a_)));
        assertFalse(corrected_);
        assertEq(abi.encode(migration.weightedSySurrender(ORIGIN)), abi.encode(s_));
        vm.warp(firstTime_ + 30 days);
        uint256 expansion_ = migration.pendingExpansionDetf();
        assertEq(migration.synchronizeRewards(), expansion_);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c1_ + expansion_);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedSyEntitlements.selector), address(0));
        (uint256 second_, uint256 c2_) = _surrenderSy(1);
        assertEq(c2_, (c0_ - c1_) / 2);
        (uint256 third_, uint256 c3_) = _surrenderSy(1);
        assertEq(c1_ + c2_ + c3_, c0_);
        assertNotEq(first_, second_);
        assertNotEq(second_, third_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstTime_);
        assertEq(bonds.positionOf(third_).startTimestamp, firstTime_ + 30 days);
        assertEq(migration.weightedSyEntitlement(ORIGIN).credit, c0_);
        s_ = migration.weightedSySurrender(ORIGIN);
        assertEq(s_.remainingUnits, 0);
        assertEq(s_.remainingCredit, 0);
        assertEq(s_.consumedUnits, 3);
        assertEq(s_.deliveredCredit, c0_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER), sourceBefore_ - 3);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 3);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 3);
        // Account for actual elapsed expansion separately from surrender's exact delivered credit.
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c0_ + expansion_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + c0_ + expansion_);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyQuantity.selector, 1, 0));
        migration.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
    }

    function test_absentWrongWalletApprovalBalanceAndLimitsLeaveEverythingUnspent() public {
        uint256 balance_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER);
        uint256 supply_ = IERC20(detf).totalSupply();
        _configureSy(HOLDER, 3);
        Migration.WeightedSyEntitlementInput[] memory large_ = _syInput(HOLDER, balance_ + 1, 0.01 ether);
        large_[0].originalId = bytes32("balance");
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(large_);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationWeightedSy(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 0);
        vm.expectCall(Legacy.WEIGHTED_SY, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, 1)));
        vm.prank(HOLDER);
        (bool approvalOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedSy, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(approvalOk_);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, type(uint256).max);
        vm.expectCall(Legacy.WEIGHTED_SY, abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, balance_ + 1)));
        vm.prank(HOLDER);
        (bool balanceOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedSy, (bytes32("balance"), balance_ + 1, 0, block.timestamp)));
        assertFalse(balanceOk_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedSyWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyQuantity.selector, 0, 3));
        migration.surrenderMigrationWeightedSy(ORIGIN, 0, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp - 1);
        uint256 quoted_ = migration.previewWeightedSySurrender(ORIGIN, 1);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", quoted_ + 1, quoted_));
        migration.surrenderMigrationWeightedSy(ORIGIN, 1, quoted_ + 1, block.timestamp);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER), balance_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 0);
        assertEq(migration.weightedSySurrender(ORIGIN).consumedUnits, 0);
        assertEq(migration.weightedSySurrender(bytes32("balance")).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
    }

    function test_transfersDoNotMoveCreditAndReturnNeedsNoHistory() public {
        _configureSy(HOLDER, 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).transfer(address(this), 3);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 3);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedSyWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationWeightedSy(ORIGIN, 3, 0, block.timestamp);
        IERC20(Legacy.WEIGHTED_SY).transfer(HOLDER, 3);
        _surrenderSy(1);
        Migration.WeightedSyEntitlementInput[] memory a_ = _syInput(address(this), 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureWeightedSyEntitlements, (a_)));
        assertFalse(corrected_);
        assertEq(migration.weightedSyEntitlement(ORIGIN).original.originalWallet, HOLDER);
        assertEq(migration.weightedSySurrender(ORIGIN).consumedUnits, 1);
        _surrenderSy(2);
    }

    function test_zeroCreditDustRejectsWithoutConfiscation() public {
        _configureSy(HOLDER, type(uint256).max);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, ORIGIN));
        migration.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
        assertEq(migration.weightedSySurrender(ORIGIN).consumedUnits, 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 0);
    }

    function test_bondReceiverRejectionRollsBackActualPullFundingAndInventory() public {
        WeightedSyReceiver wallet_ = new WeightedSyReceiver(migration, IERC20(Legacy.WEIGHTED_SY), ORIGIN);
        uint256 credit_ = _configureSy(address(wallet_), 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).transfer(address(wallet_), 3);
        wallet_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(3);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(address(wallet_)), 3);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).allowance(address(wallet_), detf), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        assertEq(migration.weightedSySurrender(ORIGIN).deliveredCredit, 0);
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
        uint256 held_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER);
        vm.prank(HOLDER);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, 3);
        for (uint256 stage_; stage_ < 2; ++stage_) {
            if (stage_ == 1) _configureSy(HOLDER, 3);
            bytes memory config_ = abi.encode(migration.weightedSyEntitlement(ORIGIN));
            bytes memory state_ = abi.encode(migration.weightedSySurrender(ORIGIN));
            vm.prank(HOLDER);
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            migration.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
            assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(HOLDER), held_);
            assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 0);
            assertEq(IERC20(Legacy.WEIGHTED_SY).allowance(HOLDER, detf), 3);
            assertEq(abi.encode(migration.weightedSyEntitlement(ORIGIN)), config_);
            assertEq(abi.encode(migration.weightedSySurrender(ORIGIN)), state_);
            assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
            assertEq(IERC20(detf).totalSupply(), supply_);
            assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
            assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
            assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        }
        _activate();
        _surrenderSy(3);
    }
}
