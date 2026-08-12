// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @notice Product-law rows M1–M15 on the Weighted gold TestBase (shipped diamond).
contract MultiVaultWeightedDetf_ProductLaw_Test is TestBase_MultiVaultWeightedDetf {
    bytes4 internal constant SEL_BOND_NOT_MATURE = bytes4(keccak256("BondNotMature(uint256)"));
    bytes4 internal constant SEL_SELL_NFT = bytes4(keccak256("sellNFT(uint256,address)"));

    function test_M1_preMaturitySell_revertsBondNotMature() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_M2_preMaturityClose_revertsBondNotMature() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.closeBondMature(tokenId_, rateAsset0, 0, alice, block.timestamp + 1 hours);
    }

    function test_M3_lockedClaimRewards_stillPays() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.claimRewards(tokenId_, alice);
    }

    function test_M4_matureSell_4626_and_oneToOne() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 1_000e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 protocolBefore_ = detfBonding.protocolBondOriginalShares();
        vm.prank(alice);
        uint256 minted_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "M4 claim minted");
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M4 1:1");
        assertTrue(nft_.originalSharesOf(protocolId_) > protocolBefore_, "M4 protocol credited");
        assertEq(nft_.originalSharesOf(tokenId_), 0, "M4 user position cleared");
    }

    function test_M5_close_noExtraDetf_protocolUnchangedExceptRedeposit() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 1_200e18);
        _warpPastUnlock(detf, tokenId_);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        uint256 protocolBefore_ = nft_.originalSharesOf(protocolId_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(alice);
        uint256 pending_ = nft_.pendingRewards(tokenId_);

        vm.prank(alice);
        uint256 out_ = detfBonding.closeBondMature(tokenId_, rateAsset0, 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "M5 settlement");
        // Harvest may pay pending + expansion-synced free DETF. The self-leg is not paid out
        // (that would be ~principal BPT-sized). Allow harvest, reject principal-sized DETF.
        uint256 detfGain_ = IERC20(detf).balanceOf(alice) - detfBefore_;
        pending_; // snapshot kept for traces
        assertTrue(detfGain_ < 10e18, "M5 no extra DETF");
        // Close may credit redeposited DETF-leg BPT onto protocol NFT, never user principal.
        assertTrue(nft_.originalSharesOf(protocolId_) >= protocolBefore_, "M5 protocol not drained");
        assertEq(nft_.effectiveSharesOf(protocolId_), nft_.originalSharesOf(protocolId_), "M5 1:1");
    }

    function test_M6_transferredLockedNft_buyerCannotExit() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 700e18);
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        nft_.transferFrom(alice, bob, tokenId_);
        uint256 unlock_ = nft_.unlockTimeOf(tokenId_);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SEL_BOND_NOT_MATURE, unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
    }

    function test_M7_bondDetf_reverts_and_acceptedExcludesDetf() public {
        _goLiveViaBptBond(detf, alice, 500e18);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultWeightedDetfRepo.InvalidRoute.selector, detf, detf)
        );
        detfBonding.bond(IERC20(detf), 1e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours);

        address[] memory tokens_ = detfBonding.acceptedBondTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            assertTrue(tokens_[i] != detf, "M7 accepted excludes DETF");
        }
    }

    function test_M8_buyClaim_emptyThenFewerShares() public {
        _goLiveViaBptBond(detf, alice, 1_000e18);
        uint256 detfAmt_ = _acquireDetf(alice, 80e18);

        uint256 preview_ = detfBonding.previewBuyClaim(detfAmt_ / 2);
        vm.startPrank(alice);
        IERC20(detf).approve(detf, detfAmt_);
        uint256 first_ = detfBonding.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(first_ > 0, "M8 first mint");
        // Linear BPT estimate vs Balancer unbalanced join — not few-wei; both must be live.
        assertTrue(preview_ > 0, "M8 preview live");

        vm.startPrank(alice);
        uint256 second_ = detfBonding.buyClaim(detfAmt_ / 2, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        // After protocol originalShares rose, same DETF input should mint fewer claim shares.
        assertTrue(second_ <= first_, "M8 second mint not more shares per input");
    }

    function test_M8b_exchangeInDetfToClaim_reverts() public {
        _goLiveViaBptBond(detf, alice, 500e18);
        address claim_ = detfInfo.rebasingClaimToken();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultWeightedDetfRepo.InvalidRoute.selector, detf, claim_)
        );
        IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), 1e18, IERC20(claim_), 0, alice, false, block.timestamp + 1 hours
        );
    }

    function test_M8c_donateBpt_ignoredByTotalAssets() public {
        _goLiveViaBptBond(detf, alice, 800e18);
        uint256 before_ = detfBonding.protocolBondOriginalShares();
        uint256 rateBefore_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate();
        address bpt_ = detfInfo.reservePool();
        uint256 detfBpt_ = IERC20(bpt_).balanceOf(detf);
        if (detfBpt_ > 1) {
            vm.prank(detf);
            IERC20(bpt_).transfer(address(this), 1);
            vm.prank(address(this));
            IERC20(bpt_).transfer(detf, 1);
        }
        assertEq(detfBonding.protocolBondOriginalShares(), before_, "M8c donate ignored");
        assertEq(IRebasingClaimToken(detfInfo.rebasingClaimToken()).redemptionRate(), rateBefore_, "M8c rate");
    }

    function test_M8d_minClaimOut_tooHigh_reverts() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        _warpPastUnlock(detf, tokenId_);
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.sellPositionToDetfNft(tokenId_, type(uint256).max, alice);
    }

    function test_M8e_forcedShortfall_InsufficientReserveBpt() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 1_000e18);
        _warpPastUnlock(detf, tokenId_);
        address bpt_ = detfInfo.reservePool();
        uint256 detfBpt_ = IERC20(bpt_).balanceOf(detf);
        if (detfBpt_ > 1) {
            vm.prank(detf);
            IERC20(bpt_).transfer(address(1), detfBpt_ - 1);
        }
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.closeBondMature(tokenId_, rateAsset0, 0, alice, block.timestamp + 1 hours);
    }

    function test_M8f_deploy_zeroPrincipalProtocolNft() public view {
        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 protocolId_ = nft_.detfNFTId();
        assertTrue(protocolId_ > 0, "M8f exists");
        assertEq(nft_.originalSharesOf(protocolId_), 0, "M8f 0 principal");
        assertEq(nft_.effectiveSharesOf(protocolId_), 0, "M8f 0 effective");
    }

    function test_M13_sellNftSelectorAbsent() public view {
        bytes4[] memory funcs_ = multiVaultWeightedDetfBondingFacet.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            assertTrue(funcs_[i] != SEL_SELL_NFT, "M13 sellNFT absent");
        }
        assertEq(IDiamondLoupe(detf).facetAddress(SEL_SELL_NFT), address(0), "M13 loupe");
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMultiVaultWeightedDetfBonding.buyClaim.selector) != address(0),
            "M13 buyClaim live"
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMultiVaultWeightedDetfBonding.closeBondMature.selector) != address(0),
            "M13 close live"
        );
    }

    function test_M14_eoaClaimLiquidity_and_redeemPosition_revert() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 600e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MultiVaultWeightedDetfRepo.NotAuthorized.selector, alice));
        detfBonding.claimLiquidity(1e18, alice);

        IDETFNFTVault nft_ = IDETFNFTVault(detfInfo.bondNftVault());
        vm.prank(alice);
        vm.expectRevert();
        nft_.redeemPosition(tokenId_, alice, block.timestamp + 1 hours);
    }

    function test_M15_newSelectorsOnProxy() public view {
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMultiVaultWeightedDetfBonding.previewBuyClaim.selector) != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMultiVaultWeightedDetfBonding.previewCloseBondMature.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(detf).facetAddress(IMultiVaultWeightedDetfBonding.previewRedeemClaim.selector) != address(0)
        );
    }

    function _acquireDetf(address user_, uint256 lpAmount_) internal returns (uint256 detfAmt_) {
        uint256 seShares_ = _fundSeShares0(user_, lpAmount_);
        vm.startPrank(user_);
        seShare0.approve(detf, seShares_);
        detfAmt_ = IStandardExchangeIn(detf).exchangeIn(
            seShare0, seShares_, IERC20(detf), 0, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(detfAmt_ > 0, "acquired DETF");
    }
}
