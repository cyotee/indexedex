// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";

/// @notice T8.3 Quad: first bond four legs; Custom close one pair.
contract UniswapV4Detf_Quad is TestBase_UniswapV4Detf_Quad {
    function test_T8_3_firstBond_fourLegs() public {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        assertEq(toks.length, 4, "quad n=4");
        assertEq(detfInfo.creationPairPerDetfWad().length, 3, "n-1");
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(detfInfo.isReserveLive(), "live");
        _assertNoJoinableDust();
    }

    function test_T8_3_customClose_onePair() public {
        IUniswapV4Detf.PkgArgs memory args = _customClosePair0Args();
        address customDetf = _deployQuadHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(customDetf);
        IUniswapV4Detf.IoRoute[] memory close_ = info.closeRoutes();
        assertEq(close_.length, 1, "custom close length 1");
        assertEq(address(close_[0].token), address(pair0), "close pair0");
        assertEq(uint8(info.closeRouteMode()), uint8(IUniswapV4Detf.RouteTableMode.Custom), "custom");

        vm.startPrank(detfUser);
        IERC20(address(pair0)).approve(customDetf, type(uint256).max);
        IERC20(address(pair1)).approve(customDetf, type(uint256).max);
        IERC20(address(pair2)).approve(customDetf, type(uint256).max);
        (uint256 tokenId, uint256 shares) = info.bond(
            IERC20(address(pair0)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isReserveLive(), "live");
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        // Custom close leftover swaps: CP pathfinder T7.12 drives closeBondMature on this DFPkg.
    }
}
