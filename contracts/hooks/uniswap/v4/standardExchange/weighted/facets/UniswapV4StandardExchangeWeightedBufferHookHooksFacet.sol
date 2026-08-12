// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol";

contract UniswapV4StandardExchangeWeightedBufferHookHooksFacet is
    UniswapV4StandardExchangeWeightedBufferHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangeWeightedBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](39);
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
        funcs[10] = IUniswapV4StandardExchangeWeightedBufferHook.poolManager.selector;
        funcs[11] = IUniswapV4StandardExchangeWeightedBufferHook.feeOracle.selector;
        funcs[12] = IUniswapV4StandardExchangeWeightedBufferHook.permit2.selector;
        funcs[13] = IUniswapV4StandardExchangeWeightedBufferHook.numTokens.selector;
        funcs[14] = IUniswapV4StandardExchangeWeightedBufferHook.tokens.selector;
        funcs[15] = IUniswapV4StandardExchangeWeightedBufferHook.token.selector;
        funcs[16] = IUniswapV4StandardExchangeWeightedBufferHook.getNormalizedWeights.selector;
        funcs[17] = IUniswapV4StandardExchangeWeightedBufferHook.weight.selector;
        funcs[18] = IUniswapV4StandardExchangeWeightedBufferHook.standardExchange.selector;
        funcs[19] = IUniswapV4StandardExchangeWeightedBufferHook.rateProvider.selector;
        funcs[20] = IUniswapV4StandardExchangeWeightedBufferHook.isBuffered.selector;
        funcs[21] = IUniswapV4StandardExchangeWeightedBufferHook.nativeReserve.selector;
        funcs[22] = IUniswapV4StandardExchangeWeightedBufferHook.nativeReserves.selector;
        funcs[23] = IUniswapV4StandardExchangeWeightedBufferHook.ratedBalance.selector;
        funcs[24] = IUniswapV4StandardExchangeWeightedBufferHook.ratedBalances.selector;
        funcs[25] = IUniswapV4StandardExchangeWeightedBufferHook.seBalance.selector;
        funcs[26] = IUniswapV4StandardExchangeWeightedBufferHook.seClaim.selector;
        funcs[27] = IUniswapV4StandardExchangeWeightedBufferHook.invScale.selector;
        funcs[28] = IUniswapV4StandardExchangeWeightedBufferHook.ratedScale.selector;
        funcs[29] = IUniswapV4StandardExchangeWeightedBufferHook.dexSwapFee.selector;
        funcs[30] = IUniswapV4StandardExchangeWeightedBufferHook.usageFee.selector;
        funcs[31] = IUniswapV4StandardExchangeWeightedBufferHook.feeTo.selector;
        funcs[32] = IUniswapV4StandardExchangeWeightedBufferHook.kLast.selector;
        funcs[33] = IUniswapV4StandardExchangeWeightedBufferHook.kLastMode.selector;
        funcs[34] = IUniswapV4StandardExchangeWeightedBufferHook.isFullBook.selector;
        funcs[35] = IUniswapV4StandardExchangeWeightedBufferHook.ensurePairPools.selector;
        funcs[36] = IUniswapV4StandardExchangeWeightedBufferHook.pairDoorCount.selector;
        funcs[37] = IUniswapV4StandardExchangeWeightedBufferHook.previewSwapExactIn.selector;
        funcs[38] = IUniswapV4StandardExchangeWeightedBufferHook.previewSwapExactOut.selector;
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
