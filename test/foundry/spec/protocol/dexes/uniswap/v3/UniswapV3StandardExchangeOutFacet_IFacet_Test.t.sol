// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutFacet.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract UniswapV3StandardExchangeOutFacet_IFacet_Test is TestBase_UniswapV3StandardExchange {
    function test_facetMetadata_includesExchangeOut() public view {
        IFacet facet = uniswapV3StandardExchangeOutFacet;
        assertEq(facet.facetName(), type(UniswapV3StandardExchangeOutFacet).name);

        bytes4[] memory interfaces = facet.facetInterfaces();
        assertEq(interfaces.length, 1);
        assertEq(interfaces[0], type(IStandardExchangeOut).interfaceId);

        bytes4[] memory funcs = facet.facetFuncs();
        assertEq(funcs.length, 2);
        assertEq(funcs[0], IStandardExchangeOut.previewExchangeOut.selector);
        assertEq(funcs[1], IStandardExchangeOut.exchangeOut.selector);
    }
}
