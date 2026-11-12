// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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

interface IClaimedSyWeightSource {
    function reassign(address recipient, uint256 amount) external;
    function withdrawClaim(uint256 amount) external returns (uint256);
    function balanceOf(address wallet) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function phase() external view returns (uint8);
    function claimVault() external view returns (address);
}

/// @notice Synthetic historical allocations; real source claims and registered Migration.
/// Foundry caller simulation here is distinct from the CLI's retained EOA signatures.
/// Ordinary-SY rejecting receiver/reentry above is shared-path coverage, not a
/// claimed-origin callback witness; claimed preparation admits direct EOAs only.
contract MigrationClaimedSyTest is MigrationRecoveryDonationForkBase {
    IClaimedSyWeightSource constant SOURCE =
        IClaimedSyWeightSource(address(bytes20(hex"e4c9ff4cfd17ae73ecb3825ebdf7db113c146d00")));
    address constant DONOR = address(bytes20(hex"016900aa17a08a52f1cc10a9474b3bbfaeb380a3"));
    uint256 constant W0 = 10013000000000000000017;
    uint256 constant UNRELATED = 7 ether;
    uint256 constant SEED = 3 ether;
    bytes32 constant CLAIMED_ORIGIN = keccak256("synthetic complete claimed-SY original");

    function _prepare(bool split_) private returns (address wallet_, uint256 q0_, uint256 floor_) {
        wallet_ = vm.addr(split_ ? 23002 : 23001);
        assertEq(wallet_.code.length, 0);
        assertEq(DONOR.code.length, 0);
        assertEq(SOURCE.phase(), 2);
        assertEq(SOURCE.claimVault(), address(bytes20(hex"af5c0cd3fdedd10bee00eff77fa0429bacdb41f0")));
        assertEq(SOURCE.balanceOf(wallet_), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(wallet_), 0);
        uint256 donor_ = SOURCE.balanceOf(DONOR);
        uint256 supply_ = SOURCE.totalSupply();
        vm.prank(DONOR);
        SOURCE.reassign(wallet_, W0 + UNRELATED + SEED);
        assertEq(SOURCE.balanceOf(DONOR), donor_ - W0 - UNRELATED - SEED);
        assertEq(SOURCE.totalSupply(), supply_);
        vm.startPrank(wallet_);
        floor_ = SOURCE.withdrawClaim(SEED);
        assertGt(floor_, 0);
        if (split_) {
            uint256 first_ = 3337000000000000000005;
            uint256 part_ = SOURCE.withdrawClaim(first_);
            assertGt(part_, 0);
            assertEq(SOURCE.balanceOf(wallet_), W0 - first_ + UNRELATED);
            q0_ = part_ + SOURCE.withdrawClaim(W0 - first_);
        } else {
            q0_ = SOURCE.withdrawClaim(W0);
        }
        vm.stopPrank();
        assertGt(q0_, 0);
        assertEq(SOURCE.balanceOf(wallet_), UNRELATED);
        assertEq(SOURCE.totalSupply(), supply_ - W0 - SEED);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(wallet_), floor_ + q0_);
    }

    function _load(address wallet_, uint256 q0_) private returns (uint256 credit_) {
        Migration.WeightedSyEntitlementInput[] memory inputs_ = new Migration.WeightedSyEntitlementInput[](1);
        // Complete E0/D0 are deliberately not scaled by a source weight/SY fraction.
        inputs_[0] = Migration.WeightedSyEntitlementInput(CLAIMED_ORIGIN, wallet_, Legacy.WEIGHTED_SY,
            q0_, 0.01 ether, 1 ether, keccak256("synthetic reviewed complete preparation evidence"), true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(migrationOwner);
        allocation.configureWeightedSyEntitlements(inputs_);
        credit_ = migration.previewOriginalCredit(0.01 ether, 1 ether);
        assertEq(migration.weightedSyEntitlement(CLAIMED_ORIGIN).credit, credit_);
        assertEq(migration.weightedSySurrender(CLAIMED_ORIGIN).remainingUnits, q0_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        vm.prank(wallet_);
        IERC20(Legacy.WEIGHTED_SY).approve(detf, q0_);
        vm.prank(wallet_);
        vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationWeightedSy(CLAIMED_ORIGIN, q0_, 1, block.timestamp);
        assertEq(SOURCE.balanceOf(wallet_), UNRELATED);
        _activate();
        assertGt(migration.migrationOwnerFirstBondTokenId(), 0);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedSyEntitlements.selector), address(0));
    }

    function _surrender(address wallet_, uint256 q_, uint256 expected_) private returns (uint256 id_) {
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = IERC20(detf).balanceOf(address(receipt));
        uint256 held_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(detf);
        vm.prank(wallet_);
        uint256 credit_;
        (id_, credit_) = migration.surrenderMigrationWeightedSy(CLAIMED_ORIGIN, q_, expected_, block.timestamp);
        assertEq(credit_, expected_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), wallet_);
        assertEq(bonds.positionOf(id_).principal, expected_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(bonds.positionOf(id_).startTimestamp, block.timestamp);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).stakingGons, expected_ * receipt.stakingState().gonsPerUnit);
        assertEq(IERC20(detf).totalSupply(), supply_ + expected_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), backing_ + expected_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), held_ + q_);
        assertEq(SOURCE.balanceOf(wallet_), UNRELATED);
    }

    function _completeOriginal(bool split_) private {
        (address wallet_, uint256 q0_, uint256 floor_) = _prepare(split_);
        uint256 c0_ = _load(wallet_, q0_);
        uint256 q_ = q0_ / 3;
        uint256 first_ = _surrender(wallet_, q_, c0_ * q_ / q0_);
        Migration.WeightedSySurrender memory state_ = migration.weightedSySurrender(CLAIMED_ORIGIN);
        assertEq(state_.remainingUnits, q0_ - q_);
        assertEq(state_.remainingCredit + state_.deliveredCredit, c0_);
        uint256 firstStart_ = bonds.positionOf(first_).startTimestamp;
        vm.warp(block.timestamp + 1 days);
        migration.synchronizeRewards();
        uint256 second_ = _surrender(wallet_, state_.remainingUnits, state_.remainingCredit);
        assertNotEq(first_, second_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstStart_);
        assertEq(bonds.positionOf(second_).startTimestamp, firstStart_ + 1 days);
        state_ = migration.weightedSySurrender(CLAIMED_ORIGIN);
        assertEq(state_.remainingUnits, 0);
        assertEq(state_.remainingCredit, 0);
        assertEq(state_.deliveredCredit, c0_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), q0_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(wallet_), floor_);
        assertEq(SOURCE.balanceOf(wallet_), UNRELATED);
    }

    function test_completeSingleClaimPreservesWholeOriginalCreditAndUnrelatedFloors() public {
        _completeOriginal(false);
    }

    function test_completeSplitClaimsAggregateMeasuredOutputsIntoOneOriginal() public {
        _completeOriginal(true);
    }

    function test_lateChildFundingRollbackCannotRestoreEarlierConsumedRawWeight() public {
        (address wallet_, uint256 q0_, uint256 floor_) = _prepare(false);
        uint256 c0_ = _load(wallet_, q0_);
        bytes32 before_ = _protected(migration.migrationOwnerFirstBondTokenId());
        bytes memory state_ = abi.encode(migration.weightedSySurrender(CLAIMED_ORIGIN));
        uint256 sourceSupply_ = SOURCE.totalSupply();
        vm.expectCall(address(receipt), abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            IERC20(detf), c0_, IERC20(address(receipt)), c0_, address(bonds), false, block.timestamp
        )), uint64(2));
        vm.prank(wallet_);
        (bool ok_,) = detf.call{gas: 750000}(abi.encodeCall(
            Migration.surrenderMigrationWeightedSy, (CLAIMED_ORIGIN, q0_, 1, block.timestamp)
        ));
        assertFalse(ok_);
        assertEq(_protected(migration.migrationOwnerFirstBondTokenId()), before_);
        assertEq(abi.encode(migration.weightedSySurrender(CLAIMED_ORIGIN)), state_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(wallet_), q0_ + floor_);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(detf), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).allowance(wallet_, detf), q0_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), 0);
        assertEq(SOURCE.balanceOf(wallet_), UNRELATED);
        assertEq(SOURCE.totalSupply(), sourceSupply_);
        _surrender(wallet_, q0_, c0_);
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
