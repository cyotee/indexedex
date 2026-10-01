// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol";
import {
    UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";

contract UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[0] = type(IStandardExchangeInMulti).interfaceId;
        controlInterfaces[1] = type(IStandardExchangeIn).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](2);
        controlFuncs[0] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector;
        controlFuncs[1] = IStandardExchangeIn.previewExchangeIn.selector;
    }
}
