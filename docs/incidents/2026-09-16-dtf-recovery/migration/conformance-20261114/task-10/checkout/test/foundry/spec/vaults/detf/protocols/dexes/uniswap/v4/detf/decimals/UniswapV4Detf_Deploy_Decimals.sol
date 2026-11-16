// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice T7.1 Deployment wiring and rejection of obsolete payload encoding.
abstract contract UniswapV4Detf_Deploy_Decimals is TestBase_UniswapV4Detf_Decimals {
    function test_deploy_inert_until_first_bond() public {
        assertFalse(detfInfo.isReserveLive(), "inert");
        assertTrue(detfInfo.isReserveWired(), "nft+claim wired");
        assertEq(detfInfo.reservePool(), reserveHook, "reservePool=hook");
        assertEq(detfInfo.hook(), reserveHook, "hook");
    }
}
