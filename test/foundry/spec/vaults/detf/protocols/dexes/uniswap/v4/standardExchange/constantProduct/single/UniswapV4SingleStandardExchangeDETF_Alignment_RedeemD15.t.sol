// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice D15 DETF-only zap-out redeem on Uni V4 CP. D15-5 N/A (single leftover pair).
contract UniswapV4SingleStandardExchangeDETF_Alignment_RedeemD15 is
    TestBase_UniswapV4SingleStandardExchangeDETF
{
    uint256 internal keepBondId;

    function setUp() public override {
        super.setUp();
        (keepBondId,) = _firstBond(400 ether);
        _firstBond(80 ether);
    }

    function _sellAndClaim() internal returns (uint256 claimBal_) {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        assertGt(claimBal_, 0);
    }

    function test_D15_1_previewEqualsExecute() public {
        uint256 claimBal_ = _sellAndClaim();
        uint256 redeem_ = claimBal_ / 2;
        uint256 preview_ = detfInfo.previewRedeemClaim(redeem_, IERC20(detf));
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(redeem_, IERC20(detf), 0, detfUser, block.timestamp + 1 hours);
        assertApproxEqRel(out_, preview_, 0.003e18, "D15-1 residual book");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        uint256 claimBal_ = _sellAndClaim();
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal_ / 3, IERC20(address(pairToken)), 0, detfUser, block.timestamp + 1 hours);
    }

    function test_D15_9_ungatedVsPolicy() public {
        uint256 claimBal_ = _sellAndClaim();
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(claimBal_ / 4, IERC20(detf), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0);
    }

    function test_D15_2_smallRedeemConsumesPending() public {
        uint256 claimBal_ = _sellAndClaim();
        uint256 redeem_ = claimBal_ / 10;
        if (redeem_ == 0) redeem_ = 1;
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(redeem_, IERC20(detf), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0, "D15-2");
    }

    function test_D15_3_pendingCoversOwed_skipsLpWithdraw() public {
        uint256 claimBal_ = _sellAndClaim();
        IDETFNFTVault nft_ = _bondNftVault(detf);
        IERC20 lp_ = IERC20(nft_.lpToken());
        deal(detf, address(nft_), IERC20(detf).balanceOf(address(nft_)) + 80 ether);
        uint256 lpBefore_ = lp_.balanceOf(address(nft_));
        uint256 origBefore_ = nft_.originalSharesOf(nft_.detfNFTId());
        uint256 redeem_ = claimBal_ / 50;
        if (redeem_ == 0) redeem_ = 1;
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(redeem_, IERC20(detf), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0, "D15-3 paid");
        assertGe(lp_.balanceOf(address(nft_)), lpBefore_, "D15-3 no LP withdraw");
        assertGe(nft_.originalSharesOf(nft_.detfNFTId()) + 1, origBefore_, "D15-3 orig except leftover compound");
    }

    function test_D15_4_shortfallResidualBuy_otherBondersUnchanged() public {
        uint256 claimBal_ = _sellAndClaim();
        IDETFNFTVault nft_ = _bondNftVault(detf);
        uint256 keepOrig_ = nft_.originalSharesOf(keepBondId);
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        uint256 redeem_ = claimBal_ / 2;
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(redeem_, IERC20(detf), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0, "D15-4 paid");
        assertEq(nft_.originalSharesOf(keepBondId), keepOrig_, "D15-4 other originalShares");
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "D15-4 no pair to redeemer");
    }

    function test_D15_6_lastExitRejoinsLeftover() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _openArgs();
        args_.name = "D15-6 last exit CP";
        args_.symbol = "d156cp";
        address instance_ = _deployDetfWired(args_);
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        pairToken.mint(detfUser, 200 ether);
        vm.startPrank(detfUser);
        pairToken.approve(instance_, type(uint256).max);
        (uint256 tokenId,) = info_.bond(
            IERC20(address(pairToken)), 80 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        info_.sellPositionToDetfNft(tokenId, detfUser);
        vm.stopPrank();
        uint256 claimBal_ = IRebasingClaimToken(info_.rebasingClaimToken()).balanceOf(detfUser);
        assertGt(claimBal_, 0, "D15-6 claim");
        IDETFNFTVault nft_ = _bondNftVault(instance_);
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 out_ = info_.redeemClaim(claimBal_, IERC20(instance_), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0, "D15-6 DETF out");
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "D15-6 no pair to redeemer");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), 0, "D15-6 leftover pair rejoined");
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), 0, "D15-6 id0 lpOut");
    }

    function test_D15_7_realizeExpansionFirst_paysFromId0Slice() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _launchRichArgs();
        args_.name = "D15-7 realize CP";
        args_.symbol = "d157cp";
        address instance_ = _deployDetfWired(args_);
        IUniswapV4SingleStandardExchangeDETF info_ = IUniswapV4SingleStandardExchangeDETF(instance_);
        pairToken.mint(detfUser, 400 ether);
        vm.startPrank(detfUser);
        pairToken.approve(instance_, type(uint256).max);
        (uint256 tokenId,) = info_.bond(
            IERC20(address(pairToken)), 200 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        info_.sellPositionToDetfNft(tokenId, detfUser);
        vm.stopPrank();
        uint256 claimBal_ = IRebasingClaimToken(info_.rebasingClaimToken()).balanceOf(detfUser);
        vm.warp(block.timestamp + 8 hours * 20);
        uint256 pendingExp_ = info_.pendingExpansionDetf();
        uint256 lastBefore_ = info_.lastExpansionTimestamp();
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        vm.prank(detfUser);
        uint256 out_ = info_.redeemClaim(redeem_, IERC20(instance_), 0, detfUser, block.timestamp + 1 hours);
        assertGt(out_, 0, "D15-7 paid");
        if (pendingExp_ > 0) {
            assertGt(info_.lastExpansionTimestamp(), lastBefore_, "D15-7 realized");
        }
    }
}
