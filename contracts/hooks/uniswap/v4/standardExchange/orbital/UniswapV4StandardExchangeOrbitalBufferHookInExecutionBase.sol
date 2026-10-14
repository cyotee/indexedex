// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositCore} from "./UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol";

abstract contract UniswapV4StandardExchangeOrbitalBufferHookInExecutionBase is
    UniswapV4StandardExchangeOrbitalBufferHookDepositCore, UniswapV4BufferHookLiquidityExecutionBase
{
    function _joinLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address)
        internal override returns (uint256)
    {
        return _entryJoinSingleAssetExactIn(token_, amount_, receiver_, minimum_, deadline_);
    }
    function _exitLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address)
        internal override onlyLiquidityRemover nonReentrant returns (uint256)
    {
        return _exitLiquidityFrom(msg.sender, token_, amount_, receiver_, minimum_, deadline_);
    }
    function _exitLiquidityFrom(address holder, address tokenOut, uint256 shares, address to, uint256 minimum, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        amountOut = _exitSingleAssetFrom(holder, tokenOut, shares, to, deadline);
        if (amountOut < minimum) revert InsufficientTokenOut();
    }
}
