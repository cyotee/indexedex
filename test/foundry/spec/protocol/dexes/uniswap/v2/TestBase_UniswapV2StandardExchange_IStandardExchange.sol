// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {TestBase_Aerodrome} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {
    TestBase_UniswapV2_Pools
} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2_Pools.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    TestBase_UniswapV2StandardExchange
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

contract TestBase_UniswapV2StandardExchange_IStandardExchange is
    TestBase_UniswapV2_Pools,
    TestBase_UniswapV2StandardExchange
{
    function setUp() public virtual override(TestBase_UniswapV2_Pools, TestBase_UniswapV2StandardExchange) {
        TestBase_UniswapV2_Pools.setUp();
        TestBase_UniswapV2StandardExchange.setUp();
    }
}
