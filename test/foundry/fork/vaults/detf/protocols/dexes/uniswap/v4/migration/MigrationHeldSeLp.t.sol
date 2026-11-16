// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
import {IMigrationLegacyExchange} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";

interface IHeldSeLpCollector {
    function owner() external view returns (address);
    function pullFee(address token_, uint256 amount_, address recipient_) external returns (bool);
}

interface IHeldLpFeeOracle {
    function feeOracle() external view returns (address);
    function feeTo() external view returns (address);
    function setFeeTo(address recipient_) external returns (bool);
}

/// @notice Synthetic acquiring contract wallet; the source and funding system remain real.
contract HeldSeLpReceiver is IERC721Receiver {
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
        return parent.surrenderMigrationHeldSeLp(origin, q_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (surrenderReentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationHeldSeLp, (origin, 1, 0, block.timestamp)
        ));
        (activationReentered,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice ED original quantities/components are synthetic, never derived from the holder's balance.
abstract contract MigrationHeldSeLpTest is MigrationRecoveryDonationForkBase {
    function _source() internal pure virtual returns (address);

    address constant HOLDER = address(0xED);
    bytes32 constant ORIGIN = keccak256("synthetic held SE LP original");
    uint256 constant QUANTITY = 21225531;

    address constant COLLECTOR = address(bytes20(hex"20af9a1e21a59a411cd3b0c40e70af9084770b2e"));
    address constant DONOR = address(bytes20(hex"72bea6fa3e68ef18c87d045aac7c4aa5249d933b"));
    address constant EARLIER_SE_HOLDER = address(bytes20(hex"bab6a03be445094a10695772a79777407dcdc0e7"));

    function setUp() public override {
        super.setUp();
        _acquire(_source(), HOLDER, 10020);
    }

    /// @dev Impersonated local donor preparation, not controlled signatures or historical originals.
    /// LP release belongs ONLY to the existing EOA collector owner and goes to that same owner.
    function _acquire(address source_, address recipient_, uint256 q_) internal {
        if (source_ == Legacy.EARLIER_SE) {
            assertEq(EARLIER_SE_HOLDER.code.length, 0);
            assertEq(IERC20(source_).balanceOf(EARLIER_SE_HOLDER), 2021090200239501983);
            assertEq(IDiamondLoupe(source_).facetAddress(IERC20.transferFrom.selector),
                0x1d17acA0e0717d90cea916372070a1BE4652223F);
            uint256 supply_ = IERC20(source_).totalSupply();
            uint256 before_ = IERC20(source_).balanceOf(recipient_);
            vm.prank(EARLIER_SE_HOLDER);
            assertTrue(IERC20(source_).transfer(recipient_, q_));
            assertEq(IERC20(source_).balanceOf(EARLIER_SE_HOLDER), 2021090200239501983 - q_);
            assertEq(IERC20(source_).balanceOf(recipient_), before_ + q_);
            assertEq(IERC20(source_).totalSupply(), supply_);
            return;
        }
        assertEq(DONOR.code.length, 0);
        assertEq(IHeldSeLpCollector(COLLECTOR).owner(), DONOR);
        address facet_ = IDiamondLoupe(COLLECTOR).facetAddress(IHeldSeLpCollector.pullFee.selector);
        assertEq(facet_, 0xF7A99a0aeD1A4252C71c99FDD2a5B3250a41f669);
        assertEq(facet_.codehash, 0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb);
        assertEq(IDiamondLoupe(source_).facetAddress(IERC20.transferFrom.selector),
            0x1d17acA0e0717d90cea916372070a1BE4652223F);
        uint256 supply_ = IERC20(source_).totalSupply();
        uint256 recipientBefore_ = IERC20(source_).balanceOf(recipient_);
        uint256 ownerBefore_ = IERC20(source_).balanceOf(DONOR);
        if (source_ != Legacy.WEIGHTED_WETH_SE) {
            uint256 collectorBefore_ = IERC20(source_).balanceOf(COLLECTOR);
            assertGe(collectorBefore_, q_);
            vm.prank(DONOR); assertTrue(IHeldSeLpCollector(COLLECTOR).pullFee(source_, q_, DONOR));
            assertEq(IERC20(source_).balanceOf(COLLECTOR), collectorBefore_ - q_);
            assertEq(IERC20(source_).balanceOf(DONOR), ownerBefore_ + q_);
        }
        uint256 personalBefore_ = IERC20(source_).balanceOf(DONOR);
        vm.prank(DONOR); assertTrue(IERC20(source_).transfer(recipient_, q_));
        assertEq(IERC20(source_).balanceOf(DONOR), personalBefore_ - q_);
        assertEq(IERC20(source_).balanceOf(recipient_), recipientBefore_ + q_);
        assertEq(IERC20(source_).totalSupply(), supply_);
        assertEq(IHeldSeLpCollector(COLLECTOR).owner(), DONOR);
        assertEq(IDiamondLoupe(COLLECTOR).facetAddress(IHeldSeLpCollector.pullFee.selector), facet_);
    }

    function _liquidInput(address wallet_, uint256 q_, uint256 eth_)
        private pure returns (Migration.HeldSeLpEntitlementInput[] memory a_)
    {
        a_ = new Migration.HeldSeLpEntitlementInput[](1);
        a_[0] = Migration.HeldSeLpEntitlementInput(
            ORIGIN, wallet_, _source(), q_, eth_, 0, keccak256("synthetic held native18 input evidence"), true
        );
    }

    function _configureLiquid(address wallet_, uint256 q_) internal returns (uint256) {
        Migration.HeldSeLpEntitlementInput[] memory a_ = _liquidInput(wallet_, q_, 0.01 ether);
        vm.prank(migrationOwner);
        allocation.configureHeldSeLpEntitlements(a_, pricingId);
        return migration.heldSeLpEntitlement(ORIGIN).credit;
    }

    function _surrenderLiquid(uint256 q_) private returns (uint256 id_, uint256 credit_) {
        uint256 now_ = vm.getBlockTimestamp();
        vm.startPrank(HOLDER);
        IERC20(_source()).approve(detf, q_);
        (id_, credit_) = migration.surrenderMigrationHeldSeLp(ORIGIN, q_, 1, now_);
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
        uint256 sourceBefore_ = IERC20(_source()).balanceOf(HOLDER);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 firstTime_ = vm.getBlockTimestamp();
        (uint256 first_, uint256 c1_) = _surrenderLiquid(1);
        assertEq(c1_, c0_ / 3);
        Migration.HeldSeLpSurrender memory s_ = migration.heldSeLpSurrender(ORIGIN);
        assertEq(s_.consumedUnits, 1);
        assertEq(s_.deliveredCredit, c1_);
        assertEq(s_.remainingUnits, 2);
        assertEq(s_.remainingCredit, c0_ - c1_);
        Migration.HeldSeLpEntitlementInput[] memory a_ = _liquidInput(HOLDER, 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool replayed_,) = detf.call(abi.encodeCall(Allocation.configureHeldSeLpEntitlements, (a_, pricingId)));
        assertFalse(replayed_);
        a_[0].originalUnits = 8;
        a_[0].originalEth = 0.02 ether;
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureHeldSeLpEntitlements, (a_, pricingId)));
        assertFalse(corrected_);
        assertEq(abi.encode(migration.heldSeLpSurrender(ORIGIN)), abi.encode(s_));
        vm.warp(firstTime_ + 30 days);
        uint256 expansion_ = migration.pendingExpansionDetf();
        assertEq(migration.synchronizeRewards(), expansion_);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c1_ + expansion_);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureHeldSeLpEntitlements.selector), address(0));
        (uint256 second_, uint256 c2_) = _surrenderLiquid(1);
        assertEq(c2_, (c0_ - c1_) / 2);
        (uint256 third_, uint256 c3_) = _surrenderLiquid(1);
        assertEq(c1_ + c2_ + c3_, c0_);
        assertNotEq(first_, second_);
        assertNotEq(second_, third_);
        assertEq(bonds.positionOf(first_).startTimestamp, firstTime_);
        assertEq(bonds.positionOf(third_).startTimestamp, firstTime_ + 30 days);
        assertEq(migration.heldSeLpEntitlement(ORIGIN).credit, c0_);
        s_ = migration.heldSeLpSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 0);
        assertEq(s_.remainingCredit, 0);
        assertEq(s_.consumedUnits, 3);
        assertEq(s_.deliveredCredit, c0_);
        assertEq(IERC20(_source()).balanceOf(HOLDER), sourceBefore_ - 3);
        assertEq(IERC20(_source()).balanceOf(detf), 3);
        assertEq(recovery.migrationRecoveryInventory(_source()), 3);
        // Account for actual elapsed expansion separately from surrender's exact delivered credit.
        assertEq(IERC20(detf).totalSupply(), supplyBefore_ + c0_ + expansion_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + c0_ + expansion_);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpQuantity.selector, 1, 0));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp);
    }

    function test_absentWrongWalletApprovalBalanceAndLimitsLeaveEverythingUnspent() public {
        uint256 balance_ = IERC20(_source()).balanceOf(HOLDER);
        uint256 supply_ = IERC20(detf).totalSupply();
        _configureLiquid(HOLDER, 3);
        Migration.HeldSeLpEntitlementInput[] memory large_ = _liquidInput(HOLDER, balance_ + 1, 0.01 ether);
        large_[0].originalId = bytes32("balance");
        vm.prank(migrationOwner);
        allocation.configureHeldSeLpEntitlements(large_, pricingId);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationHeldSeLp(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(HOLDER);
        IERC20(_source()).approve(detf, 0);
        vm.expectCall(_source(), abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, 1)));
        vm.prank(HOLDER);
        (bool approvalOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationHeldSeLp, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(approvalOk_);
        vm.prank(HOLDER);
        IERC20(_source()).approve(detf, type(uint256).max);
        vm.expectCall(_source(), abi.encodeCall(IERC20.transferFrom, (HOLDER, detf, balance_ + 1)));
        vm.prank(HOLDER);
        (bool balanceOk_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationHeldSeLp, (bytes32("balance"), balance_ + 1, 0, block.timestamp)));
        assertFalse(balanceOk_);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalHeldSeLpWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpQuantity.selector, 0, 3));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 0, 0, block.timestamp);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp - 1);
        uint256 quoted_ = migration.previewHeldSeLpSurrender(ORIGIN, 1);
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", quoted_ + 1, quoted_));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, quoted_ + 1, block.timestamp);
        assertEq(IERC20(_source()).balanceOf(HOLDER), balance_);
        assertEq(IERC20(_source()).balanceOf(detf), 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).consumedUnits, 0);
        assertEq(migration.heldSeLpSurrender(bytes32("balance")).consumedUnits, 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
        assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
    }

    function test_transfersDoNotMoveCreditAndReturnNeedsNoHistory() public {
        _configureLiquid(HOLDER, 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(_source()).transfer(address(this), 3);
        IERC20(_source()).approve(detf, 3);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalHeldSeLpWallet.selector, address(this), HOLDER));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 3, 0, block.timestamp);
        IERC20(_source()).transfer(HOLDER, 3);
        _surrenderLiquid(1);
        Migration.HeldSeLpEntitlementInput[] memory a_ = _liquidInput(address(this), 3, 0.01 ether);
        vm.prank(migrationOwner);
        (bool corrected_,) = detf.call(abi.encodeCall(Allocation.configureHeldSeLpEntitlements, (a_, pricingId)));
        assertFalse(corrected_);
        assertEq(migration.heldSeLpEntitlement(ORIGIN).original.originalWallet, HOLDER);
        assertEq(migration.heldSeLpSurrender(ORIGIN).consumedUnits, 1);
        _surrenderLiquid(2);
    }

    function test_zeroCreditDustRejectsWithoutConfiscation() public {
        _configureLiquid(HOLDER, type(uint256).max);
        _activate();
        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidHeldSeLpEntitlement.selector, ORIGIN));
        migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp);
        assertEq(migration.heldSeLpSurrender(ORIGIN).consumedUnits, 0);
        assertEq(IERC20(_source()).balanceOf(detf), 0);
    }

    function test_finiteAndMaximumAllowancesSpendExactNative18WithUnbookedFloor() public {
        uint256 c0_ = _configureLiquid(HOLDER, 10007);
        _activate();
        vm.startPrank(HOLDER);
        IERC20(_source()).transfer(detf, 13);
        IERC20(_source()).approve(detf, 10007);
        (, uint256 partial_) = migration.surrenderMigrationHeldSeLp(ORIGIN, 4003, 1, block.timestamp);
        assertEq(partial_, c0_ * 4003 / 10007);
        assertEq(IERC20(_source()).allowance(HOLDER, detf), 6004);
        assertEq(recovery.migrationRecoveryInventory(_source()), 4003);
        assertEq(IERC20(_source()).balanceOf(detf), 4016);
        IERC20(_source()).approve(detf, type(uint256).max);
        (, uint256 terminal_) = migration.surrenderMigrationHeldSeLp(ORIGIN, 6004, 1, block.timestamp);
        vm.stopPrank();
        assertEq(terminal_, c0_ - partial_);
        assertEq(IERC20(_source()).allowance(HOLDER, detf), type(uint256).max - 6004);
        assertEq(IERC20(_source()).balanceOf(HOLDER), 0);
        assertEq(recovery.migrationRecoveryInventory(_source()), 10007);
        assertEq(IERC20(_source()).balanceOf(detf), 10020);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingCredit, 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingUnits, 0);
    }

    function test_actualChildFundingFailureRestoresSourceAllowanceAndEveryBudget() public {
        uint256 credit_ = _configureLiquid(HOLDER, 3);
        _activate();
        vm.prank(HOLDER); IERC20(_source()).approve(detf, 3);
        bytes32 before_ = _protected(migration.migrationOwnerFirstBondTokenId());
        vm.expectCall(address(receipt), abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            IERC20(detf), credit_, IERC20(address(receipt)), credit_, address(bonds), false, block.timestamp
        )), uint64(2));
        vm.prank(HOLDER);
        (bool ok_,) = detf.call{gas: 750000}(abi.encodeCall(
            Migration.surrenderMigrationHeldSeLp, (ORIGIN, 3, 1, block.timestamp)
        ));
        assertFalse(ok_);
        assertEq(_protected(migration.migrationOwnerFirstBondTokenId()), before_);
        assertEq(IERC20(_source()).balanceOf(HOLDER), 10020);
        assertEq(IERC20(_source()).balanceOf(detf), 0);
        assertEq(IERC20(_source()).allowance(HOLDER, detf), 3);
        assertEq(recovery.migrationRecoveryInventory(_source()), 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).consumedUnits, 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingCredit, credit_);
        _surrenderLiquid(3);
    }

    function test_bondReceiverRejectionRollsBackActualPullFundingAndInventory() public {
        HeldSeLpReceiver wallet_ = new HeldSeLpReceiver(migration, IERC20(_source()), ORIGIN);
        uint256 credit_ = _configureLiquid(address(wallet_), 3);
        _activate();
        vm.prank(HOLDER);
        IERC20(_source()).transfer(address(wallet_), 3);
        wallet_.approve(3);
        wallet_.reject(true);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(3);
        assertEq(IERC20(_source()).balanceOf(address(wallet_)), 3);
        assertEq(IERC20(_source()).balanceOf(detf), 0);
        // The earlier completed approval persists; only operation effects roll back.
        assertEq(IERC20(_source()).allowance(address(wallet_), detf), 3);
        assertEq(recovery.migrationRecoveryInventory(_source()), 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).deliveredCredit, 0);
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
        uint256 held_ = IERC20(_source()).balanceOf(HOLDER);
        vm.prank(HOLDER);
        IERC20(_source()).approve(detf, 3);
        for (uint256 stage_; stage_ < 2; ++stage_) {
            if (stage_ == 1) _configureLiquid(HOLDER, 3);
            bytes memory config_ = abi.encode(migration.heldSeLpEntitlement(ORIGIN));
            bytes memory state_ = abi.encode(migration.heldSeLpSurrender(ORIGIN));
            vm.prank(HOLDER);
            vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
            migration.surrenderMigrationHeldSeLp(ORIGIN, 1, 0, block.timestamp);
            assertEq(IERC20(_source()).balanceOf(HOLDER), held_);
            assertEq(IERC20(_source()).balanceOf(detf), 0);
            assertEq(IERC20(_source()).allowance(HOLDER, detf), 3);
            assertEq(abi.encode(migration.heldSeLpEntitlement(ORIGIN)), config_);
            assertEq(abi.encode(migration.heldSeLpSurrender(ORIGIN)), state_);
            assertEq(recovery.migrationRecoveryInventory(_source()), 0);
            assertEq(IERC20(detf).totalSupply(), supply_);
            assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking);
            assertEq(receipt.gonsOf(address(bonds)), initialBondGons);
            assertEq(IERC721(address(bonds)).ownerOf(migration.migrationOwnerFirstBondTokenId() + 1), address(0));
        }
        _activate();
        _surrenderLiquid(3);
    }

    function test_actualHeldBondsReleasePrincipalOnlyAtTheirFreshCliff() public {
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

    function test_fourHeldSourcesPreserveMixedNftEdErWsAndDonationInventories() public {
        address[4] memory fixed_ = [Legacy.WEIGHTED_WETH_SE, Legacy.EARLIER_LP, Legacy.WEIGHTED_LP, Legacy.EARLIER_SE];
        Migration.HeldSeLpEntitlementInput[] memory a_ = new Migration.HeldSeLpEntitlementInput[](4);
        for (uint256 i_; i_ < 4; ++i_) {
            if (fixed_[i_] != _source()) _acquire(fixed_[i_], HOLDER, 10020);
            a_[i_] = _liquidInput(HOLDER, 3, 0.01 ether)[0];
            a_[i_].originalId = bytes32(uint256(uint160(fixed_[i_])));
            a_[i_].source = fixed_[i_];
        }
        vm.prank(migrationOwner); allocation.configureHeldSeLpEntitlements(a_, pricingId);
        _configureNft(EARLIER, 3);
        _configureNft(WEIGHTED, 4);
        vm.prank(address(0xBEdf78eB17A054D972c85cE222E2175F19899CD6));
        IERC20(Legacy.EARLIER_RECEIPT).transfer(HOLDER, 10000);
        Migration.EarlierReceiptEntitlementInput[] memory er_ = new Migration.EarlierReceiptEntitlementInput[](1);
        er_[0] = Migration.EarlierReceiptEntitlementInput(
            bytes32("distinct ER original"), HOLDER, Legacy.EARLIER_RECEIPT,
            uint256(10000) * 1e27 / 2197, 0.01 ether, 0, bytes32("synthetic ER components"), true
        );
        vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(er_, pricingId);
        _activate();
        _surrender(EARLIER, 3);
        _surrender(WEIGHTED, 4);
        _run(Recovery.Stage.EarlierClaim, 3, 0, 0);
        _run(Recovery.Stage.WeightedClaim, 4, 0, 0);
        vm.startPrank(HOLDER);
        IERC20(Legacy.EARLIER_RECEIPT).approve(detf, 4);
        migration.surrenderMigrationEarlierReceipt(bytes32("distinct ER original"), 4, 1, block.timestamp);
        for (uint256 i_; i_ < 4; ++i_) IERC20(fixed_[i_]).transfer(detf, 13);
        vm.stopPrank();
        vm.prank(address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed")));
        IERC20(Legacy.EARLIER_DETF).transfer(detf, 7);
        vm.warp(IMigrationEarlierNft(EARLIER).getPosition(3).unlockTime);
        _run(Recovery.Stage.EarlierSale, 3, 0, 1);
        bytes32 before_ = _inheritedInventory();
        assertGt(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), 0);
        assertGt(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT), 0);
        assertGt(recovery.migrationEarlierReceiptInternalShares(), 0);
        assertGt(recovery.migrationRecoveryGons(), 0);
        for (uint256 i_; i_ < 4; ++i_) {
            vm.startPrank(HOLDER);
            IERC20(fixed_[i_]).approve(detf, 3);
            migration.surrenderMigrationHeldSeLp(a_[i_].originalId, 3, 1, block.timestamp);
            vm.stopPrank();
            assertEq(_inheritedInventory(), before_);
            for (uint256 j_; j_ < 4; ++j_) {
                uint256 booked_ = j_ <= i_ ? 3 : 0;
                assertEq(recovery.migrationRecoveryInventory(fixed_[j_]), booked_);
                assertEq(IERC20(fixed_[j_]).balanceOf(detf), 13 + booked_);
            }
        }
    }

    function _inheritedInventory() private view returns (bytes32) {
        return keccak256(abi.encode(
            recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF),
            IERC20(Legacy.EARLIER_DETF).balanceOf(detf),
            recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT),
            recovery.migrationEarlierReceiptInternalShares(),
            IERC20(Legacy.EARLIER_RECEIPT).balanceOf(detf),
            recovery.migrationRecoveryInventory(Legacy.WEIGHTED_RECEIPT),
            recovery.migrationRecoveryGons(), IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(detf),
            recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF),
            migration.migrationDonationInventory(IERC20(pairA)),
            migration.migrationDonationInventory(IERC20(pairB)),
            IERC20(reserveHook).balanceOf(address(bonds))
        ));
    }
}

