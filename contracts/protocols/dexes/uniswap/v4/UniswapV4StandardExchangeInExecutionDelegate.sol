// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";

contract UniswapV4StandardExchangeInExecutionDelegate is UniswapV4StandardExchangeInBase {
    address private immutable SELF = address(this);
    error DelegateCallRequired();

    /// @dev Not installed on the diamond. The SY entrypoint validates and names its holder before delegation.
    function executeNamedHolderRedemption(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient, address holder)
        external returns (uint256)
    {
        if (address(this) == SELF) revert DelegateCallRequired();
        return _executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient, holder);
    }

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
        // Shares were already pulled onto the vault. The wrapper names that holder.
        // An external holder argument would let a caller burn someone else.
        return _executeZapOutExactIn(tokenOut, sharesBurned, minAmountOut, recipient, address(this));
    }
}
