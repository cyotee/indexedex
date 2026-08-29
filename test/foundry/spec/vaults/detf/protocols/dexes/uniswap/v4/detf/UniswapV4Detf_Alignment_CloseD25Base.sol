// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Shared D25 close helpers. No `test_*`. No extra deploy `setUp`.
/// @dev OpenBase and later Stage 11 Open call these internals (R-7 / R-24).
abstract contract UniswapV4Detf_Alignment_CloseD25Base is TestBase_UniswapV4Detf {
    address internal d25Alice;
    address internal d25Bob;

    function _nft() internal view virtual returns (IDETFNFTVault) {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _minOut() internal view virtual returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(detfInfo.hook()).tokens().length);
    }

    function _ensureActors() internal {
        if (d25Alice != address(0)) return;
        d25Alice = makeAddr("d25alice");
        d25Bob = makeAddr("d25bob");
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        virtual
        returns (uint256 tokenId_, uint256 shares_)
    {
        pairToken.mint(bonder_, pairAmount_);
        vm.startPrank(bonder_);
        pairToken.approve(detf, pairAmount_);
        (tokenId_, shares_) = detfInfo.bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            bonder_,
            false,
            _deadline()
        );
        vm.stopPrank();
    }

    function _liveAliceBob() internal returns (uint256 aliceId_, uint256 bobId_) {
        _ensureActors();
        (aliceId_,) = _bondAs(d25Alice, 40 ether);
        (bobId_,) = _bondAs(d25Bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    function _liveAliceOnly() internal returns (uint256 aliceId_) {
        _ensureActors();
        (aliceId_,) = _bondAs(d25Alice, 40 ether);
        _d25SeedHook();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    /// @dev Pons V1 wrap can leave last-close DETF rejoin below MINIMUM_LIQUIDITY. Seed pair via mint.
    function _d25SeedHook() internal virtual {}

    function _claimRewardsAs(address holder_, uint256 tokenId_) internal returns (uint256 claimed_) {
        IDETFNFTVault nft_ = _nft();
        vm.prank(holder_);
        claimed_ = nft_.claimRewards(tokenId_, holder_);
    }

    function _closeAs(address holder_, uint256 tokenId_) internal returns (uint256[] memory out_) {
        uint256[] memory minOut_ = _minOut();
        uint256 deadline_ = _deadline();
        vm.prank(holder_);
        out_ = detfInfo.closeBondMature(tokenId_, minOut_, holder_, deadline_);
    }

    /// @dev User DETF is NFT `claimRewards` on that id. Close must not pay the withdrawn self-leg.
    function _assert_D25_1_userDetfOnlyFromClaimRewards() internal {
        (, uint256 bobId_) = _liveAliceBob();
        IERC20 detfToken_ = IERC20(detf);
        uint256 pending_ = _nft().pendingRewards(bobId_);
        uint256 detfBeforeClaim_ = detfToken_.balanceOf(d25Bob);
        uint256 claimed_ = _claimRewardsAs(d25Bob, bobId_);
        assertApproxEqAbs(claimed_, pending_, 1, "D25-1 claimed==pending");
        assertEq(detfToken_.balanceOf(d25Bob) - detfBeforeClaim_, claimed_, "D25-1 DETF from claimRewards");
        uint256 detfAfterClaim_ = detfToken_.balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        assertEq(out_[_detfTokenIndex(toks_)], 0, "D25-1 DETF slot unpaid");
        assertEq(detfToken_.balanceOf(d25Bob), detfAfterClaim_, "D25-1 close does not pay DETF");
    }

    function _assert_D25_2_withdrawnDetfNotBurned() internal {
        (, uint256 bobId_) = _liveAliceBob();
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        _closeAs(d25Bob, bobId_);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2 no burn of withdrawn DETF");
    }

    function _assert_D25_3_id0OriginalSharesRise() internal {
        (, uint256 bobId_) = _liveAliceBob();
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        _closeAs(d25Bob, bobId_);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3 id 0 credited");
    }

    function _detfTokenIndex(address[] memory toks_) internal view returns (uint256 idx) {
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) return i;
        }
        revert("DETF not in tokens()");
    }

    function _assert_D25_4_userReceivesNonDetfBasket() internal {
        (, uint256 bobId_) = _liveAliceBob();
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_ = _detfTokenIndex(toks_);
        uint256 pairBefore_ = pairToken.balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        assertEq(out_.length, toks_.length, "tokens() order");
        assertEq(out_[detfIdx_], 0, "DETF slot unpaid");
        uint256 pairPaid_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == address(pairToken)) pairPaid_ = out_[i];
        }
        assertGt(pairPaid_, 0, "pair basket");
        assertEq(pairToken.balanceOf(d25Bob) - pairBefore_, pairPaid_, "pair paid");
    }

    function _assert_D25_5_ids1and2CannotClose() internal {
        _ensureActors();
        _bondAs(d25Alice, 20 ether);
        uint256[] memory minOut_ = _minOut();
        uint256 deadline_ = _deadline();
        vm.expectRevert(
            abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID)
        );
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, d25Alice, deadline_);
        vm.expectRevert(
            abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID)
        );
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, d25Alice, deadline_);
    }

    function _assert_D25_6_previewEqualsExecute() internal {
        (, uint256 bobId_) = _liveAliceBob();
        uint256[] memory preview_ = detfInfo.previewCloseBondMature(bobId_);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        assertEq(out_.length, preview_.length, "D25-6 length");
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1, "D25-6 preview==exec");
        }
    }

    /// @dev Last user close rejoins DETF at remaining hook liquidity; id 0 originalShares prove lpOut>0.
    function _assert_D25_7_minRejoinLpOutGt0() internal {
        uint256 aliceId_ = _liveAliceOnly();
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        _closeAs(d25Alice, aliceId_);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-7 MIN rejoin credited id 0");
    }

    function _assert_D25_lastClose_feeCreatorPendingDoesNotJump() internal {
        uint256 aliceId_ = _liveAliceOnly();
        IDETFNFTVault nft_ = _nft();
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        _closeAs(d25Alice, aliceId_);
        assertLe(
            nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID),
            feePending_ + 1,
            "D25 leftover DETF must not extract to feeTo"
        );
        assertLe(
            nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID),
            creatorPending_ + 1,
            "D25 leftover DETF must not extract to creator"
        );
    }
}