contract MigrationWeightedWethSeTest is MigrationHeldSeLpTest {
    function _source() internal pure override returns (address) { return Legacy.WEIGHTED_WETH_SE; }

    function test_typedRecoveryAfterLocalLegacyEnablementPreservesUnbookedShares() public {
        uint256 q_ = IERC20(_source()).balanceOf(DONOR) - 100;
        _acquire(_source(), HOLDER, q_);
        _acquire(_source(), detf, 100);
        _configureLiquid(HOLDER, q_);
        _activate();
        vm.startPrank(HOLDER);
        IERC20(_source()).approve(detf, q_);
        (uint256 bond_,) = migration.surrenderMigrationHeldSeLp(ORIGIN, q_, 1, block.timestamp);
        vm.stopPrank();
        bytes32 protected_ = _protected(bond_);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", _source()));
        _run(Recovery.Stage.WeightedWethSeConvert, 0, q_, 1);
        assertEq(recovery.migrationRecoveryInventory(_source()), q_);
        assertEq(IERC20(_source()).balanceOf(detf), q_ + 100);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);

        address registry_ = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(registry_);
        (, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(_source());
        vm.startPrank(IMultiStepOwnable(registry_).owner());
        if (byVault_) IVaultRegistryDisableManager(registry_).setVaultAddressDisabled(_source(), false);
        if (byPackage_) {
            IVaultRegistryDisableManager(registry_).setPackageDisabled(query_.packageOfVault(_source()), false);
        }
        vm.stopPrank();
        assertFalse(query_.isDisabled(_source()));
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 sourceSupply_ = IERC20(_source()).totalSupply();
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedWethSeConvert, 0, q_, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.Donate, 1, 1, 1);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(_source()).totalSupply(), sourceSupply_);
        assertEq(IERC20(_source()).balanceOf(detf), q_ + 100);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), before_);
        assertEq(recovery.migrationRecoveryInventory(_source()), q_);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.WeightedWethSeConvert, 0, q_, 1);
        uint256 out_ = IERC20(Legacy.DTF).balanceOf(detf) - before_;
        assertGt(out_, 0);
        assertEq(recovery.migrationRecoveryInventory(_source()), 0);
        assertEq(IERC20(_source()).balanceOf(detf), 100);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.Donate, 0, out_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }
}
contract MigrationEarlierLpTest is MigrationHeldSeLpTest {
    function _source() internal pure override returns (address) { return Legacy.EARLIER_LP; }
}
contract MigrationWeightedLpTest is MigrationHeldSeLpTest {
    function _source() internal pure override returns (address) { return Legacy.WEIGHTED_LP; }

    function test_typedLpRecoveryAfterActualOracleAuthorizationPreservesFeeMints() public {
        uint256 q_ = IERC20(_source()).balanceOf(COLLECTOR) / 2;
        _acquire(_source(), HOLDER, q_);
        _acquire(_source(), detf, 100);
        _configureLiquid(HOLDER, q_);
        _activate();
        vm.startPrank(HOLDER);
        IERC20(_source()).approve(detf, q_);
        (uint256 bond_,) = migration.surrenderMigrationHeldSeLp(ORIGIN, q_, 1, block.timestamp);
        vm.stopPrank();
        bytes32 protected_ = _protected(bond_);
        vm.expectRevert(abi.encodeWithSignature("NotOwner(address)", detf));
        _run(Recovery.Stage.WeightedLpRedeem, 0, q_, 1);
        assertEq(recovery.migrationRecoveryInventory(_source()), q_);
        assertEq(IERC20(_source()).balanceOf(detf), q_ + 100);

        address oracle_ = IHeldLpFeeOracle(_source()).feeOracle();
        address administrator_ = IMultiStepOwnable(oracle_).owner();
        assertEq(administrator_.code.length, 0);
        // Conditional real external authorization, not Migration assigning itself a role.
        vm.prank(administrator_);
        IHeldLpFeeOracle(oracle_).setFeeTo(detf);
        assertEq(IHeldLpFeeOracle(_source()).feeTo(), detf);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 supply_ = IERC20(_source()).totalSupply();
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.WeightedLpRedeem, 0, q_, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.Donate, 1, 1, 1);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(_source()).totalSupply(), supply_);
        assertEq(IERC20(_source()).balanceOf(detf), q_ + 100);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), before_);
        assertEq(recovery.migrationRecoveryInventory(_source()), q_);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.WeightedLpRedeem, 0, q_, 1);
        uint256 minted_ = IERC20(_source()).totalSupply() + q_ - supply_;
        uint256 out_ = IERC20(Legacy.DTF).balanceOf(detf) - before_;
        assertGt(out_, 0);
        assertEq(IERC20(_source()).balanceOf(detf), 100 + minted_);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);
        assertEq(recovery.migrationRecoveryInventory(_source()), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, _source(), 1, 0
        ));
        _run(Recovery.Stage.WeightedLpRedeem, 0, 1, 0);
        _run(Recovery.Stage.Donate, 0, out_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }
}

