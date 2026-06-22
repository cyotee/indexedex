// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4StandardExchangeInBase} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";

contract UniswapV4StandardExchangeInQueryTarget is UniswapV4StandardExchangeInBase {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        address token0 = _token0();
        address token1 = _token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwapIn(amountIn, address(tokenIn) == token0);
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