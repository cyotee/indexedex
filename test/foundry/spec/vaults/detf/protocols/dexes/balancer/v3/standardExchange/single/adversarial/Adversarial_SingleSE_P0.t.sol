// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";
import {
    TestBase_SingleStandardExchangeDETF_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {
    ILegacySingleStandardExchangeDETFBonding as ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ILegacySingleStandardExchangeDETFInfo as ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";

/// @notice Wave 1A P0/P1 adversarial coverage for SingleStandardExchangeDETF.
/// @dev Funded bond claims and staking redemption use the deployed child contracts.
contract Adversarial_SingleSE_P0_Test is
    TestBase_SingleStandardExchangeDETF_Adversarial,
    FundedBondLifecycleAssertions
{
    // --- E5 / H3 / Guards ---

    function test_E5_zeroAmount_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        vm.prank(attacker);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_)
            .exchangeIn(seShare, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);
    }

    function test_E5_expiredDeadline_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 50e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert(
            abi.encodeWithSelector(SingleStandardExchangeDETFRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        IStandardExchangeIn(instance_)
            .exchangeIn(seShare, shares_, IERC20(instance_), 0, attacker, false, block.timestamp - 1);
        vm.stopPrank();
        assertEq(seShare.balanceOf(instance_), 0, "H3 residual shares");
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 30e18);
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(seShare, shares_, IERC20(instance_));
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert();
        IStandardExchangeIn(instance_)
            .exchangeIn(
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
        IStandardExchangeIn(instance_)
            .exchangeIn(seShare, shares_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);
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
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(seShare, victimIn_, IERC20(instance_));
        vm.startPrank(victim);
        seShare.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShare, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours);
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
        IDetfBondNFT nft_ = IDetfBondNFT(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        IERC20 lp_ = nft_.lpToken();
        uint256 held_ = lp_.balanceOf(address(nft_));
        assertGt(held_, 0, "protocol holds funded reserve LP");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", attacker));
        nft_.transferHeldToken(lp_, attacker, held_);
        assertEq(lp_.balanceOf(address(nft_)), held_, "reserve LP intact");
        assertEq(lp_.balanceOf(attacker), 0, "no LP extracted");
    }

    // --- D bond authority ---

    function test_D2_claimBond_nonOwner_reverts() public {
        address instance_ = _deployOpenThresholdDetf("Adv Claim Authority", "advCA");
        uint256 id_ = _bootstrapDetf(instance_, alice, 1_500e18);
        IDetfBondNFT nft_ = IDetfBondNFT(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", attacker));
        nft_.claimBond(id_, attacker);
        assertEq(nft_.ownerOf(id_), alice, "owner unchanged");
        assertEq(nft_.positionOf(id_).claimedPrincipal, 0, "principal untouched");
    }

    function test_D3_fullBondClaim_retiresPosition() public {
        address instance_ = _deployOpenThresholdDetf("Adv Double Claim", "advDC");
        uint256 id_ = _bootstrapDetf(instance_, alice, 1_500e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        IDetfBondNFT nft_ = IDetfBondNFT(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        uint256 held_ = _fundedBondStaking(instance_).balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", id_));
        nft_.claimBond(id_, alice);
        assertEq(_fundedBondStaking(instance_).balanceOf(alice), held_, "no second payout");
    }

    function test_D5_lockClamp_minRevert_maxOk() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 shares_ = _fundSeShares(attacker, 80e18);
        vm.startPrank(attacker);
        seShare.approve(instance_, shares_);
        vm.expectRevert();
        ISingleStandardExchangeDETFBonding(instance_)
            .bond(seShare, shares_, 1 days, attacker, false, block.timestamp + 1 hours);
        (uint256 tid_,) = ISingleStandardExchangeDETFBonding(instance_)
            .bond(seShare, shares_, DEFAULT_MAX_LOCK + 365 days, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock");
    }

    function test_D6_cannotUnstakeMoreThanFundedBalance() public {
        address instance_ = _deployOpenThresholdDetf("Adv Funded D6", "advD6");
        uint256 id_ = _bootstrapDetf(instance_, alice, 2_500e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        uint256 held_ = _fundedBondStaking(instance_).balanceOf(alice);
        _assertFundedUnstakeRejected(instance_, alice, held_ + 1, IERC20(instance_), 0);
        _assertFundedUnstake(instance_, alice, held_ / 5);
        _assertFundedUnstakeRejected(instance_, alice, held_, IERC20(instance_), 0);
    }

    function test_H2_unstake_minOutTooHigh_balanceUnchanged() public {
        address instance_ = _deployOpenThresholdDetf("Adv Funded H2", "advH2");
        uint256 id_ = _bootstrapDetf(instance_, alice, 2_000e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        uint256 amount_ = _fundedBondStaking(instance_).balanceOf(alice) / 5;
        _assertFundedUnstakeRejected(instance_, alice, amount_, IERC20(instance_), amount_ + 1);
        _assertFundedUnstake(instance_, alice, amount_);
    }

    // --- F access ---

    function test_F2_bondNftVault_createFundedPosition_onlyDetf() public {
        address instance_ = _openLiveOpenThreshold();
        IDetfBondNFT nft_ = IDetfBondNFT(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", attacker));
        nft_.createFundedPosition(1e9, DEFAULT_MIN_LOCK, attacker);
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
        (uint256 tid_,) = ISingleStandardExchangeDETFBonding(instance_)
            .bond(IERC20(address(hostileShare)), 5_000e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours);
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
        IStandardExchangeIn(instance_)
            .exchangeIn(
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
        IStandardExchangeIn(instance_)
            .exchangeIn(
                IERC20(address(hostileShare)), 50e18, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
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
        uint256 detfOut_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShare, sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted");

        uint256 burnAmt_ = detfOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = detfOut_;
        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 sharesBack_ = IStandardExchangeIn(instance_)
            .exchangeIn(IERC20(instance_), burnAmt_, seShare, 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(sharesBack_, 0, "partial redemption executes");
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
        uint256 detfOut_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShare, sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertGt(detfOut_, 0, "attacker funded DETF");
        {
            vm.startPrank(attacker);
            IERC20(instance_).approve(instance_, detfOut_);
            IStandardExchangeIn(instance_)
                .exchangeIn(IERC20(instance_), detfOut_, seShare, 0, attacker, false, block.timestamp + 1 hours);
            vm.stopPrank();
        }

        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "B1: victim balance intact");
        assertTrue(victimOut_ > 0, "victim still has position basis");
        _assertNoFreeInventory(instance_);
    }
}
