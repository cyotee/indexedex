// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Decimals.sol";

abstract contract UniswapV4Detf_Orbital_Extras_Decimals is TestBase_UniswapV4Detf_Orbital_Decimals {

    function test_T8_1_sameDetfPkg_asCp() public view {
        assertTrue(address(detfPkg) != address(0), "detf pkg");
        assertEq(detfInfo.hook(), reserveHook, "hook");
        assertEq(detfInfo.creationPairPerDetfWad().length, 2, "creation n-1");
    }
    function test_T8_1_firstBond_threeLegs() public {
        (uint256 tokenId, uint256 shares) = _firstBond(_u0(100));
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertTrue(detfInfo.isReserveLive());
    }
    function test_T8_1_liveMint_onePair() public {
        _firstBond(_u0(100));
        uint256 mintIn = _u0(10);
        uint256 userPred = IStandardExchangeIn(address(detfInfo)).previewExchangeIn(IERC20(address(pair0)), mintIn, IERC20(address(detfInfo)));
        vm.startPrank(detfUser);
        uint256 out = IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pair0)), mintIn, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(out, userPred);
    }

}
