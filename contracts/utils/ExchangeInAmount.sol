// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/// @notice Reads `amountOut` from the widened exchange-in tuple. The refund word is not output.
library ExchangeInAmount {
    function previewOut(IStandardExchangeIn exchange_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        (amountOut_,) = exchange_.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }

    function exchangeOut(
        IStandardExchangeIn exchange_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        (amountOut_,) = exchange_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_
        );
    }
}
