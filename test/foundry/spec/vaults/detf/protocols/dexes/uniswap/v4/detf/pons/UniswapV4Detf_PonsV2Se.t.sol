// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4Detf_PonsV2Se
} from "contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol";

/**
 * @title UniswapV4Detf_PonsV2Se
 * @notice T10.8–T10.10: unified Uni V4 DETF first bond / mint against a pons v2 Uni V4 SE.
 */
contract UniswapV4Detf_PonsV2Se is TestBase_UniswapV4Detf_PonsV2Se {
    function test_T10_8_firstBond_withPonsSeLive() public {
        assertEq(_boundSe(), address(ponsSe), "T10.8: bound SE");
        assertEq(IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(launchToken), address(ponsSe));
        (uint256 tokenId, uint256 shares) = _firstBond(50 ether);
        assertGt(tokenId, 0, "T10.8: tokenId");
        assertGt(shares, 0, "T10.8: shares");
        assertTrue(detfInfo.isReserveLive(), "T10.8: live");
    }

    function test_T10_9_liveMint_weth() public {
        _firstBond(80 ether);
        uint256 mintIn = 20 ether;
        vm.startPrank(detfUser);
        uint256 userDetf = detfExchangeIn.exchangeIn(
            IERC20(launchToken),
            mintIn,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(userDetf, 0, "T10.9: mint launch token -> detfToken");
        assertGt(IERC20(detf).balanceOf(detfUser), 0, "T10.9: holder balance");
    }

    function test_T10_10_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(60 ether);
        vm.startPrank(detfUser);
        detfExchangeIn.exchangeIn(
            IERC20(launchToken),
            15 ether,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        address hook = detfInfo.hook();
        assertEq(IERC20(hook).balanceOf(detf), 0, "T10.10: no hook LP on diamond");
        assertEq(IERC20(address(ponsSe)).balanceOf(detf), 0, "T10.10: no SE share on diamond");
        assertEq(IERC20(address(weth)).balanceOf(detf), 0, "T10.10: no WETH on diamond");
        assertEq(IERC20(launchToken).balanceOf(detf), 0, "T10.10: no launch token on diamond");
    }

    function test_H_CP_P2_firstBond() public {
        address mintToken = _mintToken();
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");
        assertTrue(detfInfo.isReserveLive(), "live");
        assertEq(mintToken, launchToken, "hook pair is pons v2 launch token");
        _assertR19();
    }

    function test_H_CP_P2_mint() public {
        address mintToken = _mintToken();
        _firstBond(100 ether);
        uint256 mintIn = 10 ether;
        (, uint256 userPred,) = detfInfo.previewMint(IERC20(mintToken), mintIn);
        vm.startPrank(detfUser);
        uint256 out = detfInfo.mint(
            IERC20(mintToken), mintIn, 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out, 0, "out");
        assertEq(out, userPred, "previewMint==exec");
        _assertR19();
        _assertSeAllowancesZero();
    }

    function test_H_CP_P2_burn() public {
        address mintToken = _mintToken();
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 minted = detfInfo.mint(
            IERC20(mintToken), 10 ether, 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted, 0, "minted");

        uint256 burnIn = minted / 2;
        _assertR19();
        _assertSeAllowancesZero();
        uint256 preview = detfInfo.previewBurn(burnIn, IERC20(mintToken));
        uint256 pairBefore = IERC20(mintToken).balanceOf(detfUser);
        uint256 supplyBefore = IERC20(detf).totalSupply();

        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnIn);
        uint256 amountOut = detfInfo.burn(
            burnIn, IERC20(mintToken), 0, detfUser, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(amountOut, preview, "previewBurn==exec");
        uint256 pairAfter = IERC20(mintToken).balanceOf(detfUser);
        assertGe(pairAfter, pairBefore, "user mintToken increased");
        assertEq(pairAfter - pairBefore, amountOut, "user mintToken delta");
        assertEq(IERC20(detf).totalSupply(), supplyBefore - burnIn, "DETF supply");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "leftover LP not on diamond");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), 0, "LP on Bond NFT");
        _assertR19();
    }

    function test_H_CP_P2_close() public {
        address mintToken = _mintToken();
        (uint256 tokenId,) = _firstBond(100 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(IERC20(mintToken), 10 ether, 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();

        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _assertSeAllowancesZero();
        uint256[] memory minOut = new uint256[](toks.length);
        uint256 userBefore = IERC20(mintToken).balanceOf(detfUser);

        vm.prank(detfUser);
        uint256[] memory paid = detfInfo.closeBondMature(
            tokenId, minOut, detfUser, block.timestamp + 1 hours
        );

        assertEq(paid.length, toks.length, "n");
        uint256 detfIndex;
        bool sawPair;
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == detf) {
                detfIndex = i;
                assertEq(paid[i], 0, "DETF slot 0");
            } else if (paid[i] > 0) {
                sawPair = true;
            }
        }
        assertEq(paid[detfIndex], 0, "paid[detfIndex]==0");
        assertTrue(sawPair, "some non-DETF paid>0");
        uint256 pairPaid;
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == mintToken) pairPaid = paid[i];
        }
        assertGt(pairPaid, 0, "mintToken basket");
        assertEq(IERC20(mintToken).balanceOf(detfUser) - userBefore, pairPaid, "user received");
        assertEq(IDETFNFTVault(detfInfo.bondNftVault()).originalSharesOf(tokenId), 0, "retired");
        _assertR19();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) {
                assertLe(IERC20(toks[i]).balanceOf(reserveHook), 10, "hook pair <=10 wei");
            }
        }
    }
}
