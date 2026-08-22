// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";

contract UniswapV4StandardExchangeCurveQuadStableDETF_Alignment_RedeemD15 is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    function setUp() public override {
        super.setUp();
        detf = _deployDetfWired(_openArgsUnique("d15"));
        _bindDetfPointers();
        _setBondTermsFor(detf);
        _firstBondOn(detf, _amts(50 ether), pair0);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        _fundPair(detf, pair0, detfUser, 40 ether);
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(IERC20(pair0), 20 ether, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal_ / 3, IERC20(pair0), 0, detfUser, _dl());
    }

    function test_D15_redeemPaysDetfOnly() public {
        _fundPair(detf, pair0, detfUser, 40 ether);
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(IERC20(pair0), 20 ether, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(claimBal_ / 2, IERC20(detf), 0, detfUser, _dl());
        assertGt(out_, 0);
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    function _amts(uint256 v_) internal view returns (uint256[] memory a) {
        a = new uint256[](detfInfo.m());
        for (uint256 i; i < a.length; ++i) a[i] = v_;
    }
}