/// @notice Actual pinned EOA custody; contribution amounts and configured eligibility remain synthetic.
contract MigrationEarlierSeTest is MigrationHeldSeLpTest {
    function _source() internal pure override returns (address) { return Legacy.EARLIER_SE; }

    function test_genuineOriginalHolderSurrendersIntoFreshFundedBondsWithDisabledRecovery() public {
        uint256 quantity_ = IERC20(_source()).balanceOf(EARLIER_SE_HOLDER);
        uint256 credit_ = _configureLiquid(EARLIER_SE_HOLDER, quantity_);
        assertEq(migration.heldSeLpEntitlement(ORIGIN).original.originalWallet, EARLIER_SE_HOLDER);
        _activate();
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 firstCredit_ = credit_ * 1 ether / quantity_;
        vm.startPrank(EARLIER_SE_HOLDER);
        IERC20(_source()).approve(detf, quantity_);
        (uint256 first_, uint256 partial_) =
            migration.surrenderMigrationHeldSeLp(ORIGIN, 1 ether, firstCredit_, block.timestamp);
        assertEq(partial_, firstCredit_);
        assertEq(IERC20(_source()).balanceOf(EARLIER_SE_HOLDER), quantity_ - 1 ether);
        assertEq(IERC20(_source()).balanceOf(detf), 1 ether);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingCredit, credit_ - firstCredit_);
        (uint256 last_, uint256 delivered_) = migration.surrenderMigrationHeldSeLp(
            ORIGIN, quantity_ - 1 ether, credit_ - firstCredit_, block.timestamp
        );
        assertEq(delivered_, credit_ - firstCredit_);
        vm.stopPrank();
        assertNotEq(first_, last_);
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 bond_ = i_ == 0 ? first_ : last_;
            uint256 principal_ = i_ == 0 ? firstCredit_ : credit_ - firstCredit_;
            assertEq(IERC721(address(bonds)).ownerOf(bond_), EARLIER_SE_HOLDER);
            assertEq(bonds.positionOf(bond_).principal, principal_);
            assertEq(bonds.positionOf(bond_).claimedPrincipal, 0);
            assertEq(bonds.positionOf(bond_).startTimestamp, block.timestamp);
            assertEq(bonds.positionOf(bond_).vestingDuration, 90 days);
            assertEq(bonds.positionOf(bond_).stakingGons, principal_ * receipt.stakingState().gonsPerUnit);
        }
        assertEq(IERC20(_source()).balanceOf(EARLIER_SE_HOLDER), 0);
        assertEq(IERC20(_source()).balanceOf(detf), quantity_);
        assertEq(IERC20(_source()).allowance(EARLIER_SE_HOLDER, detf), 0);
        assertEq(recovery.migrationRecoveryInventory(_source()), quantity_);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingUnits, 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).remainingCredit, 0);
        assertEq(migration.heldSeLpSurrender(ORIGIN).consumedUnits, quantity_);
        assertEq(migration.heldSeLpSurrender(ORIGIN).deliveredCredit, credit_);
        assertEq(IERC20(detf).totalSupply(), supply_ + credit_);
        assertEq(IERC20(detf).balanceOf(address(receipt)), initialBacking + credit_);
        bytes32 protected_ = _protected(first_);
        // Other stages cannot select E-S. Its own stage honors the actual disabled source.
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        _run(Recovery.Stage.EarlierSale, 0, quantity_, 1);
        vm.expectRevert(abi.encodeWithSelector(
            Recovery.RecoveryInventoryInsufficient.selector, Legacy.DTF_CUSTODY_SE, quantity_, 0
        ));
        _run(Recovery.Stage.DtfCustodySeRedeem, 0, quantity_, 1);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)", _source()));
        _run(Recovery.Stage.EarlierSeConvert, 0, quantity_, 1);
        assertEq(recovery.migrationRecoveryInventory(_source()), quantity_);
        assertEq(IERC20(_source()).balanceOf(detf), quantity_);
        assertEq(_protected(first_), protected_);
    }

    function test_typedEarlierSeRecoveryAfterPaidAcquisitionAndLocalEnablement() public {
        address registry_ = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
        IVaultRegistryDisableQuery query_ = IVaultRegistryDisableQuery(registry_);
        (, bool byVault_, bool byPackage_) = query_.isDisabledDetailed(_source());
        vm.startPrank(IMultiStepOwnable(registry_).owner());
        if (byVault_) IVaultRegistryDisableManager(registry_).setVaultAddressDisabled(_source(), false);
        if (byPackage_) {
            IVaultRegistryDisableManager(registry_).setPackageDisabled(query_.packageOfVault(_source()), false);
        }
        vm.stopPrank();
        assertFalse(query_.isDisabled(_source()));
        // Pay for a non-dust source position from genuinely holder-funded DTF.
        IERC20(Legacy.DTF).transfer(HOLDER, 1e12);
        vm.startPrank(HOLDER);
        IERC20(Legacy.DTF).approve(_source(), 1e12);
        uint256 q_ = IMigrationLegacyExchange(_source()).exchangeIn(
            Legacy.DTF, 1e12, _source(), 1, HOLDER, false, block.timestamp
        );
        IERC20(Legacy.DTF).approve(_source(), 0);
        IERC20(_source()).transfer(detf, 100);
        vm.stopPrank();
        _configureLiquid(HOLDER, q_);
        _activate();
        vm.startPrank(HOLDER);
        IERC20(_source()).approve(detf, q_);
        (uint256 bond_,) = migration.surrenderMigrationHeldSeLp(ORIGIN, q_, 1, block.timestamp);
        vm.stopPrank();
        bytes32 protected_ = _protected(bond_);
        uint256 before_ = IERC20(Legacy.DTF).balanceOf(detf);
        uint256 supply_ = IERC20(_source()).totalSupply();
        Recovery.Step[] memory steps_ = new Recovery.Step[](2);
        steps_[0] = Recovery.Step(Recovery.Stage.EarlierSeConvert, 0, q_, 1);
        steps_[1] = Recovery.Step(Recovery.Stage.Donate, 1, 1, 1);
        vm.expectRevert(Recovery.InvalidRecoveryStep.selector);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
        assertEq(IERC20(_source()).totalSupply(), supply_);
        assertEq(IERC20(_source()).balanceOf(detf), q_ + 100);
        assertEq(IERC20(Legacy.DTF).balanceOf(detf), before_);
        assertEq(recovery.migrationRecoveryInventory(_source()), q_);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);
        assertEq(_protected(bond_), protected_);
        _run(Recovery.Stage.EarlierSeConvert, 0, q_, 1);
        uint256 out_ = IERC20(Legacy.DTF).balanceOf(detf) - before_;
        assertGt(out_, 0);
        assertEq(recovery.migrationRecoveryInventory(_source()), 0);
        assertEq(IERC20(_source()).balanceOf(detf), 100);
        assertEq(IERC20(_source()).allowance(detf, _source()), 0);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), out_);
        _run(Recovery.Stage.Donate, 0, out_, 1);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), 0);
        assertEq(_protected(bond_), protected_);
    }
}
