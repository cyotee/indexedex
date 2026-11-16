// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

/**
 * @title TestBase_UniswapV4SingleSEBufferHook_Adversarial
 * @notice Extends package TestBase for adversarial suites (production entry points only).
 */
abstract contract TestBase_UniswapV4SingleSEBufferHook_Adversarial is TestBase {
    function setUp() public virtual override {
        super.setUp();
        _initPool();
    }
}
