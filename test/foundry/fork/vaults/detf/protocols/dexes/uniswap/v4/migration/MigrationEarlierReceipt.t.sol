// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationRecoveryDonationForkBase} from "./MigrationRecoveryDonation.t.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IMigrationEarlierReceipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";
import {IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice External original wallet; no source or Migration state injection.
contract EarlierReceiptReceiver is IERC721Receiver {
    Migration immutable parent;
    bytes32 immutable origin;
    bool public rejecting;
    bool public reentered;
    uint256 public donation;
    constructor(Migration parent_, bytes32 origin_) { parent = parent_; origin = origin_; }
    function approve() external { IERC20(Legacy.EARLIER_RECEIPT).approve(address(parent), type(uint256).max); }
    function arm(bool reject_, uint256 donation_) external { rejecting = reject_; donation = donation_; }
    function surrender(uint256 n_) external returns (uint256, uint256) {
        return parent.surrenderMigrationEarlierReceipt(origin, n_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (reentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationEarlierReceipt, (origin, 1, 0, block.timestamp)
        ));
        if (donation != 0) IERC20(Legacy.EARLIER_RECEIPT).transfer(address(parent), donation);
        return rejecting ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Real admitted ER bytecode and real registry Migration with synthetic original components.
contract MigrationEarlierReceiptTest is MigrationRecoveryDonationForkBase {
    bytes32 constant ORIGIN = keccak256("synthetic acquired original ER internal shares");
    address erWallet;
    IMigrationEarlierReceipt oldEr;

    function setUp() public override {
        super.setUp();
        erWallet = vm.addr(0xD7F181);
        oldEr = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT);
        assertEq(_internal(erWallet), 0);
        assertEq(oldEr.redemptionRate(), 2197);
    }

    /// @dev Diagnostic READ ONLY, never a production measurement or manufactured source state.
    function _internal(address who_) private view returns (uint256) {
        uint256 slot_ = uint256(keccak256("indexedex.vaults.protocol.richir")) + 5;
        return uint256(vm.load(Legacy.EARLIER_RECEIPT, keccak256(abi.encode(who_, slot_))));
    }

    function _acquire(address who_, uint256 n_) private returns (uint256 q_) {
        uint256 before_ = _internal(who_);
        uint256 r_ = oldEr.redemptionRate();
        vm.prank(0xBEdf78eB17A054D972c85cE222E2175F19899CD6);
        IERC20(Legacy.EARLIER_RECEIPT).transfer(who_, n_);
        q_ = _internal(who_) - before_;
        assertEq(q_, Math.mulDiv(n_, 1e27, r_));
    }

    function _config(address who_, uint256 q_) private returns (uint256 c_) {
        Migration.EarlierReceiptEntitlementInput[] memory a_ = new Migration.EarlierReceiptEntitlementInput[](1);
        a_[0] = Migration.EarlierReceiptEntitlementInput(
            ORIGIN, who_, Legacy.EARLIER_RECEIPT, q_, 0.01 ether, 0,
            keccak256("synthetic known components; genuine original ER acquisition"), true
        );
        vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(a_);
        c_ = migration.earlierReceiptEntitlement(ORIGIN).credit;
        assertEq(c_, migration.previewOriginalCredit(0.01 ether, 0));
    }

    function _state(address who_) private view returns (bytes32) {
        return keccak256(abi.encode(
            _internal(who_), _internal(detf), oldEr.redemptionRate(), oldEr.totalShares(),
            IERC20(Legacy.EARLIER_RECEIPT).allowance(who_, detf),
            migration.earlierReceiptSurrender(ORIGIN), recovery.migrationEarlierReceiptInternalShares(),
            recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT),
            IERC20(detf).totalSupply(), receipt.stakingState(), receipt.gonsOf(address(bonds)),
            IERC20(detf).balanceOf(address(receipt)), IERC20(detf).allowance(detf, address(bonds))
        ));
    }

    function _pull(uint256 n_) private returns (uint256 id_, uint256 credit_) {
        Migration.EarlierReceiptSurrender memory before_ = migration.earlierReceiptSurrender(ORIGIN);
        uint256 wallet_ = _internal(erWallet);
        uint256 custody_ = _internal(detf);
        uint256 booked_ = recovery.migrationEarlierReceiptInternalShares();
        uint256 q_ = Math.mulDiv(n_, 1e27, oldEr.redemptionRate());
        vm.startPrank(erWallet);
        IERC20(Legacy.EARLIER_RECEIPT).approve(detf, n_);
        (id_, credit_) = migration.surrenderMigrationEarlierReceipt(ORIGIN, n_, 1, block.timestamp);
        vm.stopPrank();
        assertEq(credit_, q_ == before_.remainingUnits
            ? before_.remainingCredit : Math.mulDiv(before_.remainingCredit, q_, before_.remainingUnits));
        assertEq(wallet_ - _internal(erWallet), q_);
        assertEq(_internal(detf) - custody_, q_);
        assertEq(recovery.migrationEarlierReceiptInternalShares() - booked_, q_);
        Migration.EarlierReceiptSurrender memory after_ = migration.earlierReceiptSurrender(ORIGIN);
        assertEq(after_.remainingUnits, before_.remainingUnits - q_);
        assertEq(after_.remainingCredit, before_.remainingCredit - credit_);
        assertEq(after_.consumedUnits, before_.consumedUnits + q_);
        assertEq(after_.deliveredCredit, before_.deliveredCredit + credit_);
        assertEq(IERC721(address(bonds)).ownerOf(id_), erWallet);
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(bonds.positionOf(id_).vestingDuration, 90 days);
        assertEq(bonds.positionOf(id_).startTimestamp, vm.getBlockTimestamp());
        assertEq(bonds.positionOf(id_).stakingGons, credit_ * receipt.stakingState().gonsPerUnit);
        assertTrue(bonds.isMigrationPosition(id_));
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    function test_bothEndpointCarriesPreserveUnrelatedInternalFractions() public {
        _config(erWallet, _acquire(erWallet, 10000));
        uint256 unrelated_ = _acquire(detf, 1);
        _activate();
        uint256 w_ = oldEr.sharesOf(erWallet);
        uint256 m_ = oldEr.sharesOf(detf);
        uint256 q_ = Math.mulDiv(4, 1e27, 2197);
        _pull(4);
        assertEq(w_ - oldEr.sharesOf(erWallet), q_ / 1e9);
        assertEq(oldEr.sharesOf(detf) - m_, q_ / 1e9 + 1);
        w_ = oldEr.sharesOf(erWallet); m_ = oldEr.sharesOf(detf);
        q_ = Math.mulDiv(1, 1e27, 2197);
        _pull(1);
        assertEq(w_ - oldEr.sharesOf(erWallet), q_ / 1e9 + 1);
        assertEq(oldEr.sharesOf(detf) - m_, q_ / 1e9);
        assertEq(_internal(detf) - recovery.migrationEarlierReceiptInternalShares(), unrelated_);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT), 0);
    }

    function test_genuineDivisibleTerminalTakesAllFrozenCreditIntoFreshCliffs() public {
        uint256 q0_ = _acquire(erWallet, 4394);
        assertEq(q0_, 2e27);
        uint256 c0_ = _config(erWallet, q0_);
        uint256 unrelated_ = _acquire(detf, 1);
        _activate();
        (uint256 first_, uint256 c1_) = _pull(2197);
        vm.warp(vm.getBlockTimestamp() + 1);
        (uint256 last_, uint256 c2_) = _pull(2197);
        assertNotEq(first_, last_);
        assertEq(c1_ + c2_, c0_);
        assertEq(bonds.positionOf(last_).startTimestamp, bonds.positionOf(first_).startTimestamp + 1);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingUnits, 0);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingCredit, 0);
        assertEq(_internal(detf) - recovery.migrationEarlierReceiptInternalShares(), unrelated_);
    }

    function test_actualOneMoreThanDisplayedBalanceIsNotAnInputCap() public {
        uint256 q0_ = _acquire(erWallet, 1);
        assertEq(IERC20(Legacy.EARLIER_RECEIPT).balanceOf(erWallet), 0);
        uint256 c0_ = _config(erWallet, q0_);
        _activate();
        (, uint256 credit_) = _pull(1);
        assertEq(credit_, c0_);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingUnits, 0);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingCredit, 0);
    }

    function test_positiveNonrepresentableResidueRetainsQAndCAndRejectsExtraInput() public {
        uint256 c0_ = _config(erWallet, _acquire(erWallet, 2197));
        _activate(); _pull(1); _pull(2196);
        Migration.EarlierReceiptSurrender memory s_ = migration.earlierReceiptSurrender(ORIGIN);
        assertEq(s_.remainingUnits, 1);
        assertEq(s_.remainingCredit, 1);
        assertEq(s_.deliveredCredit + s_.remainingCredit, c0_);
        assertEq(_internal(erWallet), 1);
        assertEq(IERC20(Legacy.EARLIER_RECEIPT).balanceOf(erWallet), 0);
        _acquire(erWallet, 1);
        vm.prank(erWallet); IERC20(Legacy.EARLIER_RECEIPT).approve(detf, 1);
        bytes32 before_ = _state(erWallet);
        vm.prank(erWallet);
        vm.expectRevert(abi.encodeWithSelector(
            Migration.InvalidEarlierReceiptQuantity.selector, uint256(1e27) / 2197, 1
        ));
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp);
        assertEq(_state(erWallet), before_);
    }

    function test_actualRateDonationDoesNotRepriceOriginalOrBookUnrelatedShares() public {
        uint256 c0_ = _config(erWallet, _acquire(erWallet, 10000));
        uint256 unrelated_ = _acquire(detf, 1);
        _activate(); _pull(4);
        IERC20(Legacy.DTF).transfer(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7, 100 ether);
        assertGt(oldEr.redemptionRate(), 2197);
        _pull(1);
        assertEq(migration.earlierReceiptEntitlement(ORIGIN).credit, c0_);
        assertEq(migration.earlierReceiptSurrender(ORIGIN).remainingCredit
            + migration.earlierReceiptSurrender(ORIGIN).deliveredCredit, c0_);
        assertEq(_internal(detf) - recovery.migrationEarlierReceiptInternalShares(), unrelated_);
    }

    function test_stageOneMissingWalletTransferBackAndSourceMinimumDeadlineRollback() public {
        _config(erWallet, _acquire(erWallet, 10000));
        bytes32 before_ = _state(erWallet);
        vm.prank(erWallet); vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp);
        assertEq(_state(erWallet), before_);
        _activate();
        vm.prank(erWallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierReceiptEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationEarlierReceipt(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(erWallet);
        (bool ok_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationEarlierReceipt, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(ok_); assertEq(_state(erWallet), before_);
        vm.prank(erWallet); IERC20(Legacy.EARLIER_RECEIPT).transfer(address(this), 1);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalEarlierReceiptWallet.selector, address(this), erWallet));
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp);
        IERC20(Legacy.EARLIER_RECEIPT).transfer(erWallet, 1);
        vm.prank(erWallet); IERC20(Legacy.EARLIER_RECEIPT).approve(detf, 10000);
        before_ = _state(erWallet);
        vm.prank(erWallet);
        (ok_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationEarlierReceipt,
            (ORIGIN, 1, type(uint256).max, block.timestamp)));
        assertFalse(ok_); assertEq(_state(erWallet), before_);
        vm.prank(erWallet); vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp - 1);
        assertEq(_state(erWallet), before_);
        _pull(1);
    }

    function test_zeroCreditRollsBackAnActualApprovedPull() public {
        uint256 q0_ = _acquire(erWallet, 10000);
        Migration.EarlierReceiptEntitlementInput[] memory a_ = new Migration.EarlierReceiptEntitlementInput[](1);
        a_[0] = Migration.EarlierReceiptEntitlementInput(
            ORIGIN, erWallet, Legacy.EARLIER_RECEIPT, q0_, 1e10, 0,
            keccak256("synthetic small known components; genuine acquisition denominator"), true
        );
        vm.prank(migrationOwner); allocation.configureEarlierReceiptEntitlements(a_);
        uint256 c0_ = migration.earlierReceiptEntitlement(ORIGIN).credit;
        assertGt(c0_, 0);
        assertLt(c0_, 10000);
        _activate();
        vm.prank(erWallet); IERC20(Legacy.EARLIER_RECEIPT).approve(detf, 1);
        bytes32 before_ = _state(erWallet);
        vm.prank(erWallet); vm.expectRevert(abi.encodeWithSelector(Migration.InvalidEarlierReceiptEntitlement.selector, ORIGIN));
        migration.surrenderMigrationEarlierReceipt(ORIGIN, 1, 0, block.timestamp);
        assertEq(_state(erWallet), before_);
    }

    function test_lateReceiverRollbackReentryAndLaterDonationRemainSeparate() public {
        EarlierReceiptReceiver wallet_ = new EarlierReceiptReceiver(migration, ORIGIN);
        _config(address(wallet_), _acquire(address(wallet_), 10000));
        wallet_.approve();
        _activate();
        wallet_.arm(true, 1);
        bytes32 before_ = _state(address(wallet_));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(4);
        assertEq(_state(address(wallet_)), before_);
        wallet_.arm(false, 1);
        (uint256 id_, uint256 credit_) = wallet_.surrender(4);
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(wallet_));
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertFalse(wallet_.reentered());
        uint256 q_ = Math.mulDiv(4, 1e27, oldEr.redemptionRate());
        assertEq(recovery.migrationEarlierReceiptInternalShares(), q_);
        assertEq(_internal(detf) - q_, Math.mulDiv(1, 1e27, oldEr.redemptionRate()));
        assertEq(migration.earlierReceiptSurrender(ORIGIN).consumedUnits, q_);
    }

    function test_nftExternalAndStandaloneInternalInventoryMixInBothArrivalOrders() public {
        for (uint256 order_; order_ < 2; ++order_) {
            uint256 snap_ = vm.snapshotState();
            _config(erWallet, _acquire(erWallet, 10000));
            _configureNft(EARLIER, 3);
            uint256 unrelated_ = _acquire(detf, 1);
            _activate();
            if (order_ == 0) _pull(4);
            _surrender(EARLIER, 3);
            vm.warp(IMigrationEarlierNft(EARLIER).getPosition(3).unlockTime);
            _run(Recovery.Stage.EarlierSale, 3, 0, 1);
            uint256 e_ = recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT);
            assertGt(e_, 0);
            if (order_ == 1) _pull(4);
            uint256 b_ = recovery.migrationEarlierReceiptInternalShares();
            assertGt(b_ % 1e9, 0);
            assertEq(_internal(detf) - (e_ * 1e9 + b_), unrelated_);
            assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_RECEIPT), e_);
            assertEq(recovery.migrationNftRecovery(EARLIER, 3).receiptShares, e_);
            assertTrue(vm.revertToStateAndDelete(snap_));
        }
    }
}
