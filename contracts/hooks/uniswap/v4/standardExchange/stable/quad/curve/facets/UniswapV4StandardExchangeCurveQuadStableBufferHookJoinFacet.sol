// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4SeBufferHookClaimQuote, IUniswapV4SeBufferHookClaimExitQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

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
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](9);
        funcs[0] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[1] = IStandardExchangeMultiAssetLiquidity.joinUnbalanced.selector;
        funcs[2] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[3] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingle.selector;
        funcs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinProportionalFlexible.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.depositSingleFlexible.selector;
        funcs[8] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
