// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeBalancerQuadStableBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](20);
        funcs[0] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewJoinUnbalanced.selector;
        funcs[3] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinUnbalanced.selector;
        funcs[4] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewExitProportional.selector;
        funcs[9] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.exitProportional.selector;
        funcs[10] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[12] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[13] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[14] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewDepositSingle.selector;
        funcs[15] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.depositSingle.selector;
        funcs[16] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewWithdrawSingle.selector;
        funcs[17] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.withdrawSingle.selector;
        funcs[18] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[19] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.withdrawSingleExactOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
