// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_Flat_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_flat_afterWrapUnwrap() public {
        _wrapExactIn(10 ether);
        _assertHookFlat();
        _unwrapExactIn(4 ether);
        _assertHookFlat();
        _wrapExactOut(2 ether);
        _assertHookFlat();
        _unwrapExactOut(1 ether);
        _assertHookFlat();
    }
}
