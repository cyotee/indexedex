// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {UniswapV3FullSpreadStandardExchangeVaultInQueryFacet} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";

/// @notice V3-OWN-03: declaration coverage through the preserved release deployment entrypoint.
contract UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using Components for ICreate3FactoryProxy;
    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet();
    }
    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultInQueryFacet).name;
    }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](2);
        values[0] = type(IStandardExchangeIn).interfaceId;
        values[1] = type(IStandardExchangeStateQuote).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](4);
        values[0] = IStandardExchangeIn.previewExchangeIn.selector;
        values[1] = IStandardExchangeStateQuote.quoteExchangeState.selector;
        values[2] = IStandardExchangeStateQuote.quoteExchangeIn.selector;
        values[3] = IStandardExchangeStateQuote.quoteExchangeSupply.selector;
    }
}
