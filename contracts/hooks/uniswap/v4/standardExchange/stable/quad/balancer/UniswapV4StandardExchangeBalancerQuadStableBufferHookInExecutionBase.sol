// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol";

abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookInExecutionBase is
    UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore, UniswapV4BufferHookLiquidityExecutionBase
{
    function _joinLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address)
        internal override returns (uint256)
    {
        return _entryJoinSingleAssetExactIn(token_, amount_, receiver_, minimum_, deadline_);
    }
    function _exitLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address)
        internal override returns (uint256)
    {
        return _entryExitSingleAssetExactBptIn(token_, amount_, receiver_, minimum_, deadline_);
    }
}
