// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";

contract UniswapV4StandardExchangeWeightedDETF_Alignment_RedeemD15 is
    TestBase_UniswapV4StandardExchangeWeightedDETF
{
    function setUp() public override {
        _setUpPlatform();
        detf = _deployDetfWired(_openArgsUnique("d15"));
        _bindDetfPointers();
        _firstBondOn(detf, _one(200 ether), pair0);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        _fundPair(detf, pair0, detfUser, 80 ether);
        vm.startPrank(detfUser);
        (uint256 tokenId,) = detfInfo.bond(IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser);
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal_ / 3, IERC20(pair0), 0, detfUser, _dl());
    }

    function _one(uint256 amt_) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = amt_;
    }
}
