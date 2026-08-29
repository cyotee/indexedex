// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Weighted_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Policy.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";
import {UniswapV4Detf_Alignment_RedeemD15Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15Base.sol";

/// @notice Weighted gold D15 redeem. D15-5 multi-leg leftover dump required (WP-UDPL-WE).
contract UniswapV4Detf_Weighted_Alignment_RedeemD15 is
    TestBase_UniswapV4Detf_Weighted_Policy,
    UniswapV4Detf_Alignment_RedeemD15Base
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Weighted_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._deployInstance(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (IERC20)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._mintTokenOf(d);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._expectInvalidCreationRate(args);
    }

    function _ownerSwap(address d, address tokenIn, address tokenOut, uint256 amount)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._ownerSwap(d, tokenIn, tokenOut, amount);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._pushSyntheticUp(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
    {
        TestBase_UniswapV4Detf_Weighted_Policy._skewSyntheticDown(d);
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Weighted_Policy)
        returns (uint256 amountOut)
    {
        return TestBase_UniswapV4Detf_Weighted_Policy._burnOn(d, detfIn, tokenOut);
    }

    function _bondOn(address d, address who, uint256 amt)
        internal
        override
        returns (uint256 tokenId, uint256 shares)
    {
        _fundActor(d, who, amt * 4);
        return UniswapV4Detf_ClaimBase._bondOn(d, who, amt);
    }

    function _liveMintOn(address d, address who, uint256 amt) internal override returns (uint256 userDetf) {
        _fundActor(d, who, amt * 4);
        return UniswapV4Detf_ClaimBase._liveMintOn(d, who, amt);
    }

    struct D15UserSnap {
        uint256 detf;
        uint256 p0;
        uint256 p1;
        uint256 s0;
        uint256 s1;
        uint256 lp;
    }

    /// @notice R-22: previewRedeem must equal redeem. 1 wei n-leg leftover-dump drift is §6.1, not a looser matcher.
    function test_D15_1_previewEqualsExecute() public override {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 preview_ = _claimTok().previewRedeem(redeem_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertEq(out_, preview_, "D15-1 preview==exec");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    /// @notice D15-5: snapshot DETF-buying power once; dump largest leftover first; recipient DETF only.
    function test_D15_5_multiLegLeftoverDump() public {
        uint256 claimBal_ = _d15_5_seedClaim();
        address hook_ = detfInfo.hook();
        address largestTok_ = _d15_5_snapshotLargest(hook_);
        D15UserSnap memory before_ = _d15_5_userSnap(hook_);
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        _d15_5_assertRecipientDetfOnly(hook_, before_, out_);
        assertLe(IERC20(largestTok_).balanceOf(detf), 10, "largest leftover dumped");
    }

    function _d15_5_seedClaim() internal returns (uint256 claimBal_) {
        _firstBond(100 ether);
        _fundActor(detf, detfUser, 200 ether);
        vm.startPrank(detfUser);
        (uint256 pair1Bond,) = detfInfo.bond(
            IERC20(address(pair1)),
            30 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(pair1Bond, 0, "pair1 live so both leftover legs exist");
        (uint256 sellId,) = _firstBond(60 ether);
        _warpMature(sellId);
        _d10SellToClaimOn(detf, sellId, detfUser);
        claimBal_ = _claimTok().balanceOf(detfUser);
        assertGt(claimBal_, 0, "D15-5 claim");
    }

    function _d15_5_snapshotLargest(address hook_) internal view returns (address largestTok_) {
        uint256 lpSnap_ = IERC20(hook_).balanceOf(address(_nft()));
        assertGt(lpSnap_, 0, "id0 LP");
        uint256 unwind_ = lpSnap_ / 2;
        if (unwind_ == 0) unwind_ = lpSnap_;
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory withdrawn_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(unwind_);
        uint256 n_ = toks_.length < withdrawn_.length ? toks_.length : withdrawn_.length;
        uint256 largestQuote_;
        uint256 snapshotCount_;
        for (uint256 i; i < n_; ++i) {
            if (toks_[i] == detf || withdrawn_[i] == 0) continue;
            uint256 q_;
            try IUniswapV4SeBufferHook(hook_).previewSwapExactIn(toks_[i], detf, withdrawn_[i])
                returns (uint256 d_)
            {
                q_ = d_;
            } catch {}
            if (q_ == 0) q_ = withdrawn_[i];
            unchecked {
                ++snapshotCount_;
            }
            if (q_ > largestQuote_) {
                largestQuote_ = q_;
                largestTok_ = toks_[i];
            }
        }
        assertGt(snapshotCount_, 1, "multi-leg leftover snapshot");
        assertTrue(largestTok_ != address(0), "largest leftover");
    }

    function _d15_5_userSnap(address hook_) internal view returns (D15UserSnap memory s) {
        s.detf = IERC20(detf).balanceOf(detfUser);
        s.p0 = pair0.balanceOf(detfUser);
        s.p1 = pair1.balanceOf(detfUser);
        s.s0 = IERC20(se0).balanceOf(detfUser);
        s.s1 = IERC20(se1).balanceOf(detfUser);
        s.lp = IERC20(hook_).balanceOf(detfUser);
    }

    function _d15_5_assertRecipientDetfOnly(address hook_, D15UserSnap memory before_, uint256 out_)
        internal
        view
    {
        assertGt(out_, 0, "D15-5 DETF paid");
        assertEq(IERC20(detf).balanceOf(detfUser) - before_.detf, out_, "recipient DETF only");
        assertEq(pair0.balanceOf(detfUser), before_.p0, "pair0 unchanged");
        assertEq(pair1.balanceOf(detfUser), before_.p1, "pair1 unchanged");
        assertEq(IERC20(se0).balanceOf(detfUser), before_.s0, "se0 unchanged");
        assertEq(IERC20(se1).balanceOf(detfUser), before_.s1, "se1 unchanged");
        assertEq(IERC20(hook_).balanceOf(detfUser), before_.lp, "hook LP unchanged");
    }
}
