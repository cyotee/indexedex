// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookExitTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol";

/// @notice Exit / withdraw liquidity surface (Option 1d size split from LiquidityFacet).
contract UniswapV4StandardExchangeWeightedBufferHookExitFacet is
    UniswapV4StandardExchangeWeightedBufferHookExitTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookExitFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IDetfReserveQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](17);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector;
        funcs[2] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[3] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[5] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[6] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingle.selector;
        funcs[7] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingle.selector;
        funcs[8] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[9] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingleExactOut.selector;
        funcs[10] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeWeightedBufferHook.exitProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeWeightedBufferHook.exitSingleAssetExactBptInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeWeightedBufferHook.withdrawSingleFlexible.selector;
        funcs[16] = IDetfReserveQuote.previewBurnToToken.selector;
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
