// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol";

contract UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet is
    UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeWeightedBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](20);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinUnbalanced.selector;
        funcs[3] = IUniswapV4StandardExchangeWeightedBufferHook.joinUnbalanced.selector;
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactIn.selector;
        funcs[6] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[7] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportional.selector;
        funcs[9] = IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector;
        funcs[10] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[11] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[12] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[13] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[14] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingle.selector;
        funcs[15] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector;
        funcs[16] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingle.selector;
        funcs[17] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingle.selector;
        funcs[18] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[19] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingleExactOut.selector;
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
