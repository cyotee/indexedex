// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4WeightedSwapHookHooksTarget
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookHooksTarget.sol";
import {
    UniswapV4WeightedSwapHookLiquidityTarget
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookLiquidityTarget.sol";

abstract contract UniswapV4WeightedSwapHookTarget is
    UniswapV4WeightedSwapHookHooksTarget,
    UniswapV4WeightedSwapHookLiquidityTarget
{}
