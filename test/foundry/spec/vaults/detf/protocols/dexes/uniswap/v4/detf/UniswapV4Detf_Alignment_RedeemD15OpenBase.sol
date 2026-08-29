// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

/// @notice Open-layer D15 subset: preview==exec, non-DETF payout forbidden, redeem pays DETF only.
abstract contract UniswapV4Detf_Alignment_RedeemD15OpenBase is UniswapV4Detf_ClaimBase {
    function _sellAndClaimOn(address d, address seller, uint256 firstAmt, uint256 sellAmt)
        internal
        returns (uint256 claimBal)
    {
        _bondOn(d, seller, firstAmt);
        (uint256 tokenId,) = _bondOn(d, seller, sellAmt);
        _warpMatureOf(d, tokenId);
        _d10SellToClaimOn(d, tokenId, seller);
        claimBal = _claimTokOf(d).balanceOf(seller);
        assertGt(claimBal, 0, "claim minted");
    }

    function _redeemOn(address d, address who, uint256 amt) internal returns (uint256 detfOut) {
        IRebasingClaimToken claim_ = _claimTokOf(d);
        vm.prank(who);
        detfOut = claim_.redeem(amt, who, false);
    }

    function _assertRedeemPaysDetfOnly(address d, address who, uint256 amt) internal {
        IERC20 detfTok_ = IERC20(d);
        IERC20 pair_ = IERC20(address(pairToken));
        IERC20 share_ = IERC20(se);
        IERC20 lp_ = _lpOf(d);
        uint256 detfBefore_ = detfTok_.balanceOf(who);
        uint256 pairBefore_ = pair_.balanceOf(who);
        uint256 shareBefore_ = share_.balanceOf(who);
        uint256 lpBefore_ = lp_.balanceOf(who);
        uint256 out_ = _redeemOn(d, who, amt);
        assertGt(out_, 0, "DETF out");
        assertEq(detfTok_.balanceOf(who) - detfBefore_, out_, "recipient DETF");
        assertEq(pair_.balanceOf(who), pairBefore_, "pair unchanged");
        assertEq(share_.balanceOf(who), shareBefore_, "SE share unchanged");
        assertEq(lp_.balanceOf(who), lpBefore_, "hook LP unchanged");
    }

    /// @dev Quad gold D15-1 is a pending-covered slice (`/ 50`). Half-redeem is leftover-dump (D15-5).
    function _d15IdentityDenom() internal view virtual returns (uint256) {
        if (address(detfInfo) != address(0)) {
            address hook_ = detfInfo.hook();
            if (hook_ != address(0) && IUniswapV4SeBufferHook(hook_).tokens().length >= 4) {
                return 50;
            }
        }
        return 2;
    }

    function test_D15_1_previewEqualsExecute() public virtual {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / _d15IdentityDenom();
        if (redeem_ == 0) redeem_ = 1;
        IRebasingClaimToken claim_ = _claimTok();
        uint256 preview_ = claim_.previewRedeem(redeem_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertEq(out_, preview_, "D15-1 preview==exec");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    function test_D15_8_nonDetfPayoutForbidden() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / 3;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(detf, detfUser, redeem_);
    }

    function test_D15_redeem_paysDetf_only() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 50 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(detf, detfUser, redeem_);
    }
}
