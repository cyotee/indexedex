// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4StandardExchangeOutQueryFacetV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutQueryFacetV2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOutFacetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutFacetV2.sol";
import {
    UniswapV4_Component_FactoryServiceV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4_Component_FactoryServiceV2.sol";

contract UniswapV4StandardExchangeOutFacet_IFacet_TestV2 is CraneTest, TestBase_IFacet {
    using UniswapV4_Component_FactoryServiceV2 for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4StandardExchangeOutFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeOutFacetV2).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        // Option 1b: preview lives on OutQueryFacet; execute-only here.
        controlFuncs = new bytes4[](1);
        controlFuncs[0] = IStandardExchangeOut.exchangeOut.selector;
    }
}

contract UniswapV4StandardExchangeOutQueryFacet_IFacet_TestV2 is CraneTest, TestBase_IFacet {
    using UniswapV4_Component_FactoryServiceV2 for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeOutQueryFacetV2).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](0);
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        // Independent expected surface: exact-output preview plus inventory snapshot.
        controlFuncs = new bytes4[](2);
        controlFuncs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        controlFuncs[1] = IStandardExchangeTransitionQuote.quoteState.selector;
    }
}
