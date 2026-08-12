// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_Routes_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_HS1_wrapExactIn_previewEqualsExecution() public {
        _wrapExactIn(10 ether);
        _assertHookFlat();
    }

    function test_HS2_unwrapExactIn_previewEqualsExecution() public {
        _unwrapExactIn(5 ether);
        _assertHookFlat();
    }

    function test_HS3_wrapExactOut_previewEqualsExecution() public {
        _wrapExactOut(3 ether);
        _assertHookFlat();
    }

    function test_HS4_unwrapExactOut_previewEqualsExecution() public {
        _unwrapExactOut(2 ether);
        _assertHookFlat();
    }

    function test_HP_zeroPreview_reverts() public {
        vm.expectRevert();
        buffer.previewWrap(0);
        vm.expectRevert();
        buffer.previewUnwrap(0);
        vm.expectRevert();
        buffer.previewWrapExactOut(0);
        vm.expectRevert();
        buffer.previewUnwrapExactOut(0);
    }
}
