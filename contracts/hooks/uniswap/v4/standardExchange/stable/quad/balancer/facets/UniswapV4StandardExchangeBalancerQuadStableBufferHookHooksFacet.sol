// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget.sol";

contract UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangeBalancerQuadStableBufferHook).interfaceId;
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
        funcs[10] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.poolManager.selector;
        funcs[11] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.feeOracle.selector;
        funcs[12] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.permit2.selector;
        funcs[13] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.numTokens.selector;
        funcs[14] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.tokens.selector;
        funcs[15] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.token.selector;
        funcs[16] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.baseAmp.selector;
        funcs[17] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.getCurrentAmp.selector;
        funcs[18] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.standardExchange.selector;
        funcs[19] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.rateProvider.selector;
        funcs[20] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.isBuffered.selector;
        funcs[21] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.nativeReserve.selector;
        funcs[22] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.nativeReserves.selector;
        funcs[23] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ratedBalance.selector;
        funcs[24] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ratedBalances.selector;
        funcs[25] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.seBalance.selector;
        funcs[26] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.seClaim.selector;
        funcs[27] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.invScale.selector;
        funcs[28] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ratedScale.selector;
        funcs[29] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.dexSwapFee.selector;
        funcs[30] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.usageFee.selector;
        funcs[31] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.feeTo.selector;
        funcs[32] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.kLast.selector;
        funcs[33] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.isFullBook.selector;
        funcs[34] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ensurePairPools.selector;
        funcs[35] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.pairDoorCount.selector;
        funcs[36] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewSwapExactIn.selector;
        funcs[37] = IUniswapV4StandardExchangeBalancerQuadStableBufferHook.previewSwapExactOut.selector;
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
