// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet.sol";
import {
    UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";

contract UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](6);
        controlFuncs[0] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.canOpenBoundPoolOps.selector;
        controlFuncs[1] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.localReserve.selector;
        controlFuncs[2] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.deployedReserve.selector;
        controlFuncs[3] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.targetLiquidReservePercentage.selector;
        controlFuncs[4] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.actualLiquidReservePercentage.selector;
        controlFuncs[5] = IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.rebalanceLiquidReserve.selector;
    }
}
