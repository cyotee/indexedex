// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

contract UniswapV4OrbitalSwapHook_Deploy_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_immutablesAndRadiusZero() public view {
        assertEq(address(orbital.poolManager()), address(pm));
        assertEq(address(orbital.feeOracle()), address(indexedexManager));
        assertEq(orbital.token0(), address(token0));
        assertEq(orbital.token1(), address(token1));
        assertEq(orbital.token2(), address(token2));
        assertEq(orbital.radius(), 0);
        assertEq(orbital.lSquared(), 0);
    }

    function test_lpMetadata() public view {
        assertEq(IERC20Metadata(hook).decimals(), 18);
        string memory sym = IERC20Metadata(hook).symbol();
        assertTrue(bytes(sym).length > 4);
    }
}
