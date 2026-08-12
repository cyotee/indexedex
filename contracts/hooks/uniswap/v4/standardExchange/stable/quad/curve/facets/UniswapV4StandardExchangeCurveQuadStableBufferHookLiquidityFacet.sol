// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeCurveQuadStableBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](32);
        funcs[0] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinUnbalanced.selector;
        funcs[3] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinUnbalanced.selector;
        funcs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitProportional.selector;
        funcs[9] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitProportional.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingle.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingle.selector;
        funcs[16] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingle.selector;
        funcs[17] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingle.selector;
        funcs[18] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[19] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleExactOut.selector;
        // B6 flexible SE-share LP
        funcs[20] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportionalFlexible.selector;
        funcs[21] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportionalFlexible.selector;
        funcs[22] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitProportionalFlexible.selector;
        funcs[23] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitProportionalFlexible.selector;
        funcs[24] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[25] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[26] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingleFlexible.selector;
        funcs[27] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingleFlexible.selector;
        funcs[28] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[29] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitSingleAssetExactBptInFlexible.selector;
        funcs[30] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[31] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleFlexible.selector;
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
