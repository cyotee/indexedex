// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";

contract UniswapV4StandardExchangeInExecutionDelegate is UniswapV4StandardExchangeInBase {
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
