// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3StandardExchangeInFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInFacet.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract UniswapV3StandardExchangeInFacet_IFacet_Test is TestBase_UniswapV3StandardExchange {
    function test_facetMetadata_includesExchangeInAndCallbacks() public view {
        IFacet facet = uniswapV3StandardExchangeInFacet;
        assertEq(facet.facetName(), type(UniswapV3StandardExchangeInFacet).name);

        bytes4[] memory interfaces = facet.facetInterfaces();
        assertEq(interfaces.length, 3);
        assertEq(interfaces[0], type(IStandardExchangeIn).interfaceId);

        bytes4[] memory funcs = facet.facetFuncs();
        assertEq(funcs.length, 3);
        assertEq(funcs[0], IStandardExchangeIn.exchangeIn.selector);
        assertEq(funcs[1], IUniswapV3MintCallback.uniswapV3MintCallback.selector);
        assertEq(funcs[2], IUniswapV3SwapCallback.uniswapV3SwapCallback.selector);
    }
}
