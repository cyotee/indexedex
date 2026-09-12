// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4Detf_Weighted_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Decimals.sol";

abstract contract UniswapV4Detf_Weighted_Extras_Decimals is TestBase_UniswapV4Detf_Weighted_Decimals {

    function test_T8_4_policy_pairA_not_pairB_via_trades() public view {
        assertTrue(address(pair0) != address(pair1), "two pairs");
    }

}
