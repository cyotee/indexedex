// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4StandardExchangeWeightedBufferHookInQuoteBase} from "./UniswapV4StandardExchangeWeightedBufferHookInQuoteBase.sol";

abstract contract UniswapV4StandardExchangeWeightedBufferHookInExecutionBase is
    UniswapV4StandardExchangeWeightedBufferHookInQuoteBase, UniswapV4BufferHookLiquidityExecutionBase
{
    function _liquidityExecutionEdge(IERC20 in_, IERC20 out_) internal view override returns (address) {
        return _liquiditySePair(in_, out_);
    }
    function _joinLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address edge_)
        internal override returns (uint256)
    {
        return edge_ == address(0)
            ? _entryJoinSingleAssetExactIn(token_, amount_, receiver_, minimum_, deadline_)
            : _entryJoinSingleAssetExactInFlexible(edge_, amount_, true, receiver_, minimum_, deadline_);
    }
    function _exitLiquidityExactIn(address token_, uint256 amount_, address receiver_, uint256 minimum_, uint256 deadline_, address edge_)
        internal override returns (uint256)
    {
        return edge_ == address(0)
            ? _entryExitSingleAssetExactBptIn(token_, amount_, receiver_, minimum_, deadline_)
            : _entryExitSingleAssetExactBptInFlexible(edge_, amount_, true, receiver_, minimum_, deadline_);
    }
}
