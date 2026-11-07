// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget.sol";

/// @notice Aggregate surface uses the same component-accounting paths as the installed facets.
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget is
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget,
    UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget,
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget
{}
