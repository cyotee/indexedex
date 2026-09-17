// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4FullSpreadStandardExchangeVaultOutFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol";
import {
    UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";

contract UniswapV4FullSpreadStandardExchangeVaultOutFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultOutFacet).name;
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

contract UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultOutQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet).name;
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
