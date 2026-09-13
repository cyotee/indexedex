// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";

/// @notice Retained Mixed Buffer security catalog against funded principal and real reserve routes.
/// @dev Trust-flag tests are separate; underlying-token callbacks use a real Aerodrome SE and pool.
contract Adversarial_MixedBuffer_P0_Test is TestBase_MixedBufferMultiVaultStableDetf_Adversarial {
    /* ---------------------------------------------------------------------- */
    /*  E5 / H3 guards                                                        */
    /* ---------------------------------------------------------------------- */

    function test_E5_zeroAmount_reverts() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        vm.prank(attacker);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
    }

    function test_E5_expiredDeadline_reverts() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, _fixtureAmount(50e18));
        vm.startPrank(attacker);
        buffer_.approve(instance_, _fixtureAmount(50e18));
        vm.expectRevert(
            abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, _fixtureAmount(50e18), IERC20(instance_), 0, attacker, false, block.timestamp - 1
        );
        vm.stopPrank();
        assertEq(buffer_.balanceOf(instance_), 0, "H3 residual buffer after failed mint");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "H3 residual detf");
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 amountIn_ = _fixtureAmount(30e18);
        _fundBuffer(attacker, amountIn_);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(buffer_, amountIn_, IERC20(instance_));
        vm.startPrank(attacker);
        buffer_.approve(instance_, amountIn_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, amountIn_, IERC20(instance_), preview_ + 1, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoFreeInventory(instance_);
        assertEq(buffer_.balanceOf(attacker), amountIn_, "buffer refunded on revert");
    }

    function test_preLive_mint_reverts() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, _fixtureAmount(50e18));
        vm.startPrank(attacker);
        buffer_.approve(instance_, _fixtureAmount(50e18));
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, _fixtureAmount(50e18), IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(buffer_.balanceOf(instance_), 0, "H3 residual pre-live");
    }

    /* ---------------------------------------------------------------------- */
    /*  A donation                                                            */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate bufferToken inventory — no free DETF; victim mint matches preview.
    function test_A1_donateBuffer_cannotMintFreeDetf() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 donated_ = _fixtureAmount(100e18);
        _fundBuffer(attacker, donated_);
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        buffer_.transfer(instance_, donated_);
        assertEq(buffer_.balanceOf(instance_), donated_, "buffer idle on diamond");
        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "A1: no free DETF");

        uint256 victimIn_ = _fixtureAmount(20e18);
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
    function test_A1_donateVaultShares_cannotMintFreeDetf() public virtual {
        address instance_ = _openLiveGated();
        address shareToken_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares()[0];
        uint256 donated_ = _fundVaultShares(0, attacker, 80e18);
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        IERC20(shareToken_).transfer(instance_, donated_);
        assertEq(IERC20(shareToken_).balanceOf(instance_), donated_, "shares idle");
        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "A1 share: no free DETF");
    }

    /// @notice A2: donate detfToken to diamond — cannot be spent by attacker burn / free extract.
    function test_A2_donateDetfToDiamond_noTheft() public virtual {
        address instance_ = _openLiveGated();
        uint256 minted_ = _mintDetfFromBuffer(instance_, attacker, _fixtureAmount(40e18));
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        uint256 victimBefore_ = IERC20(instance_).balanceOf(victim);
        vm.prank(attacker);
        IERC20(instance_).transfer(instance_, donateAmt_);
        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf on diamond");
        assertEq(IERC20(instance_).balanceOf(victim), victimBefore_, "victim unchanged");

        // Attacker cannot burn diamond's free inventory without holding DETF themselves.
        uint256 hold_ = IERC20(instance_).balanceOf(attacker);
        assertGt(hold_, 0);
        {
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
    function test_A3_D2_unstakeWithoutReceipt_noBptOrBackingDrain() public virtual {
        address instance_ = _openLiveGated();
        IDetfBondNFT nft_ = _fundedNft(instance_); IStakedDETF staking_ = IStakedDETF(_claimOf(instance_));
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        assertGt(lp_, 0); assertGt(backing_, 0); assertEq(staking_.balanceOf(attacker), 0);
        vm.prank(attacker); vm.expectRevert();
        staking_.exchangeIn(IERC20(address(staking_)), 1e9, IERC20(instance_), 0, attacker, false, block.timestamp);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_);
        assertEq(IERC20(instance_).balanceOf(attacker), 0);
    }


    /* ---------------------------------------------------------------------- */
    /*  D bond / claim authority                                              */
    /* ---------------------------------------------------------------------- */

    function test_D2_claimBond_nonOwner_reverts() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        (uint256 id_,,) = _bootstrapDefault(instance_, alice); IDetfBondNFT nft_ = _fundedNft(instance_);
        bytes32 position_ = keccak256(abi.encode(nft_.positionOf(id_)));
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, attacker));
        nft_.claimBond(id_, attacker);
        assertEq(keccak256(abi.encode(nft_.positionOf(id_))), position_);
        assertEq(IStakedDETF(_claimOf(instance_)).balanceOf(attacker), 0);
    }


    function test_D3_finalClaim_cannotPayTwice() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        (uint256 id_,,) = _bootstrapDefault(instance_, alice);
        IStakedDETF staking_ = _matureClaim(instance_, id_, alice); IDetfBondNFT nft_ = _fundedNft(instance_);
        uint256 balance_ = staking_.balanceOf(alice); assertGt(balance_, 0);
        vm.prank(alice); vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id_));
        nft_.claimBond(id_, alice);
        assertEq(staking_.balanceOf(alice), balance_); assertEq(nft_.ownerOf(id_), address(0));
    }


    function test_D3_unstake_overRemainingReceipt_reverts() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        (uint256 id_,,) = _bootstrapDefault(instance_, alice); IStakedDETF staking_ = _matureClaim(instance_, id_, alice);
        uint256 part_ = staking_.balanceOf(alice) / 10; assertGt(part_, 0);
        vm.prank(alice);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), part_, IERC20(instance_), part_, alice, false, block.timestamp), part_);
        uint256 left_ = staking_.balanceOf(alice); uint256 raw_ = IERC20(instance_).balanceOf(alice);
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        vm.prank(alice); vm.expectRevert();
        staking_.exchangeIn(IERC20(address(staking_)), left_ + 1, IERC20(instance_), 0, alice, false, block.timestamp);
        assertEq(staking_.balanceOf(alice), left_); assertEq(IERC20(instance_).balanceOf(alice), raw_);
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_);
    }


    function test_D5_lockClamp_minRevert_maxOk() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        _fundBuffer(attacker, _fixtureAmount(80e18));
        vm.startPrank(attacker);
        buffer_.approve(instance_, _fixtureAmount(80e18));
        vm.expectRevert();
        IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, _fixtureAmount(80e18), 1 days, attacker, false, block.timestamp + 1 hours
        );
        (uint256 tid_,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, _fixtureAmount(80e18), DEFAULT_MAX_LOCK + 365 days, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock bonds");
    }

    function test_D6_unstakePaysExactlyHeldDetfAndLeavesProtocolLp() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        (uint256 id_,,) = _bootstrapDefault(instance_, alice); IStakedDETF staking_ = _matureClaim(instance_, id_, alice);
        IDetfBondNFT nft_ = _fundedNft(instance_);
        uint256 amount_ = staking_.balanceOf(alice) / 5; assertGt(amount_, 0);
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 receipt_ = staking_.balanceOf(alice); uint256 supply_ = IERC20(instance_).totalSupply();
        vm.prank(alice);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(instance_), amount_, alice, false, block.timestamp), amount_);
        assertEq(IERC20(instance_).balanceOf(alice), amount_);
        assertEq(staking_.balanceOf(alice), receipt_ - amount_);
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_ - amount_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
        assertEq(IERC20(instance_).totalSupply(), supply_);
    }


    /* ---------------------------------------------------------------------- */
    /*  F access / immutability                                               */
    /* ---------------------------------------------------------------------- */

    function test_F2_createFundedPosition_onlyDetf() public virtual {
        address instance_ = _openLiveGated(); IDetfBondNFT nft_ = _fundedNft(instance_);
        vm.prank(attacker); vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, attacker));
        nft_.createFundedPosition(1e9, DEFAULT_MIN_LOCK, attacker);
    }


    function test_F3_fundRewards_onlyDetf() public virtual {
        address instance_ = _openLiveGated(); IStakedDETF staking_ = IStakedDETF(_claimOf(instance_));
        bytes32 before_ = keccak256(abi.encode(staking_.stakingState()));
        vm.prank(attacker); vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.Unauthorized.selector, attacker));
        staking_.fundRewards(1e9);
        assertEq(keccak256(abi.encode(staking_.stakingState())), before_);
    }


    function test_F3_retireEscrowDust_onlyBondNft() public virtual {
        address instance_ = _openLiveGated(); IStakedDETF staking_ = IStakedDETF(_claimOf(instance_));
        bytes32 before_ = keccak256(abi.encode(staking_.stakingState()));
        vm.prank(attacker); vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.Unauthorized.selector, attacker));
        staking_.retireEscrowDust(1);
        assertEq(keccak256(abi.encode(staking_.stakingState())), before_);
    }


    function test_F1_diamondCut_notCallableByAttacker() public virtual {
        address instance_ = _openLiveGated();
        bytes4 selector_ = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(instance_).facetAddress(selector_), address(0));
        IDiamond.FacetCut[] memory cuts_ = new IDiamond.FacetCut[](0);
        vm.prank(attacker);
        (bool ok_,) = instance_.call(abi.encodeWithSelector(selector_, cuts_, address(0), bytes("")));
        assertFalse(ok_);
    }


    function test_F4_noSetWeightsOrThresholds() public virtual {
        address instance_ = _openLiveGated();
        (bool okW,) = instance_.call(abi.encodeWithSignature("setWeights(uint256,uint256)", 1, 1));
        assertFalse(okW, "no setWeights");
        (bool okT,) = instance_.call(abi.encodeWithSignature("setMintThreshold(uint256)", 1));
        assertFalse(okT, "no setMintThreshold");
    }

    /* ---------------------------------------------------------------------- */
    /*  C reentrancy (hostile share leg)                                      */
    /* ---------------------------------------------------------------------- */

    function test_C1_reenterBond_duringBootstrap_hitsIsLocked() public virtual {
        address instance_ = _deployHostileBufferDetf();
        hostileBuffer.armForRecipient(instance_, address(reentryTarget), abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric, (instance_, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), DEFAULT_MIN_LOCK, attacker)));
        uint256 id_ = _bootstrapHostile(instance_, alice, _fixtureAmount(1_000e18), 1_000e18);
        assertGt(_fundedNft(instance_).positionOf(id_).principal, 0);
        _assertHostileLock();
    }


    function test_C2_reenterExchangeIn_duringBufferMint_hitsIsLocked() public virtual {
        address instance_ = _deployHostileBufferDetf(); _bootstrapHostile(instance_, alice, _fixtureAmount(1_000e18), 1_000e18);
        hostileBuffer.armForRecipient(instance_, address(reentryTarget), abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn, (instance_, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), IERC20(instance_), attacker)));
        _executeHostileMint(instance_, attacker, _fixtureAmount(50e18)); _assertHostileLock();
    }


    function test_C3_bufferMintReenterBond_hitsIsLocked() public virtual {
        address instance_ = _deployHostileBufferDetf(); _bootstrapHostile(instance_, alice, _fixtureAmount(1_000e18), 1_000e18);
        hostileBuffer.armForRecipient(instance_, address(reentryTarget), abi.encodeCall(
            DetfReentryTarget.reenterBondGeneric, (instance_, IERC20(address(hostileBuffer)), _fixtureAmount(1e18), DEFAULT_MIN_LOCK, attacker)));
        _executeHostileMint(instance_, attacker, _fixtureAmount(50e18)); _assertHostileLock();
    }


    /* ---------------------------------------------------------------------- */
    /*  E economic / B thresholds                                             */
    /* ---------------------------------------------------------------------- */

    function test_E1_mintThenPartialBurn_conservation() public virtual {
        address instance_ = _openLiveGated();
        IERC20 buffer_ = _bufferOf(instance_);
        uint256 bufferIn_ = _fixtureAmount(40e18);
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
        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 bufferBack_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, buffer_, 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertLe(bufferBack_, bufferIn_, "E1: partial out <= in");
        _assertNoFreeInventory(instance_);
    }

    function test_E4_holderBalance_notDilutedByOthersMint() public virtual {
        address instance_ = _openLiveGated();
        uint256 holderOut_ = _mintDetfFromBuffer(instance_, victim, _fixtureAmount(30e18));
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        assertTrue(holderOut_ > 0 && victimBal_ > 0, "victim holds");
        _mintDetfFromBuffer(instance_, attacker, _fixtureAmount(20e18));
        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "E4: victim DETF unchanged");
    }

    function test_B3_thresholdGates_coupleToSynthetic() public virtual {
        // Default-threshold instance from setUp detf (mandatory package defaults after bootstrap).
        address instance_ = detf;
        _bootstrapDefault(instance_, alice);
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        uint256 synth_ = info_.syntheticPrice();
        assertEq(info_.isMintingAllowed(), synth_ > info_.mintThreshold(), "B3 mint coupling");
        assertEq(info_.isBurningAllowed(), synth_ < info_.burnThreshold(), "B3 burn coupling");
    }

    function test_B1_reserveFallback_mintBurn_boundsSafety() public virtual {
        address instance_ = _openLiveGated();
        uint256 victimOut_ = _mintDetfFromBuffer(instance_, victim, _fixtureAmount(30e18));
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        address pool_ = IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool();

        // Skew underlying SE pool, mint, reverse, then execute the burn route.
        _shiftUnderlyingPrice(0, true, 50_000e18);
        uint256 attackerOut_ = _mintDetfFromBuffer(instance_, attacker, _fixtureAmount(50e18));
        _shiftUnderlyingPrice(0, false, 50_000e18);

        assertGt(attackerOut_, 0);
        {
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
        assertTrue(IERC20(pool_).balanceOf(address(_fundedNft(instance_))) > 0, "B1: protocol still owns reserve BPT");
        _assertNoFreeInventory(instance_);
    }

    /* ---------------------------------------------------------------------- */
    /*  H2 claim redeem atomicity                                             */
    /* ---------------------------------------------------------------------- */

    function test_H2_unstake_minOutFail_receiptAndBackingUnchanged() public virtual {
        address instance_ = _deployDetfN(1, 100e18, 0.1e18);
        (uint256 id_,,) = _bootstrapDefault(instance_, alice); IStakedDETF staking_ = _matureClaim(instance_, id_, alice);
        uint256 receipt_ = staking_.balanceOf(alice); uint256 amount_ = receipt_ / 10; assertGt(amount_, 0);
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.MinimumOutputNotMet.selector, amount_ + 1, amount_));
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(instance_), amount_ + 1, alice, false, block.timestamp);
        assertEq(staking_.balanceOf(alice), receipt_); assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(instance_), amount_, alice, false, block.timestamp), amount_);
        vm.stopPrank();
        assertEq(staking_.balanceOf(alice), receipt_ - amount_);
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_ - amount_);
        assertEq(IERC20(instance_).balanceOf(alice), amount_);
    }


    /* ---------------------------------------------------------------------- */
    /*  G1 nested composition                                                 */
    /* ---------------------------------------------------------------------- */

    function test_G1_outerActivity_doesNotBrickInner() public virtual {
        address nested_ = _deployDetfN(1, 100e18, 0.1e18);
        _bootstrapDefault(nested_, alice);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(nested_).isReserveLive(), "nested live");

        address outer_ = _deployOuterOverNested(nested_);
        _bootstrapOuterWithNested(outer_, nested_, bob);

        // Outer mint with nested shares
        uint256 nestedIn_ = _mintDetfFromBuffer(nested_, attacker, _fixtureAmount(80e18));
        if (nestedIn_ > 20e9) nestedIn_ = 20e9;
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
        uint256 direct_ = _mintDetfFromBuffer(nested_, victim, _fixtureAmount(30e18));
        assertTrue(direct_ > 0, "G1: nested still mints for third user");
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(nested_).isReserveLive(), "nested still live");

        _assertNoFreeInventory(outer_);
    }
    function _assertHostileLock() private view {
        assertEq(hostileBuffer.reentryAttempts(), 1);
        assertFalse(hostileBuffer.nestedCallSucceeded());
        assertEq(hostileBuffer.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
    }
}
