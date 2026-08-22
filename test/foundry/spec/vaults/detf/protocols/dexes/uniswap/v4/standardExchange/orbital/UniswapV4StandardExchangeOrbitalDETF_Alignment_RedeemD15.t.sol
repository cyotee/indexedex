// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";

contract UniswapV4StandardExchangeOrbitalDETF_Alignment_RedeemD15 is
    TestBase_UniswapV4StandardExchangeOrbitalDETF
{
    function setUp() public override {
        super.setUp();
        _firstBondBothPairs(200 ether, 200 ether);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(
            IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal_ / 3, IERC20(pair0), 0, detfUser, block.timestamp + 1 hours);
    }
}
