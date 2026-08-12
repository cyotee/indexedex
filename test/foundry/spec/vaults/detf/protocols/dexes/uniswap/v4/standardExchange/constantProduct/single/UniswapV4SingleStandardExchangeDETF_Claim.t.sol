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

/// @notice Phase 4 claim: sell→mint rebasing claim; redeemClaim pair / vaultShare / SE token matrix.
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

    function test_redeemClaim_toPair() public {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(claimBal, 0);

        // Approve DETF to burn claim shares (burnShares pulls from owner unless pretransferred).
        // burnShares is onlyOwner (DETF) and burns from owner without transfer when called by DETF.
        uint256 pairBefore = pairToken.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 pairOut = detfInfo.redeemClaim(
            claimBal / 2,
            IERC20(address(pairToken)),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
        assertGt(pairOut, 0, "redeem pair out");
        assertEq(pairToken.balanceOf(detfUser) - pairBefore, pairOut);
    }

    function test_redeemClaim_toVaultShare() public {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 redeemAmt = claimBal / 3;
        if (redeemAmt == 0) return;

        vm.prank(detfUser);
        uint256 shareOut = detfInfo.redeemClaim(
            redeemAmt,
            IERC20(se),
            0,
            detfUser,
            block.timestamp + 1 hours
        );
        assertGt(shareOut, 0, "redeem vaultShare out");
        assertGt(IERC20(se).balanceOf(detfUser), 0);
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
