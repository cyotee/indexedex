// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

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
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet).name;
    }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IDetfReserveQuote).interfaceId;
        interfaces[1] = type(IStandardizedYield).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[1] = IStandardExchangeMultiAssetLiquidity.previewJoinUnbalanced.selector;
        funcs[2] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[3] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[4] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingle.selector;
        funcs[5] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinProportionalFlexible.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewDepositSingleFlexible.selector;
        funcs[8] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[9] = IDetfReserveQuote.previewSynthetic.selector;
        funcs[10] = this.previewJoinAfterDeposit.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
