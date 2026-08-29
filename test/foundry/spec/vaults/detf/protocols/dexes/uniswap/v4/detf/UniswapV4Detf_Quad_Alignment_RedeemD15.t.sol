// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {TestBase_UniswapV4Detf_Quad_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Policy.sol";
import {UniswapV4Detf_Alignment_RedeemD15PolicyBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15PolicyBase.sol";

/// @notice Quad gold D15 redeem. D15-5 required. D15-6 extra deploy is Quad (`_deployInstance`).
contract UniswapV4Detf_Quad_Alignment_RedeemD15 is
    TestBase_UniswapV4Detf_Quad_Policy,
    UniswapV4Detf_Alignment_RedeemD15PolicyBase
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._deployInstance(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._expectInvalidCreationRate(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
        returns (IERC20)
    {
        return TestBase_UniswapV4Detf_Quad_Policy._mintTokenOf(d);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._pushSyntheticUp(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Quad_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Quad_Policy._skewSyntheticDown(d);
    }

    function test_D15_1_previewEqualsExecute() public override {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        // Pending-covered slice: two-step previewRedeem identity. Multi-leg leftover dump is D15-5.
        uint256 redeem_ = claimBal_ / 50;
        if (redeem_ == 0) redeem_ = 1;
        IRebasingClaimToken claim_ = _claimTok();
        uint256 preview_ = claim_.previewRedeem(redeem_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertEq(out_, preview_, "D15-1 preview==exec");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    function test_D15_2_smallRedeemConsumesPending() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / 10;
        if (redeem_ == 0) redeem_ = 1;
        uint256 nftDetfBefore_ = IERC20(detf).balanceOf(address(_nft()));
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertGt(out_, 0, "D15-2");
        uint256 nftDetfAfter_ = IERC20(detf).balanceOf(address(_nft()));
        if (nftDetfBefore_ > 0) {
            assertLe(nftDetfAfter_, nftDetfBefore_, "D15-2 pending consumed or held");
        }
    }

    function test_D15_3_pendingCoversOwed_skipsLpWithdraw() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        IDETFNFTVault nft_ = _nft();
        IERC20 lp_ = nft_.lpToken();
        deal(detf, address(nft_), IERC20(detf).balanceOf(address(nft_)) + 80 ether);
        uint256 lpBefore_ = lp_.balanceOf(address(nft_));
        uint256 origBefore_ = nft_.originalSharesOf(nft_.detfNFTId());
        uint256 redeem_ = claimBal_ / 50;
        if (redeem_ == 0) redeem_ = 1;
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertGt(out_, 0, "D15-3 paid");
        assertGe(lp_.balanceOf(address(nft_)), lpBefore_, "D15-3 no LP withdraw");
        assertGe(nft_.originalSharesOf(nft_.detfNFTId()) + 1, origBefore_, "D15-3 orig except leftover compound");
    }

    function test_D15_4_shortfallResidualBuy_otherBondersUnchanged() public {
        (uint256 keepBondId,) = _firstBond(100 ether);
        (uint256 sellId,) = _firstBond(60 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 keepOrig_ = nft_.originalSharesOf(keepBondId);
        _warpMature(sellId);
        _d10SellToClaimOn(detf, sellId, detfUser);
        uint256 claimBal_ = _claimTok().balanceOf(detfUser);
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertGt(out_, 0, "D15-4 paid");
        assertEq(nft_.originalSharesOf(keepBondId), keepOrig_, "D15-4 other originalShares");
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "D15-4 no pair to redeemer");
    }

    /// @notice Multi-leg leftover dump: snapshot DETF-buying power once; dump largest leftover first.
    function test_D15_5_multiLegLeftoverDump() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(detfInfo.hook());
        address[] memory toks_ = hook_.tokens();
        IDETFNFTVault nft_ = _nft();
        uint256 orig0_ = nft_.originalSharesOf(nft_.detfNFTId());
        require(orig0_ > 0, "D15-5 id0 originalShares");
        uint256 unwindLp_ = orig0_ / 4;
        if (unwindLp_ == 0) unwindLp_ = orig0_;
        uint256[] memory withdrawn_ = hook_.previewExitProportional(unwindLp_);
        uint256 bestPow_;
        address bestTok_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) continue;
            if (i >= withdrawn_.length || withdrawn_[i] == 0) continue;
            uint256 pow_;
            try hook_.previewSwapExactIn(toks_[i], detf, withdrawn_[i]) returns (uint256 d_) {
                pow_ = d_;
            } catch {}
            emit log_named_address("D15-5 leftover", toks_[i]);
            emit log_named_uint("D15-5 buyingPower", pow_);
            if (pow_ > bestPow_) {
                bestPow_ = pow_;
                bestTok_ = toks_[i];
            }
        }
        assertTrue(bestTok_ != address(0), "D15-5 snapshot has a leftover pair");
        assertGt(bestPow_, 0, "D15-5 largest buying power");

        uint256 p0Before_ = pairToken.balanceOf(detfUser);
        uint256 p1Before_ = pair1.balanceOf(detfUser);
        uint256 p2Before_ = pair2.balanceOf(detfUser);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertGt(out_, 0, "D15-5 DETF paid");
        assertEq(pairToken.balanceOf(detfUser), p0Before_, "D15-5 no pair0 to redeemer");
        assertEq(pair1.balanceOf(detfUser), p1Before_, "D15-5 no pair1 to redeemer");
        assertEq(pair2.balanceOf(detfUser), p2Before_, "D15-5 no pair2 to redeemer");
        assertLe(IERC20(bestTok_).balanceOf(detf), 10, "D15-5 largest leftover dumped");
    }

    function test_D15_6_lastExitRejoinsLeftover() public {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_ = _withTag(args_, string.concat("d156", _nextTag()));
        address instance_ = _deployInstance(args_);
        _bindPolicy(instance_);
        (uint256 tokenId,) = _bondOn(instance_, detfUser, 80 ether);
        _warpMatureOf(instance_, tokenId);
        _d10SellToClaimOn(instance_, tokenId, detfUser);
        uint256 claimBal_ = _claimTokOf(instance_).balanceOf(detfUser);
        assertGt(claimBal_, 0, "D15-6 claim");
        IDETFNFTVault nft_ = _nftOf(instance_);
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        uint256 out_ = _redeemOn(instance_, detfUser, claimBal_);
        assertGt(out_, 0, "D15-6 DETF out");
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "D15-6 no pair to redeemer");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), 0, "D15-6 leftover pair rejoined");
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), 0, "D15-6 id0 lpOut");
    }

    function test_D15_7_realizeExpansionFirst_paysFromId0Slice() public {
        address instance_ = _deployD31LaunchRichLive();
        (uint256 tokenId,) = _bondOn(instance_, detfUser, 40 ether);
        _warpMatureOf(instance_, tokenId);
        _d10SellToClaimOn(instance_, tokenId, detfUser);
        uint256 claimBal_ = _claimTokOf(instance_).balanceOf(detfUser);
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * POLICY_EXPANSION_CATCHUP);
        IUniswapV4Detf info_ = IUniswapV4Detf(instance_);
        uint256 pendingExp_ = info_.pendingExpansionDetf();
        uint256 nftDetfBefore_ = IERC20(instance_).balanceOf(info_.bondNftVault());
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 out_ = _redeemOn(instance_, detfUser, redeem_);
        assertGt(out_, 0, "D15-7 paid");
        if (pendingExp_ > 0) {
            assertLt(info_.pendingExpansionDetf(), pendingExp_, "D15-7 realized pending");
            assertGe(
                IERC20(instance_).balanceOf(info_.bondNftVault()) + out_ + 1,
                nftDetfBefore_,
                "D15-7 id0 slice"
            );
        }
    }

    function test_D15_pendingFirst_thenZapOutToDetf() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pendingDetf_ = IERC20(detf).balanceOf(address(nft_));
        uint256 lpBefore_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 pairBefore_ = pairToken.balanceOf(detfUser);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 out_ = _redeemOn(detf, detfUser, claimBal_);
        assertGt(out_, 0, "pendingFirst DETF");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
        assertEq(pairToken.balanceOf(detfUser), pairBefore_, "unwind to DETF not pair");
        uint256 pendingAfter_ = IERC20(detf).balanceOf(address(nft_));
        if (pendingDetf_ > 0) {
            assertLe(pendingAfter_, pendingDetf_, "pending first");
        }
        uint256 lpAfter_ = nft_.lpToken().balanceOf(address(nft_));
        if (out_ > pendingDetf_) {
            assertLe(lpAfter_, lpBefore_, "shortfall from id0 LP");
        }
    }
}
