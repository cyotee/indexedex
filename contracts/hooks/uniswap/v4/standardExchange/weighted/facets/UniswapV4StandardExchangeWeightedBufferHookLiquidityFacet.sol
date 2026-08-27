// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
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
        funcs = new bytes4[](35);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector;
        funcs[2] = bytes4(keccak256("previewJoinUnbalanced(uint256[])"));
        funcs[3] = bytes4(keccak256("joinUnbalanced(uint256[],address,uint256,uint256)"));
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
        // B6 flexible SE-share LP
        funcs[20] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinProportionalFlexible.selector;
        funcs[21] = IUniswapV4StandardExchangeWeightedBufferHook.joinProportionalFlexible.selector;
        funcs[22] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportionalFlexible.selector;
        funcs[23] = IUniswapV4StandardExchangeWeightedBufferHook.exitProportionalFlexible.selector;
        funcs[24] = IUniswapV4StandardExchangeWeightedBufferHook.previewJoinSingleAssetExactInFlexible.selector;
        funcs[25] = IUniswapV4StandardExchangeWeightedBufferHook.joinSingleAssetExactInFlexible.selector;
        funcs[26] = IUniswapV4StandardExchangeWeightedBufferHook.previewDepositSingleFlexible.selector;
        funcs[27] = IUniswapV4StandardExchangeWeightedBufferHook.depositSingleFlexible.selector;
        funcs[28] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[29] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactBptInFlexible.selector;
        funcs[30] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[31] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingleFlexible.selector;
        funcs[32] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[33] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
        funcs[34] = IDetfReserveQuote.previewBurnToToken.selector;
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
