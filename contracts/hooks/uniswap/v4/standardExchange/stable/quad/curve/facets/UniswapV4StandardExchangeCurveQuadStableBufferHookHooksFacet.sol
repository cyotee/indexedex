// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangeCurveQuadStableBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](38);
        funcs[0] = IHooks.beforeInitialize.selector;
        funcs[1] = IHooks.afterInitialize.selector;
        funcs[2] = IHooks.beforeAddLiquidity.selector;
        funcs[3] = IHooks.afterAddLiquidity.selector;
        funcs[4] = IHooks.beforeRemoveLiquidity.selector;
        funcs[5] = IHooks.afterRemoveLiquidity.selector;
        funcs[6] = IHooks.beforeSwap.selector;
        funcs[7] = IHooks.afterSwap.selector;
        funcs[8] = IHooks.beforeDonate.selector;
        funcs[9] = IHooks.afterDonate.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.poolManager.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.feeOracle.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.permit2.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.numTokens.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.tokens.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.token.selector;
        funcs[16] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.baseAmp.selector;
        funcs[17] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.getCurrentAmp.selector;
        funcs[18] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.standardExchange.selector;
        funcs[19] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.rateProvider.selector;
        funcs[20] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.isBuffered.selector;
        funcs[21] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.nativeReserve.selector;
        funcs[22] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.nativeReserves.selector;
        funcs[23] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.ratedBalance.selector;
        funcs[24] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.ratedBalances.selector;
        funcs[25] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.seBalance.selector;
        funcs[26] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.seClaim.selector;
        funcs[27] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.invScale.selector;
        funcs[28] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.ratedScale.selector;
        funcs[29] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.dexSwapFee.selector;
        funcs[30] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.usageFee.selector;
        funcs[31] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.feeTo.selector;
        funcs[32] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.kLast.selector;
        funcs[33] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.isFullBook.selector;
        funcs[34] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.ensurePairPools.selector;
        funcs[35] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.pairDoorCount.selector;
        funcs[36] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewSwapExactIn.selector;
        funcs[37] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewSwapExactOut.selector;
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
