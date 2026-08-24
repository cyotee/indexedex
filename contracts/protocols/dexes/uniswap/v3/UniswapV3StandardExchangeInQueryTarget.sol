// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInBase.sol";

/**
 * @title UniswapV3StandardExchangeInQueryTarget
 * @notice View-only exchange-in previews (size split from mutate facet). D24: no rebalance simulation.
 */
abstract contract UniswapV3StandardExchangeInQueryTarget is UniswapV3StandardExchangeInBase {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            if (!canOpenBoundPoolOps()) {
                revert UniswapV3Exchange_BoundPoolInteractionBlocked();
            }
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(address(tokenIn), amountIn);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutExactIn(address(tokenOut), amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }
}
