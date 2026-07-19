// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial,
    AdvRecordingReentrantShare,
    AdvReentryTarget
} from "test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice C1–C3 reentrancy expansion: nested DETF entries during hostile share transferFrom → IsLocked.
/// @dev Deferred P2: C4 (redeemClaim→exchangeIn via hostile rateAsset without breaking SE),
///      C5 (read-only reentrancy on preview — preview is view-safe by construction).
contract Adversarial_Reentrancy_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_C1_reenterInitializeReserve_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        _assertInert(instance_);

        // Fund a second reserve attempt that will reenter during first initializeReserve transferFrom.
        uint256[] memory nestedAmounts_ = new uint256[](1);
        nestedAmounts_[0] = 1e18;
        bytes memory reentry = abi.encodeCall(
            AdvReentryTarget.reenterInitializeReserve,
            (instance_, nestedAmounts_, block.timestamp + 1 hours)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 5_000e18;
        vm.startPrank(alice);
        hostileShare.approve(instance_, type(uint256).max);
        uint256 bpt_ = IMultiVaultWeightedDetfBonding(instance_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "C1 reentry attempted");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested initializeReserve blocked");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "C1 IsLocked"
        );
        assertTrue(bpt_ > 0, "outer initializeReserve completed");
        assertFalse(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "still inert until bond");
        hostileShare.disarm();

        // Finish go-live cleanly
        vm.startPrank(alice);
        address pool_ = IMultiVaultWeightedDetfInfo(instance_).reservePool();
        IERC20(pool_).approve(instance_, bpt_);
        IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(pool_), bpt_, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertLive(instance_);
    }

    function test_C2_reenterRedeemClaim_duringMint_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        _goLiveHostile(instance_, alice, 5_000e18);
        _assertLive(instance_);

        // Seed claim inventory for a real redeem attempt (nested will still be locked).
        // Attacker has no claim; nested call should hit IsLocked before claim checks anyway.
        bytes memory reentry = abi.encodeCall(
            AdvReentryTarget.reenterRedeemClaim,
            (instance_, uint256(1e18), rateAssets[0], attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 amountIn_ = 50e18;
        vm.startPrank(attacker);
        hostileShare.approve(instance_, amountIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(hostileShare)),
            amountIn_,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "outer mint ok");
        assertEq(hostileShare.reentryAttempts(), 1, "C2 reentry attempted");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested redeemClaim blocked");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "C2 IsLocked"
        );
        hostileShare.disarm();
    }

    function test_C3_mintReenterBond_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        _goLiveHostile(instance_, alice, 5_000e18);

        bytes memory reentry = abi.encodeCall(
            AdvReentryTarget.reenterBond,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 amountIn_ = 50e18;
        uint256 balBefore_ = IERC20(instance_).balanceOf(attacker);
        vm.startPrank(attacker);
        hostileShare.approve(instance_, amountIn_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(hostileShare)),
            amountIn_,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "C3 reentry attempted");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested bond blocked");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "C3 IsLocked"
        );
        assertGe(IERC20(instance_).balanceOf(attacker), balBefore_, "outer mint continued");
        hostileShare.disarm();
    }
}
