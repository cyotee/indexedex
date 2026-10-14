// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookExitCore} from "./UniswapV4StandardExchangeWeightedBufferHookExitCore.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from "./UniswapV4StandardExchangeWeightedBufferHookRepo.sol";

abstract contract UniswapV4StandardExchangeWeightedBufferHookInQuoteBase is
    NativeStandardYieldQuoteBase, UniswapV4StandardExchangeWeightedBufferHookExitCore
{
    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256 amountOut)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            address pair = _liquiditySePair(tokenIn, tokenOut);
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            if (address(tokenOut) == address(this)) {
                return pair == address(0)
                    ? _entryPreviewJoinSingleAssetExactIn(address(tokenIn), amountIn)
                    : _entryPreviewJoinSingleAssetExactInFlexible(pair, amountIn, true);
            }
            return pair == address(0)
                ? _entryPreviewExitSingleAssetExactBptIn(address(tokenOut), amountIn)
                : _entryPreviewExitSingleAssetExactBptInFlexible(pair, amountIn, true);
        }
        (amountOut,) = ClaimLib.previewSwapExactInContext(address(tokenIn), address(tokenOut), amountIn, address(0));
    }

    function _liquiditySePair(IERC20 in_, IERC20 out_) internal view returns (address) {
        address edge_ = address(in_) == address(this) ? address(out_) : address(in_);
        Repo.Layout storage l_ = Repo._layout();
        for (uint256 i_; i_ < l_.numTokens; ++i_) {
            if (edge_ != address(0) && edge_ == l_.standardExchanges[i_]) return l_.tokens[i_];
        }
        return address(0);
    }
}
