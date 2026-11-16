// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4Detf_Quad_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Decimals.sol";

abstract contract UniswapV4Detf_Quad_Extras_Decimals is TestBase_UniswapV4Detf_Quad_Decimals {

    function test_T8_3_firstBond_fourLegs() public {
        (uint256 tokenId, uint256 shares) = _firstBond(_u0(100));
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertTrue(detfInfo.isReserveLive());
    }

}
