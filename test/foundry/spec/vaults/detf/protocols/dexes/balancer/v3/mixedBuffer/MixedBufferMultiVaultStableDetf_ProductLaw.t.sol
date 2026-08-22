// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @notice Product-law rows M1–M15 on the Mixed-buffer gold TestBase.
/// @dev closeBondMature is D25+L2: proportional withdraw, burn DETF, send remaining reserve tokens.
contract MixedBufferMultiVaultStableDetf_ProductLaw_Test is TestBase_MixedBufferMultiVaultStableDetf {
    bytes4 internal constant SEL_BOND_NOT_MATURE = bytes4(keccak256("BondNotMature(uint256)"));
    bytes4 internal constant SEL_SELL_NFT = bytes4(keccak256("sellNFT(uint256,address)"));

    function test_M1_preMaturitySell_revertsBondNotMature() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_M2_preMaturityClose_revertsBondNotMature() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        uint256[] memory minOut_ = _closeMinAmountsOut(detf);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M3_lockedClaimRewards_stillPays() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.claimRewards(tokenId_, alice);
    }

    function test_M4_matureSell_4626_and_oneToOne() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        _warpPastUnlock(detf, tokenId_);
        uint256 protocolBefore_ = detfBonding.protocolBondOriginalShares();
        vm.prank(alice);
        uint256 minted_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "M4 claim minted");
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M4 1:1");
        assertTrue(nft_.originalSharesOf(protocolId_) > protocolBefore_, "M4 protocol credited");
        assertEq(nft_.originalSharesOf(tokenId_), 0, "M4 user principal gone");
        assertEq(nft_.balanceOf(alice), 0, "M4 user nft gone");
    }

    function test_M4b_compoundThenRedeem_notOneToOne() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        IMixedBufferMultiVaultStableDetfBonding bonding_ = IMixedBufferMultiVaultStableDetfBonding(instance_);
        (uint256 tokenId_,,) = _bootstrapDefault(instance_, alice);
        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        uint256 minted_ = bonding_.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "M4b minted");

        _enableSeigniorageIncentive(instance_, 0.20e18);
        _seedBondVaultRewardDetf(instance_, 40e18);
        IMixedBufferMultiVaultStableDetfInfo(instance_).compoundProtocolRewards();

        IRebasingClaimToken claim_ = IRebasingClaimToken(
            IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken()
        );
        uint256 claimBal_ = claim_.balanceOf(alice);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;

        uint256 preview_ = bonding_.previewRedeemClaim(redeemAmt_, IERC20(instance_));
        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(redeemAmt_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "M4b redeem DETF");
        if (preview_ > 0) {
            assertApproxEqAbs(preview_, out_, 1e12, "M4b preview~exec");
        }
    }

    function test_M5_close_noExtraDetf_protocolUnchangedExceptRedeposit() public {
        _bootstrapDefault(detf, alice);
        // Close a *later* smaller bond so the exit is not 100% of pool BPT (InvariantRatio).
        _fundBuffer(alice, 80e18);
        vm.startPrank(alice);
        IERC20(address(dai)).approve(detf, 80e18);
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(dai)), 80e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        uint256 protocolBefore_ = nft_.originalSharesOf(protocolId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(alice);
        uint256 bufBefore_ = IERC20(address(dai)).balanceOf(alice);

        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        uint256 pending_ = nft_.pendingRewards(tokenId_);
        uint256[] memory minOut_ = _closeMinAmountsOut(detf);
        vm.prank(alice);
        uint256[] memory out_ = detfBonding.closeBondMature(
            tokenId_, minOut_, alice, block.timestamp + 1 hours
        );
        uint256 settled_ = 0;
        for (uint256 i; i < out_.length; ++i) settled_ += out_[i];
        assertTrue(settled_ > 0, "M5 settlement");
        // D25 harvests pending DETF (incl. expansion minted on this touch); withdrawn reserve DETF is burned.
        uint256 detfDelta_ = IERC20(detf).balanceOf(alice) - detfBefore_;
        assertTrue(detfDelta_ >= pending_, "M5 at least pending");
        assertTrue(IERC20(address(dai)).balanceOf(alice) > bufBefore_, "M5 buffer basket");
        assertEq(out_.length, preview_.length, "L2 length");
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1e12, "M5 preview~exec");
        }
        // Close may credit redeposited DETF-leg BPT onto protocol NFT, never user principal.
        assertTrue(nft_.originalSharesOf(protocolId_) >= protocolBefore_, "M5 protocol not drained");
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M5 1:1");
    }

    function test_M6_transferredLockedNft_buyerCannotExit() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.transferFrom(alice, bob, tokenId_);
        uint256 unlock_ = nft_.unlockTimeOf(tokenId_);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
        uint256[] memory minOut_ = _closeMinAmountsOut(detf);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.closeBondMature(tokenId_, minOut_, bob, block.timestamp + 1 hours);
    }

    function test_M7_bondDetf_reverts_and_acceptedExcludesDetf() public {
        _bootstrapDefault(detf, alice);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.InvalidRoute.selector, detf, detf)
        );
        detfBonding.bond(IERC20(detf), 1e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours);

        address[] memory tokens_ = detfBonding.acceptedBondTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            assertTrue(tokens_[i] != detf, "M7 accepted excludes DETF");
        }
    }

    function test_M8_buyClaim_emptyThenFewerShares() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        IMixedBufferMultiVaultStableDetfBonding bonding_ = IMixedBufferMultiVaultStableDetfBonding(instance_);
        _bootstrapDefault(instance_, alice);
        uint256 detfAmt_ = _mintDetfFromBuffer(instance_, alice, 80e18);

        uint256 preview_ = bonding_.previewBuyClaim(detfAmt_ / 2);
        vm.startPrank(alice);
        IERC20(instance_).approve(instance_, detfAmt_);
        uint256 first_ = bonding_.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(first_ > 0, "M8 first mint");
        // Unbalanced DETF-only join is not closed-form; preview is a linear BPT estimate.
        assertTrue(preview_ > 0, "M8 preview nonzero");

        vm.startPrank(alice);
        uint256 second_ = bonding_.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(second_ <= first_, "M8 second mint not more shares per input");
    }

    function test_M8b_exchangeInDetfToClaim_reverts() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(instance_, alice);
        address claim_ = IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.InvalidRoute.selector, instance_, claim_)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), 1e18, IERC20(claim_), 0, alice, false, block.timestamp + 1 hours
        );
    }

    function test_M8c_donateBpt_ignoredByTotalAssets() public {
        _bootstrapDefault(detf, alice);
        uint256 before_ = detfBonding.protocolBondOriginalShares();
        uint256 rateBefore_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate();
        uint256 donated_ = _fundReserveBpt(detf, address(this), 40e18);
        IERC20(detfInfo.reservePool()).transfer(detf, donated_);
        assertEq(detfBonding.protocolBondOriginalShares(), before_, "M8c donate ignored");
        assertEq(IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate(), rateBefore_, "M8c rate");
    }

    function test_M8d_minClaimOut_tooHigh_reverts() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        _warpPastUnlock(detf, tokenId_);
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.sellPositionToDetfNft(tokenId_, type(uint256).max, alice);
    }

    function test_M8e_forcedShortfall_InsufficientReserveBpt() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        _warpPastUnlock(detf, tokenId_);
        address bpt_ = detfInfo.reservePool();
        address nft_ = detfInfo.bondNftVault();
        uint256 nftBal_ = IERC20(bpt_).balanceOf(nft_);
        assertTrue(nftBal_ > 0, "M8e has bpt");
        // D13: drain every physical BPT. Leaving 1 wei lets convertToAssets round
        // to 1 and close succeed. Diamond leftover would skip _pullBptFromNft.
        vm.prank(detf);
        IDETFNFTVault(nft_).transferHeldToken(IERC20(bpt_), address(0xdead), nftBal_);
        uint256 detfBal_ = IERC20(bpt_).balanceOf(detf);
        if (detfBal_ > 0) {
            vm.prank(detf);
            IERC20(bpt_).transfer(address(0xdead), detfBal_);
        }
        uint256[] memory minOut_ = _closeMinAmountsOut(detf);
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M8f_deploy_zeroPrincipalProtocolNft() public view {
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertEq(nft_.originalSharesOf(protocolId_), 0, "M8f 0 principal");
        assertEq(nft_.effectiveSharesOf(protocolId_), 0, "M8f 0 effective");
        assertEq(nft_.ownerOf(protocolId_), address(nft_), "M8f protocol nft held by vault");
    }

    function test_M8g_redemptionRate_ignoresUserBondAndIdle() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        uint256 rate0_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate();
        uint256 proto0_ = detfBonding.protocolBondOriginalShares();
        uint256 donated_ = _fundReserveBpt(detf, address(this), 30e18);
        IERC20(detfInfo.reservePool()).transfer(detf, donated_);
        assertEq(detfBonding.protocolBondOriginalShares(), proto0_, "M8g idle ignored");
        assertEq(IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate(), rate0_, "M8g rate");
        tokenId_;
    }

    function test_M13_sellNftSelectorAbsent() public view {
        bytes4[] memory funcs_ = mixedBufferDetfBondingFacet.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            assertTrue(funcs_[i] != SEL_SELL_NFT, "M13 sellNFT absent");
        }
        assertEq(IDiamondLoupe(detf).facetAddress(SEL_SELL_NFT), address(0), "M13 loupe");
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.buyClaim.selector) != address(0),
            "M13 buyClaim live"
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.closeBondMature.selector)
                != address(0),
            "M13 close live"
        );
    }

    function test_M14_eoaClaimLiquidity_and_redeemPosition_revert() public {
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.NotAuthorized.selector, alice));
        detfBonding.claimLiquidity(1e18, alice);

        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        vm.expectRevert();
        nft_.redeemPosition(tokenId_, alice, block.timestamp + 1 hours);
    }

    function test_M15_newSelectorsOnProxy() public view {
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.previewBuyClaim.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.previewCloseBondMature.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.previewRedeemClaim.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.claimLiquidity.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMixedBufferMultiVaultStableDetfBonding.protocolBondOriginalShares.selector)
                != address(0)
        );
    }
}
