// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {MigrationWeightedReceiptForkBase} from "./MigrationWeightedReceiptForkBase.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Actual original contract-wallet acquisition and rejecting/attempted reentrant bond callback.
contract WeightedReceiptReceiver is IERC721Receiver {
    Migration immutable parent;
    bytes32 immutable origin;
    bool public rejecting;
    bool public reentered;
    constructor(Migration parent_, bytes32 origin_) { parent = parent_; origin = origin_; }
    function reject(bool value_) external { rejecting = value_; }
    function surrender(uint256 n_) external returns (uint256, uint256) {
        IERC20(Legacy.WEIGHTED_RECEIPT).approve(address(parent), n_);
        return parent.surrenderMigrationWeightedReceipt(origin, n_, 1, block.timestamp);
    }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (reentered,) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationWeightedReceipt, (origin, 1, 0, block.timestamp)
        ));
        return rejecting ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual legacy bytecode composed with a registry-deployed Migration, not a source-only probe.
contract MigrationWeightedReceiptTest is MigrationWeightedReceiptForkBase {
    function test_partialAndDivisibleTerminalConsumeExactGonsAndCreateFreshFundedCliffs() public {
        uint256 c0_ = _configureWs(wsWallet, acquiredGons);
        _activate();
        (uint256 first_, uint256 c1_) = _surrenderWs(1);
        assertEq(c1_, c0_ / 101);
        (uint256 final_, uint256 c2_) = _surrenderWs(100);
        assertNotEq(first_, final_);
        assertEq(c1_ + c2_, c0_);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).remainingUnits, 0);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).remainingCredit, 0);
        assertEq(oldReceipt.gonsOf(wsWallet), 0);
        assertEq(recovery.migrationRecoveryGons(), acquiredGons);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_RECEIPT), 101);
    }

    function test_growthLeavesPositiveNonrepresentableResidualWithoutClearingOrRepricing() public {
        uint256 c0_ = _configureWs(wsWallet, acquiredGons);
        _activate();
        uint256 k0_ = oldReceipt.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        (uint256 first_,) = _surrenderWs(1);
        assertLt(oldReceipt.stakingState().gonsPerUnit, k0_);
        vm.warp(vm.getBlockTimestamp() + 1);
        (uint256 last_,) = _surrenderWs(100);
        assertNotEq(first_, last_);
        assertEq(bonds.positionOf(last_).startTimestamp, bonds.positionOf(first_).startTimestamp + 1);
        Migration.WeightedReceiptSurrender memory s_ = migration.weightedReceiptSurrender(WS_ORIGIN);
        assertGt(s_.remainingUnits, 0);
        assertLt(s_.remainingUnits, oldReceipt.stakingState().gonsPerUnit);
        assertGt(s_.remainingCredit, 0);
        assertEq(s_.remainingCredit + s_.deliveredCredit, c0_);
        assertEq(oldReceipt.gonsOf(wsWallet), s_.remainingUnits);
        assertEq(IERC20(Legacy.WEIGHTED_RECEIPT).balanceOf(wsWallet), 0);
        assertEq(migration.weightedReceiptEntitlement(WS_ORIGIN).credit, c0_);
        _acquireWs(wsWallet, 1); // Actual additional custody does not increase original eligibility.
        vm.prank(wsWallet); IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 1);
        bytes32 before_ = _wsEconomicState(wsWallet);
        uint256 k_ = oldReceipt.stakingState().gonsPerUnit;
        vm.prank(wsWallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptQuantity.selector, k_, s_.remainingUnits));
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 0, block.timestamp);
        assertEq(_wsEconomicState(wsWallet), before_);
        vm.prank(wsWallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, WS_ORIGIN));
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 0, 0, block.timestamp);
        assertEq(_wsEconomicState(wsWallet), before_);
    }

    function test_stageOneAbsentWalletTransferAndReturnCannotMoveOrRestoreCredit() public {
        _configureWs(wsWallet, acquiredGons);
        vm.prank(wsWallet); IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 101);
        bytes32 before_ = _wsEconomicState(wsWallet);
        vm.prank(wsWallet); vm.expectRevert(Migration.MigrationSurrenderClosed.selector);
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 0, block.timestamp);
        assertEq(_wsEconomicState(wsWallet), before_);
        _activate();
        vm.prank(wsWallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, bytes32("absent")));
        migration.surrenderMigrationWeightedReceipt(bytes32("absent"), 1, 0, block.timestamp);
        vm.prank(wsWallet); IERC20(Legacy.WEIGHTED_RECEIPT).transfer(address(this), 1);
        IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 1);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedReceiptWallet.selector, address(this), wsWallet));
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 0, block.timestamp);
        IERC20(Legacy.WEIGHTED_RECEIPT).transfer(wsWallet, 1);
        _surrenderWs(1);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).consumedUnits,
            oldReceipt.stakingState().gonsPerUnit);
        Migration.WeightedReceiptEntitlementInput[] memory a_ = _wsInputs(wsWallet, acquiredGons);
        vm.prank(migrationOwner);
        (bool restored_,) = detf.call(abi.encodeCall(Allocation.configureWeightedReceiptEntitlements, (a_)));
        assertFalse(restored_);
        _surrenderWs(100);
    }

    function test_sourceFailureAfterDueSynchronizationAndMinimumDeadlineRollback() public {
        _configureWs(wsWallet, acquiredGons);
        _activate();
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        bytes32 before_ = _wsEconomicState(wsWallet);
        vm.prank(wsWallet);
        (bool ok_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedReceipt, (WS_ORIGIN, 1, 0, block.timestamp)));
        assertFalse(ok_); // Missing actual native allowance; preceding WD funding must roll back too.
        assertEq(_wsEconomicState(wsWallet), before_);
        vm.prank(wsWallet); IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 101);
        before_ = _wsEconomicState(wsWallet);
        vm.prank(wsWallet);
        (ok_,) = detf.call(abi.encodeCall(Migration.surrenderMigrationWeightedReceipt,
            (WS_ORIGIN, 1, type(uint256).max, block.timestamp)));
        assertFalse(ok_);
        assertEq(_wsEconomicState(wsWallet), before_);
        vm.prank(wsWallet);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired(uint256)", block.timestamp - 1));
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 0, block.timestamp - 1);
        assertEq(_wsEconomicState(wsWallet), before_);
        _surrenderWs(1);
    }

    function test_zeroCreditRejectsActualApprovedCustodyWithoutConfiscation() public {
        _configureWs(wsWallet, type(uint256).max);
        _activate();
        vm.prank(wsWallet); IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 1);
        bytes32 before_ = _wsEconomicState(wsWallet);
        vm.prank(wsWallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedReceiptEntitlement.selector, WS_ORIGIN));
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 0, block.timestamp);
        assertEq(_wsEconomicState(wsWallet), before_);
    }

    function test_realRoleWalletSettlementExcludesNewlyIssuedRoleGons() public {
        address role_ = IERC721(WEIGHTED).ownerOf(2);
        assertEq(role_.code.length, 0);
        uint256 q0_ = _acquireWs(role_, 3);
        uint256 c0_ = _configureWs(role_, q0_);
        _activate();
        uint256 roleBefore_ = oldReceipt.gonsOf(role_);
        uint256 k0_ = oldReceipt.stakingState().gonsPerUnit;
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        vm.startPrank(role_);
        IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 1);
        (, uint256 credit_) = migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 1, block.timestamp);
        vm.stopPrank();
        uint256 k_ = oldReceipt.stakingState().gonsPerUnit;
        assertLt(k_, k0_);
        assertGt(oldReceipt.gonsOf(role_) + k_, roleBefore_);
        assertEq(oldReceipt.gonsOf(detf), k_);
        assertEq(recovery.migrationRecoveryGons(), k_);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).consumedUnits, k_);
        assertEq(credit_, c0_ * k_ / q0_);
    }

    function test_actualRoleNftTransferMakesCustodyRewardsUnbookedNotSurrender() public {
        _configureWs(wsWallet, acquiredGons);
        _activate();
        address role_ = IERC721(WEIGHTED).ownerOf(2);
        // A real authorized NFT transfer, not a source storage/role substitution.
        vm.prank(role_);
        IERC721(WEIGHTED).transferFrom(role_, detf, 2);
        assertEq(IERC721(WEIGHTED).ownerOf(2), detf);
        uint256 custody_ = oldReceipt.gonsOf(detf);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        vm.startPrank(wsWallet);
        IERC20(Legacy.WEIGHTED_RECEIPT).approve(detf, 1);
        migration.surrenderMigrationWeightedReceipt(WS_ORIGIN, 1, 1, block.timestamp);
        vm.stopPrank();
        uint256 q_ = oldReceipt.stakingState().gonsPerUnit;
        assertEq(recovery.migrationRecoveryGons(), q_);
        assertGt(oldReceipt.gonsOf(detf) - custody_, q_);
        assertEq(migration.weightedReceiptSurrender(WS_ORIGIN).consumedUnits, q_);
    }

    function test_lateBondCallbackRevertsSourceFundingCustodyAndCreditThenRejectsReentry() public {
        WeightedReceiptReceiver wallet_ = new WeightedReceiptReceiver(migration, WS_ORIGIN);
        uint256 q0_ = _acquireWs(address(wallet_), 3);
        _configureWs(address(wallet_), q0_);
        _activate();
        wallet_.reject(true);
        vm.warp(vm.getBlockTimestamp() + 8 hours);
        bytes32 before_ = _wsEconomicState(address(wallet_));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(wallet_)));
        wallet_.surrender(1);
        assertEq(_wsEconomicState(address(wallet_)), before_);
        wallet_.reject(false);
        (uint256 id_, uint256 credit_) = wallet_.surrender(1);
        assertEq(IERC721(address(bonds)).ownerOf(id_), address(wallet_));
        assertEq(bonds.positionOf(id_).principal, credit_);
        assertFalse(wallet_.reentered());
    }
}
