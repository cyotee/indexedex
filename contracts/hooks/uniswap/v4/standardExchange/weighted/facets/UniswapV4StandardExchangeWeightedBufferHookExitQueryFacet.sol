// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol";

/// @notice Exit / withdraw liquidity surface (Option 1d size split from LiquidityFacet).
contract UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet is
    UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IDetfReserveQuote).interfaceId;
        interfaces[1] = type(IStandardizedYield).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](10);
        funcs[0] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportional.selector;
        funcs[1] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[2] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[3] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingle.selector;
        funcs[4] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[5] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitProportionalFlexible.selector;
        funcs[6] = IUniswapV4StandardExchangeWeightedBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[7] = IUniswapV4StandardExchangeWeightedBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[8] = IDetfReserveQuote.previewBurnToToken.selector;
        funcs[9] = IDetfReserveQuote.previewSynthetic.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
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
