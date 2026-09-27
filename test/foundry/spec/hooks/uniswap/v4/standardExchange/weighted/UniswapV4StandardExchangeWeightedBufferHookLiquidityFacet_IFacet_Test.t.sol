// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet.sol";

/// @notice D19: mutating join/deposit selectors on LiquidityFacet.
contract UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet_IFacet_Test is
    CraneTest,
    TestBase_IFacet
{
    using UniswapV4StandardExchangeWeightedBufferHook_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployLiquidityFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](0);
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](5);
        controlFuncs[0] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector;
        controlFuncs[1] = bytes4(keccak256("joinUnbalanced(uint256[],address,uint256,uint256)"));
        controlFuncs[2] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactIn.selector;
        controlFuncs[3] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactOut.selector;
        controlFuncs[4] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector;
    }
}
