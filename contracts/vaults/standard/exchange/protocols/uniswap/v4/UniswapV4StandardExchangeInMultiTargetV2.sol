// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInBaseV2.sol";

contract UniswapV4StandardExchangeInMultiTargetV2 is UniswapV4StandardExchangeInBaseV2 {
    function exchangeInManyToOne(
        address[] calldata tokenIn,
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant inputOperation returns (uint256 amountOut) {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
        if (address(tokenOut) != address(this) || !_isDualPoolCurrencies(tokenIn) || !_dualAmountsPositive(amountsIn)) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }

        uint256 actual0 = _secureTokenTransfer(IERC20(tokenIn[0]), amountsIn[0], pretransferred);
        uint256 actual1 = _secureTokenTransfer(IERC20(tokenIn[1]), amountsIn[1], pretransferred);
        amountOut = _executeZapInDualDeposit(actual0, actual1, minAmountOut, recipient);
        _pokeBoundPoolTwap();
    }
}
