// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_RouteSmoke_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_sequential_wrapThenUnwrap() public {
        uint256 pairBefore = pairToken.balanceOf(user);
        uint256 seOut = _wrapExactIn(20 ether);
        assertGt(seOut, 0);
        uint256 pairOut = _unwrapExactIn(seOut);
        assertGt(pairOut, 0);
        // ERC-4626 offset / first-deposit dust may round-trip slightly under; hook must stay flat.
        assertLe(pairBefore - pairToken.balanceOf(user), 1e16, "round-trip dust bounded");
        assertGt(pairOut, 0, "unwrap returns pair");
        _assertHookFlat();
    }
}
