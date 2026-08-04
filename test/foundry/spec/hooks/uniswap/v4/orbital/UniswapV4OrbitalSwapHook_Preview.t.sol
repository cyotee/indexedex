// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

contract UniswapV4OrbitalSwapHook_Preview_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_preview_lp_and_swap_bitExact() public {
        _seedThreeLeg(300 ether);
        _setDexFee(0.001e18);

        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(10 ether, 10 ether, 10 ether);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) =
            _addLiquidity(10 ether, 10 ether, 10 ether);
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);

        uint256 predOut = orbital.previewSwapExactIn(address(token0), address(token2), 2 ether);
        uint256 before = token2.balanceOf(user);
        _swapExactIn(address(token0), address(token2), 2 ether);
        assertEq(token2.balanceOf(user) - before, predOut);
    }
}
