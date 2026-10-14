// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV3FullSpreadStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol";

contract UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate is UniswapV3FullSpreadStandardExchangeVaultInBase {
    address private immutable SELF = address(this);
    error DelegateCallRequired();
    function executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        external
        returns (uint256 sharesOut)
    {
        if (address(this) == SELF) revert DelegateCallRequired();
        return _executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient);
    }

    function executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        external
        returns (uint256 amountOut)
    {
        if (address(this) == SELF) revert DelegateCallRequired();
        // Shares were already pulled onto the vault. The wrapper names that holder.
        return _executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient, address(this));
    }
}
