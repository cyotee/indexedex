// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4BufferHookLiquidityExecutionBase} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase.sol";

abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookInExecutionBase is
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore,
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase,
    UniswapV4BufferHookLiquidityExecutionBase
{
    function _nativeRedemption(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal returns (uint256)
    {
        Repo.Layout storage l_ = Repo._layout();
        bool asShare_ = LegLib.classify(l_.legs, tokenOut_) == LegLib.LegKind.StandardExchange;
        address pair_ = asShare_ ? l_.legs.pairOfStandardExchange[tokenOut_] : tokenOut_;
        return _exitSingleAssetFrom(address(this), pair_, shares_, asShare_, receiver_, minimum_);
    }

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
        internal override onlyLiquidityRemover nonReentrant returns (uint256)
    {
        return edge_ == address(0)
            ? _exitSingleAssetExactBptIn(token_, amount_, receiver_, minimum_, deadline_)
            : _exitSingleAssetExactBptInFlexible(edge_, amount_, true, receiver_, minimum_, deadline_);
    }
}
