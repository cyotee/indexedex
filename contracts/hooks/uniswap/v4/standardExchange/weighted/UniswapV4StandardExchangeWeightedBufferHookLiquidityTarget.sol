// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeWeightedBufferHookJoinTarget} from "./UniswapV4StandardExchangeWeightedBufferHookJoinTarget.sol";
import {UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget} from "./UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget.sol";
import {UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget} from "./UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol";
import {UniswapV4StandardExchangeWeightedBufferHookExitTarget} from "./UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol";
import {UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget} from "./UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol";

/// @notice Aggregate surface uses exactly the installed family cores and guards.
abstract contract UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget is
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget,
    UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget,
    UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget,
    UniswapV4StandardExchangeWeightedBufferHookExitTarget,
    UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget
{}
