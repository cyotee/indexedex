// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";

/// @notice T8.1 Orbital: Default mint rows = two pairs + two shares; first bond three legs.
contract UniswapV4Detf_Orbital is TestBase_UniswapV4Detf_Orbital {
    function test_T8_1_sameDetfPkg_asCp() public view {
        assertTrue(address(detfPkg) != address(0), "detf pkg");
        assertEq(detfInfo.hook(), reserveHook, "hook");
        assertEq(detfInfo.creationPairPerDetfWad().length, 2, "creation n-1");
    }

    function test_T8_1_defaultMintRows_twoPairsTwoShares() public view {
        IUniswapV4Detf.IoRoute[] memory mint_ = detfInfo.mintRoutes();
        assertEq(mint_.length, 4, "two pairs + two shares");
        bool hasP0;
        bool hasP1;
        bool hasS0;
        bool hasS1;
        for (uint256 i; i < mint_.length; ++i) {
            address t = address(mint_[i].token);
            if (t == address(pair0)) hasP0 = true;
            if (t == address(pair1)) hasP1 = true;
            if (t == se0) hasS0 = true;
            if (t == se1) hasS1 = true;
        }
        assertTrue(hasP0 && hasP1 && hasS0 && hasS1, "pairs+shares");
    }

    function test_T8_1_firstBond_threeLegs() public {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        assertEq(toks.length, 3, "orbital n=3");
        assertTrue(IUniswapV4SeBufferHook(reserveHook).firstJoinMustBeFullBook(), "full book");
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(detfInfo.isReserveLive(), "live");
        _assertNoJoinableDust();
    }

    function test_T8_1_liveMint_onePair() public {
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 out_ = detfInfo.mint(
            IERC20(address(pair0)),
            10 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "minted");
        detfInfo.sweepDust();
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "no hook LP");
        assertEq(IERC20(se0).balanceOf(detf), 0, "no se0");
        assertEq(IERC20(se1).balanceOf(detf), 0, "no se1");
    }
}
