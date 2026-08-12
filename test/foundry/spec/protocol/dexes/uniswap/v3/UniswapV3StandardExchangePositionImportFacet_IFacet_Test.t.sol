// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    UniswapV3StandardExchangePositionImportFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportFacet.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract UniswapV3StandardExchangePositionImportFacet_IFacet_Test is TestBase_UniswapV3StandardExchange {
    function test_facetMetadata_includesImportPreviewAndMutate() public view {
        IFacet facet = uniswapV3StandardExchangePositionImportFacet;
        assertEq(facet.facetName(), type(UniswapV3StandardExchangePositionImportFacet).name);

        bytes4[] memory interfaces = facet.facetInterfaces();
        assertEq(interfaces.length, 1);
        assertEq(interfaces[0], type(IUniswapV3StandardExchangePositionImport).interfaceId);

        bytes4[] memory funcs = facet.facetFuncs();
        assertEq(funcs.length, 2);
        assertEq(funcs[0], IUniswapV3StandardExchangePositionImport.previewImportPosition.selector);
        assertEq(funcs[1], IUniswapV3StandardExchangePositionImport.importPosition.selector);
    }
}
