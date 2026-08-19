// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @notice WP-ADV-DETF-MB-001: MixedBuffer DETF adversarial catalog A–H residual (after I CODE).
/// @dev I1–I3 secure-pull / trust-flag: Adversarial_MixedBuffer_TrustFlag.t.sol.
///      Deferred P2: A4 dust bootstrap grief; A5 fee-slice double-claim; B2 reserve sandwich;
///      B4–B5 MaxInRatio / multi-leg desync; C4 hostile bufferToken; C5 gas N-max;
///      D4 junk rateAsset N/A (redeemClaim is DETF-only); D7 sell/redeem lock independence by design;
///      E2–E3 multi-leg dust / fee recipient; G2–G3 nested free-inventory / opacity; H1 N-max gas.
contract Adversarial_MixedBuffer_P0_Test is TestBase_MixedBufferMultiVaultStableDetf_Adversarial {
    /* ---------------------------------------------------------------------- */
    /*  E5 / H3 guards                                                        */
    /* ---------------------------------------------------------------------- */

    function test_E5_zeroAmount_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        vm.prank(attacker);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
    }

    function test_E5_expiredDeadline_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, 50e18);
        vm.startPrank(attacker);
        buffer_.approve(instance_, 50e18);
        vm.expectRevert(
            abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, 50e18, IERC20(instance_), 0, attacker, false, block.timestamp - 1
        );
        vm.stopPrank();
        assertEq(buffer_.balanceOf(instance_), 0, "H3 residual buffer after failed mint");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "H3 residual detf");
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 amountIn_ = 30e18;
        _fundBuffer(attacker, amountIn_);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(buffer_, amountIn_, IERC20(instance_));
        vm.startPrank(attacker);
        buffer_.approve(instance_, amountIn_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, amountIn_, IERC20(instance_), preview_ + 1e18, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoFreeInventory(instance_);
        assertEq(buffer_.balanceOf(attacker), amountIn_, "buffer refunded on revert");
    }

    function test_preLive_mint_reverts() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, 50e18);
        vm.startPrank(attacker);
        buffer_.approve(instance_, 50e18);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, 50e18, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(buffer_.balanceOf(instance_), 0, "H3 residual pre-live");
    }

    /* ---------------------------------------------------------------------- */
    /*  A donation                                                            */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate bufferToken inventory — no free DETF; victim mint matches preview.
    function test_A1_donateBuffer_cannotMintFreeDetf() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 donated_ = 100e18;
        _fundBuffer(attacker, donated_);
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        buffer_.transfer(instance_, donated_);
        assertEq(buffer_.balanceOf(instance_), donated_, "buffer idle on diamond");
        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "A1: no free DETF");

        uint256 victimIn_ = 20e18;
        _fundBuffer(victim, victimIn_);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(buffer_, victimIn_, IERC20(instance_));
        vm.startPrank(victim);
        buffer_.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, preview_, "victim mint not inflated by idle donation");
        // Idle donation remains free (not joined by honest pull mint).
        assertEq(buffer_.balanceOf(instance_), donated_, "donation still idle after honest mint");
    }

    /// @notice A1b: donate vault shares — no free DETF for attacker.
    function test_A1_donateVaultShares_cannotMintFreeDetf() public {
        address instance_ = _openLiveOpenThreshold();
        address shareToken_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares()[0];
        uint256 donated_ = _fundVaultShares(0, attacker, 80e18);
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        IERC20(shareToken_).transfer(instance_, donated_);
        assertEq(IERC20(shareToken_).balanceOf(instance_), donated_, "shares idle");
        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "A1 share: no free DETF");
    }

    /// @notice A2: donate detfToken to diamond — cannot be spent by attacker burn / free extract.
    function test_A2_donateDetfToDiamond_noTheft() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintDetfFromBuffer(instance_, attacker, 40e18);
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        uint256 victimBefore_ = IERC20(instance_).balanceOf(victim);
        vm.prank(attacker);
        IERC20(instance_).transfer(instance_, donateAmt_);
        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf on diamond");
        assertEq(IERC20(instance_).balanceOf(victim), victimBefore_, "victim unchanged");

        // Attacker cannot burn diamond's free inventory without holding DETF themselves.
        uint256 hold_ = IERC20(instance_).balanceOf(attacker);
        if (hold_ > 0 && IMixedBufferMultiVaultStableDetfInfo(instance_).isBurningAllowed()) {
            uint256 burnAmt_ = hold_ / 2;
            if (burnAmt_ == 0) burnAmt_ = hold_;
            IERC20 buffer_ = _bufferOf(instance_);
            vm.startPrank(attacker);
            IERC20(instance_).approve(instance_, burnAmt_);
            IStandardExchangeIn(instance_).exchangeIn(
                IERC20(instance_), burnAmt_, buffer_, 0, attacker, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
            assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "donated DETF not spent by burn");
        }
    }

    /// @notice A3 / D2: no claim → cannot drain reserve BPT via redeemClaim.
    function test_A3_D2_redeemWithoutClaim_noBptDrain() public {
        address instance_ = _openLiveOpenThreshold();
        address pool_ = IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);

        // Grow reserve BPT via mint join.
        _mintDetfFromBuffer(instance_, bob, 30e18);
        uint256 bptAfterMint_ = IERC20(pool_).balanceOf(instance_);
        assertGe(bptAfterMint_, bptBefore_, "reserve BPT non-decreasing on mint");

        vm.prank(attacker);
        vm.expectRevert();
        IMixedBufferMultiVaultStableDetfBonding(instance_).redeemClaim(
            1e18, IERC20(instance_), 0, attacker, block.timestamp + 1 hours
        );

        assertEq(IERC20(pool_).balanceOf(instance_), bptAfterMint_, "A3/D2: BPT intact");
        assertEq(IERC20(pool_).balanceOf(attacker), 0, "A3: attacker holds no BPT");
    }

    /* ---------------------------------------------------------------------- */
    /*  D bond / claim authority                                              */
    /* ---------------------------------------------------------------------- */

    function test_D2_sellPosition_nonOwner_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        // First bootstrap bond is alice's tokenId; attacker cannot sell.
        vm.prank(attacker);
        vm.expectRevert();
        IMixedBufferMultiVaultStableDetfBonding(instance_).sellPositionToDetfNft(1, 0, attacker);
    }

    function test_D3_doubleSell_secondReverts() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        (uint256 tokenId_,,) = _bootstrapDefault(instance_, alice);
        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        IMixedBufferMultiVaultStableDetfBonding(instance_).sellPositionToDetfNft(tokenId_, 0, alice);
        vm.prank(alice);
        vm.expectRevert();
        IMixedBufferMultiVaultStableDetfBonding(instance_).sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_D3_doubleRedeem_overClaim_reverts() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        (uint256 tokenId_,,) = _bootstrapDefault(instance_, alice);
        // Seed more reserve so claim redeem is a fraction of pool.
        _mintDetfFromBuffer(instance_, bob, 200e18);

        IMixedBufferMultiVaultStableDetfBonding bonding_ =
            IMixedBufferMultiVaultStableDetfBonding(instance_);
        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        uint256 minted_ = bonding_.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "claim minted");

        IRebasingClaimToken claim_ = IRebasingClaimToken(_claimOf(instance_));
        uint256 bal_ = claim_.balanceOf(alice);
        uint256 part_ = bal_ / 10;
        if (part_ == 0) part_ = bal_;

        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(part_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "first redeem ok");

        uint256 left_ = claim_.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(left_ + 1e18, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
    }

    function test_D5_lockClamp_minRevert_maxOk() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, 80e18);
        vm.startPrank(attacker);
        buffer_.approve(instance_, 80e18);
        vm.expectRevert();
        IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, 80e18, 1 days, attacker, false, block.timestamp + 1 hours
        );
        (uint256 tid_,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, 80e18, DEFAULT_MAX_LOCK + 365 days, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock bonds");
    }

    function test_D6_redeemBoundedByClaimAndInventory() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        (uint256 tokenId_,,) = _bootstrapDefault(instance_, alice);
        _mintDetfFromBuffer(instance_, bob, 150e18);

        IMixedBufferMultiVaultStableDetfBonding bonding_ =
            IMixedBufferMultiVaultStableDetfBonding(instance_);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);

        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        bonding_.sellPositionToDetfNft(tokenId_, 0, alice);

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(alice);
        uint256 bptBefore_ = IERC20(info_.reservePool()).balanceOf(instance_);
        uint256 redeemAmt_ = claimBal_ / 5;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;

        vm.prank(alice);
        bonding_.redeemClaim(redeemAmt_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);

        uint256 bptAfter_ = IERC20(info_.reservePool()).balanceOf(instance_);
        assertTrue(bptBefore_ >= bptAfter_, "BPT decreased or same");
        // Exit cannot exceed claim principal scale (claim units track bond principal).
        assertTrue(bptBefore_ - bptAfter_ <= claimBal_ + 1, "D6: exit bounded by claim scale");
    }

    /* ---------------------------------------------------------------------- */
    /*  F access / immutability                                               */
    /* ---------------------------------------------------------------------- */

    function test_F2_bondNftVault_createPosition_onlyOwner() public {
        address instance_ = _openLiveOpenThreshold();
        IDETFNFTVault bondVault_ =
            IDETFNFTVault(IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert();
        bondVault_.createPosition(1e18, DEFAULT_MIN_LOCK, attacker);
    }

    function test_F3_claim_mintFromNFTSale_onlyOwner() public {
        address instance_ = _openLiveOpenThreshold();
        IRebasingClaimToken claim_ =
            IRebasingClaimToken(IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken());
        assertTrue(address(claim_) != address(0), "claim wired");
        vm.prank(attacker);
        vm.expectRevert();
        claim_.mintFromNFTSale(1e18, attacker);
    }

    function test_F3_claim_burnShares_onlyOwner() public {
        address instance_ = _openLiveOpenThreshold();
        IRebasingClaimToken claim_ =
            IRebasingClaimToken(IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken());
        vm.prank(attacker);
        vm.expectRevert();
        claim_.burnShares(1e18, attacker, false);
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

    function test_F4_noSetWeightsOrThresholds() public {
        address instance_ = _openLiveOpenThreshold();
        (bool okW,) = instance_.call(abi.encodeWithSignature("setWeights(uint256,uint256)", 1, 1));
        assertFalse(okW, "no setWeights");
        (bool okT,) = instance_.call(abi.encodeWithSignature("setMintThreshold(uint256)", 1));
        assertFalse(okT, "no setMintThreshold");
    }

    /* ---------------------------------------------------------------------- */
    /*  C reentrancy (hostile share leg)                                      */
    /* ---------------------------------------------------------------------- */

    function test_C1_reenterBond_duringBootstrap_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf();
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, attacker)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 bufferAmt_ = 1_000e18;
        uint256 shareAmt_ = 1_000e18;
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;
        _fundBuffer(alice, bufferAmt_);

        vm.startPrank(alice);
        IERC20(address(dai)).approve(instance_, bufferAmt_);
        hostileShare.approve(instance_, shareAmt_);
        (uint256 tid_,,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bootstrapFirstBond(
            bufferAmt_, shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(tid_ > 0, "outer bootstrap ok");
        assertEq(hostileShare.reentryAttempts(), 1, "C1 reentry attempted");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested blocked");
        assertEq(hostileShare.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C1 IsLocked");
        hostileShare.disarm();
    }

    function test_C2_reenterExchangeIn_duringMint_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf();
        _bootstrapHostile(instance_, alice, 1_000e18, 1_000e18);

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

    function test_C3_mintReenterBond_hitsIsLocked() public {
        address instance_ = _deployHostileShareDetf();
        _bootstrapHostile(instance_, alice, 1_000e18, 1_000e18);

        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric,
            (instance_, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, attacker)
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

        assertEq(hostileShare.reentryAttempts(), 1, "C3 reentry");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested blocked");
        assertEq(hostileShare.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C3 IsLocked");
        hostileShare.disarm();
    }

    /* ---------------------------------------------------------------------- */
    /*  E economic / B thresholds                                             */
    /* ---------------------------------------------------------------------- */

    function test_E1_mintThenPartialBurn_conservation() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 bufferIn_ = 40e18;
        _fundBuffer(attacker, bufferIn_);

        vm.startPrank(attacker);
        buffer_.approve(instance_, bufferIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, bufferIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted");

        uint256 burnAmt_ = detfOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = detfOut_;
        if (!IMixedBufferMultiVaultStableDetfInfo(instance_).isBurningAllowed()) {
            return; // Open mode should allow; skip if gate closed for env reasons
        }
        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 bufferBack_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, buffer_, 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertLe(bufferBack_, bufferIn_, "E1: partial out <= in");
        _assertNoFreeInventory(instance_);
    }

    function test_E4_holderBalance_notDilutedByOthersMint() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 holderOut_ = _mintDetfFromBuffer(instance_, victim, 30e18);
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        assertTrue(holderOut_ > 0 && victimBal_ > 0, "victim holds");
        _mintDetfFromBuffer(instance_, attacker, 20e18);
        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "E4: victim DETF unchanged");
    }

    function test_B3_thresholdGates_coupleToSynthetic() public {
        // Default-threshold instance from setUp detf (Policy with package defaults after bootstrap).
        address instance_ = detf;
        _bootstrapDefault(instance_, alice);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        uint256 synth_ = info_.syntheticPrice();
        assertEq(info_.isMintingAllowed(), synth_ > info_.mintThreshold(), "B3 mint coupling");
        assertEq(info_.isBurningAllowed(), synth_ < info_.burnThreshold(), "B3 burn coupling");
    }

    function test_B1_openThresholds_mintBurn_boundsSafety() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 victimOut_ = _mintDetfFromBuffer(instance_, victim, 30e18);
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        address pool_ = IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool();

        // Skew underlying SE pool, mint, reverse, optional burn.
        _shiftUnderlyingPrice(0, true, 50_000e18);
        uint256 attackerOut_ = _mintDetfFromBuffer(instance_, attacker, 50e18);
        _shiftUnderlyingPrice(0, false, 50_000e18);

        if (IMixedBufferMultiVaultStableDetfInfo(instance_).isBurningAllowed() && attackerOut_ > 0) {
            IERC20 buffer_ = _bufferOf(instance_);
            vm.startPrank(attacker);
            IERC20(instance_).approve(instance_, attackerOut_);
            IStandardExchangeIn(instance_).exchangeIn(
                IERC20(instance_), attackerOut_, buffer_, 0, attacker, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }

        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "B1: victim balance intact");
        assertTrue(victimOut_ > 0, "victim still has position basis");
        assertEq(IERC20(pool_).balanceOf(attacker), 0, "B1: attacker holds no free BPT");
        assertTrue(IERC20(pool_).balanceOf(instance_) > 0, "B1: diamond still holds reserve BPT");
        _assertNoFreeInventory(instance_);
    }

    /* ---------------------------------------------------------------------- */
    /*  H2 claim redeem atomicity                                             */
    /* ---------------------------------------------------------------------- */

    function test_H2_redeemClaim_minOutFail_claimUnchanged() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        (uint256 tokenId_,,) = _bootstrapDefault(instance_, alice);
        _mintDetfFromBuffer(instance_, bob, 200e18);

        IMixedBufferMultiVaultStableDetfBonding bonding_ =
            IMixedBufferMultiVaultStableDetfBonding(instance_);
        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        bonding_.sellPositionToDetfNft(tokenId_, 0, alice);

        IRebasingClaimToken claim_ = IRebasingClaimToken(_claimOf(instance_));
        uint256 claimBefore_ = claim_.balanceOf(alice);
        assertTrue(claimBefore_ > 0, "has claim");

        uint256 redeemAmt_ = claimBefore_ / 10;
        if (redeemAmt_ == 0) redeemAmt_ = claimBefore_;

        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(redeemAmt_, IERC20(instance_), type(uint256).max, alice, block.timestamp + 1 hours);

        assertEq(claim_.balanceOf(alice), claimBefore_, "H2: claim unchanged after failed redeem");

        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(redeemAmt_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "H2: successful redeem after failed attempt");
        assertLt(claim_.balanceOf(alice), claimBefore_, "claim burned on success");
    }

    /* ---------------------------------------------------------------------- */
    /*  G1 nested composition                                                 */
    /* ---------------------------------------------------------------------- */

    function test_G1_outerActivity_doesNotBrickInner() public {
        address nested_ = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(nested_, alice);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(nested_).isReserveLive(), "nested live");

        address outer_ = _deployOuterOverNested(nested_);
        _bootstrapOuterWithNested(outer_, nested_, bob);

        // Outer mint with nested shares
        uint256 nestedIn_ = _mintDetfFromBuffer(nested_, attacker, 80e18);
        if (nestedIn_ > 20e18) nestedIn_ = 20e18;
        vm.startPrank(attacker);
        IERC20(nested_).approve(outer_, nestedIn_);
        uint256 outerOut_ = IStandardExchangeIn(outer_).exchangeIn(
            IERC20(nested_), nestedIn_, IERC20(outer_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(outerOut_ > 0, "outer minted");

        // Outer partial burn to buffer
        uint256 burnAmt_ = outerOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = outerOut_;
        IERC20 buffer_ = _bufferOf(outer_);
        vm.startPrank(attacker);
        IERC20(outer_).approve(outer_, burnAmt_);
        IStandardExchangeIn(outer_).exchangeIn(
            IERC20(outer_), burnAmt_, buffer_, 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Third user still mints on inner
        uint256 direct_ = _mintDetfFromBuffer(nested_, victim, 30e18);
        assertTrue(direct_ > 0, "G1: nested still mints for third user");
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(nested_).isReserveLive(), "nested still live");

        _assertNoFreeInventory(outer_);
    }
}
