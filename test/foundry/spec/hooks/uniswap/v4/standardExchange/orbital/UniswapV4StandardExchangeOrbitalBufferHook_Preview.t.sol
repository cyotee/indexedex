// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_PreviewTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_previewAdd_matches_exec() public {
        _seedThreeLeg(100 ether);
        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(20 ether, 20 ether, 20 ether);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) =
            _addLiquidity(20 ether, 20 ether, 20 ether);
        assertEq(es, ps);
        assertEq(e0, p0);
        assertEq(e1, p1);
        assertEq(e2, p2);
    }

    function test_previewSwap_matches_exec() public {
        _seedThreeLeg(200 ether);
        uint256 prev = orbital.previewSwapExactIn(address(token0), address(token1), 2 ether);
        uint256 before = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 2 ether);
        assertEq(token1.balanceOf(user) - before, prev);
    }
}
