// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet.sol";

/// @notice D19: mutating join/deposit selectors on LiquidityFacet.
contract UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet_IFacet_Test is
    CraneTest,
    TestBase_IFacet
{
    using UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployLiquidityFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](0);
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](9);
        controlFuncs[0] = IUniswapV4SeBufferHook.joinProportional.selector;
        controlFuncs[1] = IStandardExchangeMultiAssetLiquidity.joinUnbalanced.selector;
        controlFuncs[2] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        controlFuncs[3] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        controlFuncs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingle.selector;
        controlFuncs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportionalFlexible.selector;
        controlFuncs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactInFlexible.selector;
        controlFuncs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingleFlexible.selector;
        controlFuncs[8] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
    }
}
