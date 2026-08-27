// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.5 first bond joinUnbalanced; ungated; then live.
contract UniswapV4Detf_Bond is TestBase_UniswapV4Detf {
    function test_T7_5_firstBond_joinUnbalanced_goesLive() public {
        assertFalse(detfInfo.isReserveLive(), "pre-live");
        assertTrue(IUniswapV4SeBufferHook(reserveHook).firstJoinMustBeFullBook(), "full book");
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(detfInfo.isReserveLive(), "live");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "no LP on diamond");
        assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), 0, "LP on NFT");
        _assertNoJoinableDust();
    }

    function test_preLive_mint_reverts() public {
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.mint(
            IERC20(address(pairToken)),
            1 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
