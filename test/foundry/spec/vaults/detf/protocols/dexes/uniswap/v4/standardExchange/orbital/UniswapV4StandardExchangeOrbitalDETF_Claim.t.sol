// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @notice Claim: mature sell->mint rebasing claim; redeemClaim rateAsset/pair/vaultShare matrix + redeposit.
contract UniswapV4StandardExchangeOrbitalDETF_ClaimTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function setUp() public override {
        super.setUp();
        _firstBondBothPairs(400 ether, 400 ether);
        // Live single-leg bond for sellable user position.
        vm.startPrank(detfUser);
        detfInfo.bond(IERC20(pair0), 80 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_claim_package_wired() public view {
        assertTrue(detfInfo.rebasingClaimToken() != address(0), "claim package wired");
    }

    function test_sell_mintsRebasingClaim() public {
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) =
            detfInfo.bond(IERC20(pair0), 50 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();

        uint256 unlock = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId);
        vm.warp(unlock + 1);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBefore = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 protocolLpBefore = detfInfo.protocolLp();

        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        assertEq(principal, shares, "principal == LP originalShares");
        uint256 claimAfter = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(claimAfter, claimBefore, "mintFromNFTSale increased claim balance");
        assertGt(detfInfo.protocolLp(), protocolLpBefore, "id 0 originalShares received bond principal");
    }

    function test_redeemClaim_toDetf() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) =
            detfInfo.bond(IERC20(pair0), 60 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        vm.warp(IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId) + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(claimBal, 0);

        uint256 before_ = IERC20(detf).balanceOf(detfUser);
        uint256 dl = block.timestamp + 30 days;
        vm.prank(detfUser);
        uint256 out_ = detfInfo.redeemClaim(claimBal / 2, IERC20(detf), 0, detfUser, dl);
        assertGt(out_, 0, "D15 redeem DETF only");
        assertEq(IERC20(detf).balanceOf(detfUser) - before_, out_);
    }

    function test_redeemClaim_pairToken_reverts() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) =
            detfInfo.bond(IERC20(pair1), 60 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        vm.warp(IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId) + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 dl = block.timestamp + 30 days;
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal / 3, IERC20(pair1), 0, detfUser, dl);
    }

    function test_depositClaim_pair_mintsClaim() public {
        vm.startPrank(detfUser);
        uint256 claimOut = detfInfo.depositClaim(IERC20(pair0), 40 ether, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut, 0, "depositClaim pair mints");
        assertGt(IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(detfUser), 0);
    }

    function test_depositClaim_freeDetf_mintsClaim() public {
        vm.startPrank(detfUser);
        uint256 minted = detfExchangeIn.exchangeIn(
            IERC20(pair0), 40 ether, IERC20(detf), 0, detfUser, false, _dl()
        );
        IERC20(detf).approve(detf, minted);
        uint256 claimOut = detfInfo.depositClaim(IERC20(detf), minted / 2, 0, detfUser, false, _dl());
        vm.stopPrank();
        assertGt(claimOut, 0, "depositClaim free detfToken mints");
    }

    function test_redeemClaim_invalidRoute_reverts() public {
        vm.startPrank(detfUser);
        (uint256 tokenId,) =
            detfInfo.bond(IERC20(pair0), 40 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        vm.warp(IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId) + 1);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 claimBal = IRebasingClaimToken(claim).balanceOf(detfUser);
        address junk = address(0xDEAD);
        uint256 dl = block.timestamp + 30 days;
        vm.prank(detfUser);
        vm.expectRevert();
        detfInfo.redeemClaim(claimBal / 4, IERC20(junk), 0, detfUser, dl);
    }
}
