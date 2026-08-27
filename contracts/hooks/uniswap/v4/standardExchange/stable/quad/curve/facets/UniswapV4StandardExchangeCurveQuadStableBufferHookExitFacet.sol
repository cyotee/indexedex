// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet).name;
    }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](17);
        funcs[0] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[1] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[2] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[3] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[5] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingle.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingle.selector;
        funcs[8] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[9] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleExactOut.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitSingleAssetExactBptInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleFlexible.selector;
        funcs[16] = IDetfReserveQuote.previewBurnToToken.selector;
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
