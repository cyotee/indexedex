// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4FullSpreadPonsFamilyHookInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInBase.sol";

contract UniswapV4FullSpreadPonsFamilyHookInExecutionDelegate is UniswapV4FullSpreadPonsFamilyHookInBase {
    address private immutable SELF = address(this);

    function executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        external
        returns (uint256 sharesOut)
    {
        if (address(this) == SELF) revert AccountingMismatch();
        return _executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient);
    }

    function executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        external
        returns (uint256 amountOut)
    {
        if (address(this) == SELF) revert AccountingMismatch();
        return _executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient);
    }
}
