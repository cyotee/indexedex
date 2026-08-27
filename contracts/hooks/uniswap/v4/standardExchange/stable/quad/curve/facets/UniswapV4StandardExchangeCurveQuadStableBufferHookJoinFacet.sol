// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
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
        funcs = new bytes4[](18);
        funcs[0] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[2] = IStandardExchangeMultiAssetLiquidity.previewJoinUnbalanced.selector;
        funcs[3] = IStandardExchangeMultiAssetLiquidity.joinUnbalanced.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingle.selector;
        funcs[9] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingle.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingleFlexible.selector;
        funcs[16] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[17] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
