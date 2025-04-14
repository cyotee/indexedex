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
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

contract TestBase_AerodromeStandardExchange_IStandardExchange is
    TestBase_Aerodrome_Pools,
    TestBase_AerodromeStandardExchange
{
    function setUp() public virtual override(TestBase_Aerodrome_Pools, TestBase_AerodromeStandardExchange) {
        TestBase_AerodromeStandardExchange.setUp();
        TestBase_Aerodrome_Pools.setUp();
    }
}
