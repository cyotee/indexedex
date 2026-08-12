// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet).name;
    }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](16);
        funcs[0] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinUnbalanced.selector;
        funcs[3] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinUnbalanced.selector;
        funcs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingle.selector;
        funcs[9] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingle.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingleFlexible.selector;
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
