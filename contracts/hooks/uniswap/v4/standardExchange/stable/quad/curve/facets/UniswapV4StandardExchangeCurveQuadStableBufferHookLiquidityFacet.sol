// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
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
        funcs = new bytes4[](35);
        funcs[0] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[2] = IStandardExchangeMultiAssetLiquidity.previewJoinUnbalanced.selector;
        funcs[3] = IStandardExchangeMultiAssetLiquidity.joinUnbalanced.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[9] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[10] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[12] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[13] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
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
        funcs[32] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[33] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
        funcs[34] = IDetfReserveQuote.previewBurnToToken.selector;
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
