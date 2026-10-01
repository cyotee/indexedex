// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionDelegate is UniswapV4FullSpreadHooklessStandardExchangeVaultInBase {
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
