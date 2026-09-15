// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInBaseV2.sol";

contract UniswapV4StandardExchangeInMultiQueryTargetV2 is UniswapV4StandardExchangeInBaseV2 {
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
            if (!canOpenPoolManagerUnlock()) {
                revert UniswapV4Exchange_PoolManagerInteractionBlocked();
            }
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

    function previewExchangeInManyToOne(address[] calldata tokenIn, uint256[] calldata amountsIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (address(tokenOut) != address(this) || !_isDualPoolCurrencies(tokenIn) || !_dualAmountsPositive(amountsIn)) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }
        return _previewZapInDualDeposit(amountsIn[0], amountsIn[1]);
    }
}
