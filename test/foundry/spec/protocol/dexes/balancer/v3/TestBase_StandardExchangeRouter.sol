// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";
import {
    TestBase_UniswapV2StandardExchange
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

contract TestBase_StandardExchangeRouter is TestBase_AerodromeStandardExchange, TestBase_UniswapV2StandardExchange {
    function setUp() public virtual override(TestBase_AerodromeStandardExchange, TestBase_UniswapV2StandardExchange) {
        TestBase_AerodromeStandardExchange.setUp();
        TestBase_UniswapV2StandardExchange.setUp();
    }
}
