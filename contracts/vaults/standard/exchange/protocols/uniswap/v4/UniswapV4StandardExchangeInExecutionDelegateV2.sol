// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeInBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInBaseV2.sol";

contract UniswapV4StandardExchangeInExecutionDelegateV2 is UniswapV4StandardExchangeInBaseV2 {
    function executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        external
        returns (uint256 sharesOut)
    {
        return _executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient);
    }

    function executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        external
        returns (uint256 amountOut)
    {
        return _executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient);
    }
}
