// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";

/// @notice V3-OWN-03: declaration coverage through the preserved release deployment entrypoint.
contract UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using Components for ICreate3FactoryProxy;
    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet();
    }
    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet).name;
    }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](1);
        values[0] = type(IStandardExchangeOut).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](1);
        values[0] = IStandardExchangeOut.previewExchangeOut.selector;
    }
}
