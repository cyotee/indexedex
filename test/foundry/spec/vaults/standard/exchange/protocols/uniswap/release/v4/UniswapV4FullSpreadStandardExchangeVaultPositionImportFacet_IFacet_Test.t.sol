// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {
    IUniswapV4FullSpreadStandardExchangeVaultPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultInTarget.sol";
import {
    UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol";
import {
    UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol";

contract UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4FullSpreadStandardExchangeVaultPositionImportFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IUniswapV4FullSpreadStandardExchangeVaultPositionImport).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](1);
        controlFuncs[0] = IUniswapV4FullSpreadStandardExchangeVaultPositionImport.importPosition.selector;
    }
}
