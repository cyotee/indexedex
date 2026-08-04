// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

/// @dev SimpleMintableERC20 is 18 decimals; LP decimals always 18 (Q24).
contract UniswapV4OrbitalSwapHook_Decimals_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_lpDecimalsAlways18() public {
        _seedThreeLeg(10 ether);
        assertEq(IERC20Metadata(hook).decimals(), 18);
    }
}
