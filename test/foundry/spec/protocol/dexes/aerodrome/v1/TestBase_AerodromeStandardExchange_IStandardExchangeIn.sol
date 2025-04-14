// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {TestBase_Aerodrome} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {
    TestBase_Aerodrome_Pools
} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome_Pools.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    TestBase_AerodromeStandardExchange_IStandardExchange
} from "test/foundry/spec/protocol/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange_IStandardExchange.sol";

contract TestBase_AerodromeStandardExchange_IStandardExchangeIn is
    TestBase_AerodromeStandardExchange_IStandardExchange
{
    function setUp() public virtual override(TestBase_AerodromeStandardExchange_IStandardExchange) {
        TestBase_AerodromeStandardExchange_IStandardExchange.setUp();
        IndexedexTest.setUp();
    }
}
