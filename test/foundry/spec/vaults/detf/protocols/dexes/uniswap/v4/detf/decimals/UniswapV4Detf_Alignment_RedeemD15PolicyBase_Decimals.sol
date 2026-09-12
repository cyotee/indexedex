// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_Alignment_RedeemD15OpenBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_RedeemD15OpenBase_Decimals.sol";

/// @notice Policy-layer D15: Open subset plus D22 / D15-9 (ungated redeem in deadband).
abstract contract UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals is UniswapV4Detf_Alignment_RedeemD15OpenBase_Decimals {
    function _policySellClaim(address d) internal returns (uint256 claimBal) {
        (uint256 tokenId,) = _bondOn(d, detfUser, _uPair(10));
        _warpMatureOf(d, tokenId);
        _d10SellToClaimOn(d, tokenId, detfUser);
        claimBal = _claimTokOf(d).balanceOf(detfUser);
        assertGt(claimBal, 0, "policy claim");
    }

    function _skewMintBlocked(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        for (uint256 i; i < 40 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertFalse(info.isMintingAllowed(), "Policy deadband");
    }

    function test_D22_claimUngated() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _policySellClaim(d);
        _skewMintBlocked(d);
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 detfBefore_ = IERC20(d).balanceOf(detfUser);
        uint256 pairBefore_ = IERC20(address(pairToken)).balanceOf(detfUser);
        uint256 out_ = _redeemOn(d, detfUser, redeem_);
        assertGt(out_, 0, "D22 redeem in deadband");
        assertEq(IERC20(d).balanceOf(detfUser) - detfBefore_, out_);
        assertEq(IERC20(address(pairToken)).balanceOf(detfUser), pairBefore_, "D22 no pair");
    }

    // D15-9 is covered by test_D22_claimUngated with recipient balance assertions.
}
