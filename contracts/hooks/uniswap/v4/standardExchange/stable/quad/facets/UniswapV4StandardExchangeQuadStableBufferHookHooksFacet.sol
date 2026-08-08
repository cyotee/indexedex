// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookHooksTarget.sol";

contract UniswapV4StandardExchangeQuadStableBufferHookHooksFacet is
    UniswapV4StandardExchangeQuadStableBufferHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeQuadStableBufferHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangeQuadStableBufferHook).interfaceId;
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
        funcs[10] = IUniswapV4StandardExchangeQuadStableBufferHook.poolManager.selector;
        funcs[11] = IUniswapV4StandardExchangeQuadStableBufferHook.feeOracle.selector;
        funcs[12] = IUniswapV4StandardExchangeQuadStableBufferHook.permit2.selector;
        funcs[13] = IUniswapV4StandardExchangeQuadStableBufferHook.numTokens.selector;
        funcs[14] = IUniswapV4StandardExchangeQuadStableBufferHook.tokens.selector;
        funcs[15] = IUniswapV4StandardExchangeQuadStableBufferHook.token.selector;
        funcs[16] = IUniswapV4StandardExchangeQuadStableBufferHook.baseAmp.selector;
        funcs[17] = IUniswapV4StandardExchangeQuadStableBufferHook.getCurrentAmp.selector;
        funcs[18] = IUniswapV4StandardExchangeQuadStableBufferHook.standardExchange.selector;
        funcs[19] = IUniswapV4StandardExchangeQuadStableBufferHook.rateProvider.selector;
        funcs[20] = IUniswapV4StandardExchangeQuadStableBufferHook.isBuffered.selector;
        funcs[21] = IUniswapV4StandardExchangeQuadStableBufferHook.nativeReserve.selector;
        funcs[22] = IUniswapV4StandardExchangeQuadStableBufferHook.nativeReserves.selector;
        funcs[23] = IUniswapV4StandardExchangeQuadStableBufferHook.ratedBalance.selector;
        funcs[24] = IUniswapV4StandardExchangeQuadStableBufferHook.ratedBalances.selector;
        funcs[25] = IUniswapV4StandardExchangeQuadStableBufferHook.seBalance.selector;
        funcs[26] = IUniswapV4StandardExchangeQuadStableBufferHook.seClaim.selector;
        funcs[27] = IUniswapV4StandardExchangeQuadStableBufferHook.invScale.selector;
        funcs[28] = IUniswapV4StandardExchangeQuadStableBufferHook.ratedScale.selector;
        funcs[29] = IUniswapV4StandardExchangeQuadStableBufferHook.dexSwapFee.selector;
        funcs[30] = IUniswapV4StandardExchangeQuadStableBufferHook.usageFee.selector;
        funcs[31] = IUniswapV4StandardExchangeQuadStableBufferHook.feeTo.selector;
        funcs[32] = IUniswapV4StandardExchangeQuadStableBufferHook.kLast.selector;
        funcs[33] = IUniswapV4StandardExchangeQuadStableBufferHook.isFullBook.selector;
        funcs[34] = IUniswapV4StandardExchangeQuadStableBufferHook.ensurePairPools.selector;
        funcs[35] = IUniswapV4StandardExchangeQuadStableBufferHook.pairDoorCount.selector;
        funcs[36] = IUniswapV4StandardExchangeQuadStableBufferHook.previewSwapExactIn.selector;
        funcs[37] = IUniswapV4StandardExchangeQuadStableBufferHook.previewSwapExactOut.selector;
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
