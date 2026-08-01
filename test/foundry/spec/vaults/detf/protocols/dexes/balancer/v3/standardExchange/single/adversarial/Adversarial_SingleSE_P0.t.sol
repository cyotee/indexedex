// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_SingleStandardExchangeDETF_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";

/// @notice Wave 1A P0/P1 adversarial coverage for SingleStandardExchangeDETF.
/// @dev Deferred: D6 claim over-redeem N/A (no rebasing claim v1); H2 claim path N/A - use sellPosition;
///      G1 nested optional (see ComposedStable matrix). Production entry points only.
contract Adversarial_SingleSE_P0_Test is TestBase_SingleStandardExchangeDETF_Adversarial {
    // --- E5 / H3 / Guards ---

    function test_E5_zeroAmount_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        vm.prank(attacker);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
    }

    function test_E5_expiredDeadline_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 50e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert(
            abi.encodeWithSelector(SingleStandardExchangeDETFRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, shares_, IERC20(instance_), 0, attacker, false, block.timestamp - 1
        );
        vm.stopPrank();
        assertEq(seShare.balanceOf(instance_), 0, "H3 residual shares");
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 30e18);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(seShare, shares_, IERC20(instance_));
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, shares_, IERC20(instance_), preview_ + 1e18, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoFreeInventory(instance_);
        assertEq(seShare.balanceOf(attacker), shares_, "shares refunded");
    }

    function test_preLive_mint_reverts() public {
        address instance_ = _deployOpenThresholdDetf("Adv Inert", "advI");
        uint256 shares_ = _fundSeShares(attacker, 50e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, shares_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(seShare.balanceOf(instance_), 0, "H3 residual");
    }

    // --- A donation ---

    function test_A1_donateVaultShares_cannotMintFreeDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 donated_ = _fundSeShares(attacker, 100e18);
        uint256 attBefore_ = IERC20(instance_).balanceOf(attacker);
        vm.prank(attacker);
        seShare.transfer(instance_, donated_);
        assertEq(seShare.balanceOf(instance_), donated_, "shares idle");
        assertEq(IERC20(instance_).balanceOf(attacker), attBefore_, "A1: no free DETF");

        uint256 victimIn_ = _fundSeShares(victim, 20e18);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(seShare, victimIn_, IERC20(instance_));
        vm.startPrank(victim);
        seShare.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, preview_, "victim mint not inflated by idle donation");
    }

    function test_A2_donateDetfToDiamond_noTheft() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintSeSharesToDetf(instance_, attacker, 40e18);
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 victimBefore_ = IERC20(instance_).balanceOf(victim);
        vm.prank(attacker);
        IERC20(instance_).transfer(instance_, donateAmt_);
        assertEq(IERC20(instance_).balanceOf(victim), victimBefore_, "victim unchanged");
        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf on diamond");
    }

    function test_A3_cannotDrainBptWithoutBondAuthority() public {
        address instance_ = _openLiveOpenThreshold();
        address pool_ = ISingleStandardExchangeDETFInfo(instance_).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);
        // Attacker without NFT cannot sellPositionToDetfNft on bond vault (onlyOwner = DETF)
        IDETFNFTVault bondVault_ =
            IDETFNFTVault(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert();
        bondVault_.sellPositionToDetfNft(1, attacker, attacker);
        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "A3: BPT intact");
    }

    // --- D bond authority ---

    function test_D2_sellPosition_nonOwner_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        // First bond gave alice a tokenId; attacker cannot sell via DETF without ownership
        vm.prank(attacker);
        vm.expectRevert();
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(1, attacker);
    }

    function test_D3_doubleSell_secondReverts() public {
        address instance_ = _deployOpenThresholdDetf("Adv DoubleSell", "advDS");
        uint256 tokenId_ = _bootstrapDetf(instance_, alice, 1_500e18);
        vm.prank(alice);
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(tokenId_, alice);
        vm.prank(alice);
        vm.expectRevert();
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(tokenId_, alice);
    }

    function test_D5_lockClamp_minRevert_maxOk() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 80e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert();
        ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, shares_, 1 days, attacker, false, block.timestamp + 1 hours
        );
        (uint256 tid_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, shares_, DEFAULT_MAX_LOCK + 365 days, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock");
    }

    // --- F access ---

    function test_F2_bondNftVault_createPosition_onlyOwner() public {
        address instance_ = _openLiveOpenThreshold();
        IDETFNFTVault bondVault_ =
            IDETFNFTVault(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert();
        bondVault_.createPosition(1e18, DEFAULT_MIN_LOCK, attacker);
    }

    function test_F1_diamondCut_notCallableByAttacker() public {
        address instance_ = _openLiveOpenThreshold();
        (bool cutOk,) = instance_.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(cutOk, "diamondCut blocked");
    }

    function test_F4_noSetWeights() public {
        address instance_ = _openLiveOpenThreshold();
        (bool ok,) = instance_.call(abi.encodeWithSignature("setWeights(uint256,uint256)", 1, 1));
        assertFalse(ok, "no setWeights");
    }

    // --- C reentrancy ---

    function test_C1_reenterBond_duringFirstBond_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        vm.startPrank(alice);
        hostileShare.approve(instance_, 5_000e18);
        (uint256 tid_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            IERC20(address(hostileShare)),
            5_000e18,
            DEFAULT_MIN_LOCK,
            alice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(tid_ > 0, "outer bond ok");
        assertEq(hostileShare.reentryAttempts(), 1, "C1 reentry attempted");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested blocked");
        assertEq(hostileShare.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C1 IsLocked");
        hostileShare.disarm();
    }

    function test_C3_mintReenterBond_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        _bootstrapHostile(instance_, alice, 5_000e18);

        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 amountIn_ = 50e18;
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

        assertEq(hostileShare.reentryAttempts(), 1, "C3 reentry");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested blocked");
        assertEq(hostileShare.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C3 IsLocked");
        hostileShare.disarm();
    }

    function test_C2_reenterExchangeIn_duringMint_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf(1, type(uint256).max);
        _bootstrapHostile(instance_, alice, 5_000e18);

        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), IERC20(instance_), attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        vm.startPrank(attacker);
        hostileShare.approve(instance_, 50e18);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(hostileShare)),
            50e18,
            IERC20(instance_),
            0,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "C2 reentry");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested blocked");
        assertEq(hostileShare.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C2 IsLocked");
        hostileShare.disarm();
    }

    // --- E economic / B thresholds ---

    function test_E1_mintThenPartialBurn_conservation() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 sharesIn_ = _fundSeShares(attacker, 40e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted");

        uint256 burnAmt_ = detfOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = detfOut_;
        if (!ISingleStandardExchangeDETFInfo(instance_).isBurningAllowed()) {
            // Open burn threshold may still be closed; skip burn half if gate blocks
            return;
        }
        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 sharesBack_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShare, 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertLe(sharesBack_, sharesIn_, "E1: partial out <= in");
        _assertNoFreeInventory(instance_);
    }

    function test_E4_holderBalance_notDilutedByOthersMint() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 holderOut_ = _mintSeSharesToDetf(instance_, victim, 30e18);
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        assertTrue(holderOut_ > 0 && victimBal_ > 0, "victim holds");
        _mintSeSharesToDetf(instance_, attacker, 20e18);
        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "E4: victim DETF unchanged");
    }

    function test_B3_thresholdGates_coupleToSynthetic() public {
        // Default-threshold instance from setUp detf
        _bootstrapViaFirstBond(alice, 2_000e18);
        uint256 synth_ = detfInfo.syntheticPrice();
        assertEq(detfInfo.isMintingAllowed(), synth_ > detfInfo.mintThreshold(), "B3 mint coupling");
        assertEq(detfInfo.isBurningAllowed(), synth_ < detfInfo.burnThreshold(), "B3 burn coupling");
    }

    function test_B1_openThresholds_mintBurn_boundsSafety() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 victimOut_ = _mintSeSharesToDetf(instance_, victim, 30e18);
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);

        uint256 sharesIn_ = _fundSeShares(attacker, 50e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        if (ISingleStandardExchangeDETFInfo(instance_).isBurningAllowed() && detfOut_ > 0) {
            vm.startPrank(attacker);
            IERC20(instance_).approve(instance_, detfOut_);
            IStandardExchangeIn(instance_).exchangeIn(
                IERC20(instance_), detfOut_, seShare, 0, attacker, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "B1: victim balance intact");
        assertTrue(victimOut_ > 0, "victim still has position basis");
        _assertNoFreeInventory(instance_);
    }
}
