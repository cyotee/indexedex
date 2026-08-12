// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";

/// @notice Preview-only exchangeOut surface (Option 1b).
abstract contract UniswapV4StandardExchangeOutQueryTarget is UniswapV4StandardExchangeOutBase {
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
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
            return _quoteSwapOut(amountOut, address(tokenIn) == token0);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(address(tokenOut), amountOut);
        }

        revert ExchangeOutNotAvailable();
    }
}
