// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinTarget.sol";

/// @title UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget
/// @notice Flexible join/deposit surface is implemented on JoinTarget; this is the facet inherit alias.
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget is
    UniswapV4StandardExchangeWeightedBufferHookJoinTarget
{}
