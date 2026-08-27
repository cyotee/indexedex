// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
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
        assertEq(IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(address(weth)), address(ponsSe));
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
            IERC20(address(weth)),
            mintIn,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(userDetf, 0, "T10.9: mint WETH -> detfToken");
        assertGt(IERC20(detf).balanceOf(detfUser), 0, "T10.9: holder balance");
    }

    function test_T10_10_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(60 ether);
        vm.startPrank(detfUser);
        detfExchangeIn.exchangeIn(
            IERC20(address(weth)),
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
}
