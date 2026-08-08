// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookLiquidityTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookLiquidityTarget.sol";

contract UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet is
    UniswapV4StandardExchangeQuadStableBufferHookLiquidityTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeQuadStableBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](20);
        funcs[0] = IUniswapV4StandardExchangeQuadStableBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeQuadStableBufferHook.joinProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeQuadStableBufferHook.previewJoinUnbalanced.selector;
        funcs[3] = IUniswapV4StandardExchangeQuadStableBufferHook.joinUnbalanced.selector;
        funcs[4] = IUniswapV4StandardExchangeQuadStableBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeQuadStableBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeQuadStableBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeQuadStableBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeQuadStableBufferHook.previewExitProportional.selector;
        funcs[9] = IUniswapV4StandardExchangeQuadStableBufferHook.exitProportional.selector;
        funcs[10] = IUniswapV4StandardExchangeQuadStableBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IUniswapV4StandardExchangeQuadStableBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[12] = IUniswapV4StandardExchangeQuadStableBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[13] = IUniswapV4StandardExchangeQuadStableBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[14] = IUniswapV4StandardExchangeQuadStableBufferHook.previewDepositSingle.selector;
        funcs[15] = IUniswapV4StandardExchangeQuadStableBufferHook.depositSingle.selector;
        funcs[16] = IUniswapV4StandardExchangeQuadStableBufferHook.previewWithdrawSingle.selector;
        funcs[17] = IUniswapV4StandardExchangeQuadStableBufferHook.withdrawSingle.selector;
        funcs[18] = IUniswapV4StandardExchangeQuadStableBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[19] = IUniswapV4StandardExchangeQuadStableBufferHook.withdrawSingleExactOut.selector;
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
