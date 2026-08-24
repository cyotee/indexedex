// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeLiquidReserveFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeLiquidReserveFacet.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";

contract UniswapV3StandardExchangeLiquidReserveFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3StandardExchangeLiquidReserveFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IUniswapV3StandardExchangeLiquidReserve).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](6);
        controlFuncs[0] = IUniswapV3StandardExchangeLiquidReserve.canOpenBoundPoolOps.selector;
        controlFuncs[1] = IUniswapV3StandardExchangeLiquidReserve.localReserve.selector;
        controlFuncs[2] = IUniswapV3StandardExchangeLiquidReserve.deployedReserve.selector;
        controlFuncs[3] = IUniswapV3StandardExchangeLiquidReserve.targetLiquidReservePercentage.selector;
        controlFuncs[4] = IUniswapV3StandardExchangeLiquidReserve.actualLiquidReservePercentage.selector;
        controlFuncs[5] = IUniswapV3StandardExchangeLiquidReserve.rebalanceLiquidReserve.selector;
    }
}
