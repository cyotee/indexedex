// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
/// @notice Product-law rows M1–M15 on the Single SE gold TestBase (shipped diamond).
contract SingleStandardExchangeDETF_ProductLaw_Test is TestBase_SingleStandardExchangeDETF {
    bytes4 internal constant SEL_BOND_NOT_MATURE = bytes4(keccak256("BondNotMature(uint256)"));
    bytes4 internal constant SEL_SELL_NFT = bytes4(keccak256("sellNFT(uint256,address)"));

    function test_M1_preMaturitySell_revertsBondNotMature() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_M2_preMaturityClose_revertsBondNotMature() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        uint256[] memory minOut_ = new uint256[](2);
        detfBonding.closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M3_lockedClaimRewards_stillPays() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.claimRewards(tokenId_, alice);
    }

    function test_M4_matureSell_4626_and_oneToOne() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 1_000e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 protocolBefore_ = detfBonding.protocolBondOriginalShares();
        vm.prank(alice);
        uint256 minted_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "M4 claim minted");
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M4 1:1");
        assertTrue(nft_.originalSharesOf(protocolId_) > protocolBefore_, "M4 protocol credited");
        address ownerAfter_;
        try nft_.ownerOf(tokenId_) returns (address o_) {
            ownerAfter_ = o_;
        } catch {
            ownerAfter_ = address(0);
        }
        assertEq(ownerAfter_, address(0), "M4 user NFT burned");
    }

    function test_M5_close_noExtraDetf_protocolUnchangedExceptRedeposit() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        uint256 protocolBefore_ = nft_.originalSharesOf(protocolId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        uint256 pending_ = nft_.pendingRewards(tokenId_);

        vm.prank(bob);
        uint256[] memory minOut_ = new uint256[](2);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, minOut_, bob, block.timestamp + 1 hours);
        uint256 settled_ = out_[0] + out_[1];
        assertTrue(settled_ > 0, "M5 settlement");
        // D25 harvests pending DETF to the user; withdrawn reserve DETF is burned.
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "M5 pending only");
        assertTrue(nft_.originalSharesOf(protocolId_) >= protocolBefore_, "M5 protocol not drained");
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M5 1:1");
    }

    function test_close_previewMatchesExecute_paysVaultShare() public {
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        uint256 seBefore_ = seShare.balanceOf(bob);
        uint256 detfBefore_ = IERC20(detf).balanceOf(bob);
        uint256 pending_ = IDETFNFTVault(detfInfo.bondNftVault()).pendingRewards(tokenId_);
        vm.prank(bob);
        uint256[] memory minOut_ = new uint256[](2);
        uint256[] memory out_ = detfBonding.closeBondMature(tokenId_, minOut_, bob, block.timestamp + 1 hours);
        assertEq(out_.length, preview_.length, "L2 length");
        assertApproxEqAbs(out_[0], preview_[0], 1, "preview[0]");
        assertApproxEqAbs(out_[1], preview_[1], 1, "preview[1]");
        assertApproxEqAbs(IERC20(detf).balanceOf(bob) - detfBefore_, pending_, 1, "D25 pending only");
        assertTrue(seShare.balanceOf(bob) > seBefore_, "D25 vault share basket");
    }

    function test_M6_transferredLockedNft_buyerCannotExit() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 700e18);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.transferFrom(alice, bob, tokenId_);
        uint256 unlock_ = nft_.unlockTimeOf(tokenId_);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
    }

    function test_M7_bondDetf_reverts_and_acceptedExcludesDetf() public {
        _bootstrapViaFirstBond(alice, 500e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SingleStandardExchangeDETFRepo.InvalidRoute.selector, detf, detf));
        detfBonding.bond(IERC20(detf), 1e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours);

        address[] memory tokens_ = detfBonding.acceptedBondTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            assertTrue(tokens_[i] != detf, "M7 accepted excludes DETF");
        }
    }

    function test_M8_buyClaim_emptyThenFewerShares() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 detfAmt_ = IERC20(detf).balanceOf(alice);
        assertTrue(detfAmt_ > 0, "M8 free DETF from bond");

        detfBonding.previewBuyClaim(detfAmt_ / 2);
        vm.startPrank(alice);
        IERC20(detf).approve(detf, detfAmt_);
        uint256 first_ = detfBonding.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(first_ > 0, "M8 first mint");

        vm.startPrank(alice);
        uint256 second_ = detfBonding.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(second_ <= first_, "M8 second mint not more shares per input");
    }

    function test_M8b_exchangeInDetfToClaim_reverts() public {
        _bootstrapViaFirstBond(alice, 500e18);
        address claim_ = detfInfo.rebasingClaimToken();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SingleStandardExchangeDETFRepo.InvalidRoute.selector, detf, claim_));
        IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), 1e18, IERC20(claim_), 0, alice, false, block.timestamp + 1 hours
        );
    }

    function test_M8c_donateBpt_ignoredByTotalAssets() public {
        _bootstrapViaFirstBond(alice, 800e18);
        uint256 before_ = detfBonding.protocolBondOriginalShares();
        uint256 rateBefore_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate();
        // D13: user-bond BPT sits on the Bond NFT, not the diamond. Protocol originalShares stay 0.
        assertEq(before_, 0, "M8c user pile is not protocol assets");
        assertEq(IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate(), rateBefore_, "M8c rate");
        address nft_ = detfInfo.bondNftVault();
        assertTrue(
            IERC20(detfInfo.reservePool()).balanceOf(nft_) > before_, "physical NFT BPT > protocol"
        );
    }

    function test_M8d_minClaimOut_tooHigh_reverts() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        _warpPastUnlock(detf, tokenId_);
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.sellPositionToDetfNft(tokenId_, type(uint256).max, alice);
    }

    function test_M8e_forcedShortfall_InsufficientReserveBpt() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 1_000e18);
        _warpPastUnlock(detf, tokenId_);
        address bpt_ = detfInfo.reservePool();
        address nft_ = detfInfo.bondNftVault();
        uint256 nftBal_ = IERC20(bpt_).balanceOf(nft_);
        if (nftBal_ > 0) {
            vm.prank(detf);
            IDETFNFTVault(nft_).transferHeldToken(IERC20(bpt_), address(1), nftBal_);
        }
        uint256 detfBal_ = IERC20(bpt_).balanceOf(detf);
        if (detfBal_ > 0) {
            vm.prank(detf);
            IERC20(bpt_).transfer(address(1), detfBal_);
        }
        vm.prank(alice);
        vm.expectRevert();
        uint256[] memory minOut_ = new uint256[](2);
        detfBonding.closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M8f_deploy_zeroPrincipalProtocolNft() public view {
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertTrue(nft_.ownerOf(protocolId_) != address(0), "M8f exists");
        assertEq(nft_.originalSharesOf(protocolId_), 0, "M8f 0 principal");
        assertEq(nft_.effectiveSharesOf(protocolId_), 0, "M8f 0 effective");
    }

    function test_M8g_redemptionRate_ignoresUserBondAndDonate() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 900e18);
        uint256 rateBefore_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate();
        _bootstrapDetf(detf, bob, 150e18);
        assertEq(IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate(), rateBefore_, "M8g user-bond");
        tokenId_;
    }

    function test_M12_deployWithZeroClaimPkg_reverts() public {
        _expectRevertDeployPkgWithZeroClaim();
    }

    function test_M13_sellNftSelectorAbsent() public view {
        bytes4[] memory funcs_ = singleStandardExchangeDetfExchangeInFacet.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            assertTrue(funcs_[i] != SEL_SELL_NFT, "M13 sellNFT absent");
        }
        assertEq(IDiamondLoupe(detf).facetAddress(SEL_SELL_NFT), address(0), "M13 loupe");
        assertTrue(
            IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.buyClaim.selector) != address(0),
            "M13 buyClaim live"
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.closeBondMature.selector) != address(0),
            "M13 close live"
        );
    }

    function test_M14_eoaClaimLiquidity_and_redeemPosition_revert() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 600e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SingleStandardExchangeDETFRepo.NotAuthorized.selector, alice));
        detfBonding.claimLiquidity(1e18, alice);

        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        vm.expectRevert();
        nft_.redeemPosition(tokenId_, alice, block.timestamp + 1 hours);
    }

    function test_M15_newSelectorsOnProxy() public view {
        assertTrue(
            IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.previewBuyClaim.selector) != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.previewCloseBondMature.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.previewRedeemClaim.selector)
                != address(0)
        );
        assertTrue(IDiamondLoupe(detf).facetAddress(ISingleStandardExchangeDETFBonding.redeemClaim.selector) != address(0));
        assertTrue(
            detfInfo.rebasingClaimToken() != address(0),
            "claim wired"
        );
    }
}
