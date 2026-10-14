// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase} from "./UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookInExecutionBase is
    UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase, UniswapV4BufferHookLiquidityExecutionBase
{
    function _joinLiquidityExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline, address)
        internal override nonReentrant returns (uint256)
    {
        if (!_isLive()) revert NotLive();
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        _pullErc20Single(tokenIn, amountIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair = Repo._layout().legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = _unwrap(tokenIn, pair, amountIn);
            return _depositSingle(pair, pairOut, to, sharesMin, deadline);
        }
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }
    function _exitLiquidityExactIn(address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline, address)
        internal override nonReentrant returns (uint256)
    {
        return _exitLiquidityFrom(msg.sender, tokenOut, sharesIn, to, amountOutMin, deadline);
    }
    function _exitLiquidityFrom(address holder, address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        amountOut = _exitSingleAssetFrom(holder, tokenOut, sharesIn, to, deadline);
        if (amountOut < amountOutMin) revert InsufficientTokenOut();
    }
}
