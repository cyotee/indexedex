// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol";
import {
    TestBase_UniswapV3FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet_IFacet_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault, TestBase_IFacet {
    function setUp() public override(TestBase_UniswapV3FullSpreadStandardExchangeVault, TestBase_IFacet) {
        TestBase_UniswapV3FullSpreadStandardExchangeVault.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public view override returns (IFacet) { return uniswapV3StandardExchangePositionImportFacet; }
    function controlFacetName() public pure override returns (string memory) { return type(UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet).name; }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](1);
        values[0] = type(IUniswapV3FullSpreadStandardExchangeVaultPositionImport).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](2);
        values[0] = IUniswapV3FullSpreadStandardExchangeVaultPositionImport.previewImportPosition.selector;
        values[1] = IUniswapV3FullSpreadStandardExchangeVaultPositionImport.importPosition.selector;
    }
}
