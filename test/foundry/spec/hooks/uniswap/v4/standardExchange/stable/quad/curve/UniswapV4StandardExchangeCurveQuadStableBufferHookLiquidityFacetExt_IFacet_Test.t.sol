// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
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
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt.sol";

/// @notice D19 Ext: join/deposit preview selectors plus native SY.
contract UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt_IFacet_Test is
    CraneTest,
    TestBase_IFacet
{
    using UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployLiquidityFacetExt();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[0] = type(IDetfReserveQuote).interfaceId;
        controlInterfaces[1] = type(IStandardizedYield).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](11);
        controlFuncs[0] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        controlFuncs[1] = IStandardExchangeMultiAssetLiquidity.previewJoinUnbalanced.selector;
        controlFuncs[2] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        controlFuncs[3] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        controlFuncs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingle.selector;
        controlFuncs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportionalFlexible.selector;
        controlFuncs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        controlFuncs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingleFlexible.selector;
        controlFuncs[8] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        controlFuncs[9] = IDetfReserveQuote.previewSynthetic.selector;
        controlFuncs[10] = IDetfReserveQuote.previewJoinAfterDeposit.selector;
        controlFuncs = NativeStandardYieldSelectors._append(controlFuncs);
    }
}
