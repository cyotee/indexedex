// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt.sol";

/// @notice D19 Ext: join/deposit preview selectors.
contract UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt_IFacet_Test is
    CraneTest,
    TestBase_IFacet
{
    using UniswapV4StandardExchangeWeightedBufferHook_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployLiquidityFacetExt();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookLiquidityFacetExt).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](0);
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](10);
        controlFuncs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportional.selector;
        controlFuncs[1] = bytes4(keccak256("previewJoinUnbalanced(uint256[])"));
        controlFuncs[2] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactIn.selector;
        controlFuncs[3] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactOut.selector;
        controlFuncs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingle.selector;
        controlFuncs[5] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportionalFlexible.selector;
        controlFuncs[6] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        controlFuncs[7] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingleFlexible.selector;
        controlFuncs[8] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        controlFuncs[9] = IDetfReserveQuote.previewJoinAfterDeposit.selector;
    }
}
