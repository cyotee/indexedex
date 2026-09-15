// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {
    IUniswapV3StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserveV2.sol";
import {
    UniswapV3StandardExchangeLiquidReserveFacetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeLiquidReserveFacetV2.sol";
import {
    UniswapV3_Component_FactoryServiceV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3_Component_FactoryServiceV2.sol";

contract UniswapV3StandardExchangeLiquidReserveFacet_IFacet_TestV2 is CraneTest, TestBase_IFacet {
    using UniswapV3_Component_FactoryServiceV2 for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3StandardExchangeLiquidReserveFacetV2).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IUniswapV3StandardExchangeLiquidReserveV2).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](6);
        controlFuncs[0] = IUniswapV3StandardExchangeLiquidReserveV2.canOpenBoundPoolOps.selector;
        controlFuncs[1] = IUniswapV3StandardExchangeLiquidReserveV2.localReserve.selector;
        controlFuncs[2] = IUniswapV3StandardExchangeLiquidReserveV2.deployedReserve.selector;
        controlFuncs[3] = IUniswapV3StandardExchangeLiquidReserveV2.targetLiquidReservePercentage.selector;
        controlFuncs[4] = IUniswapV3StandardExchangeLiquidReserveV2.actualLiquidReservePercentage.selector;
        controlFuncs[5] = IUniswapV3StandardExchangeLiquidReserveV2.rebalanceLiquidReserve.selector;
    }
}
