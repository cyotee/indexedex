// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice Phase 4 claim: sell→mint rebasing claim; D15 redeemClaim is DETF only.
contract UniswapV4SingleStandardExchangeDETF_ClaimTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _firstBond(400 ether);
        // Second bond so we have a sellable user position with LP principal.
        _firstBond(80 ether);
    }

    function test_claim_package_wired() public view {
        assertTrue(detfInfo.rebasingClaimToken() != address(0), "claim package wired");
    }

    function test_sell_mintsRebasingClaim() public {
        (uint256 tokenId, uint256 shares) = _firstBond(50 ether);
        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);

        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        assertEq(principal, shares);
        uint256 claimAfter = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(claimAfter, claimBefore, "mintFromNFTSale increased claim balance");
    }

    function test_redeemClaim_toDetf() public {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(claimBal, 0);

        uint256 detfBefore = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 detfOut = detfInfo.redeemClaim(
            claimBal / 2,
            IERC20(detf),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
        assertGt(detfOut, 0, "redeem DETF out");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore, detfOut);
    }

    function test_redeemClaim_toPair_reverts() public {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 redeemAmt = claimBal / 3;
        if (redeemAmt == 0) return;

        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(
            redeemAmt,
            IERC20(address(pairToken)),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
    }

    function test_redeemClaim_invalidRoute_reverts() public {
        (uint256 tokenId,) = _firstBond(40 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        // Raw token not in SE allowlist → InvalidRoute
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(
            claimBal / 4,
            IERC20(address(rawToken)),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
    }
}
