// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV3StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutBase.sol";

/// @dev Leftover alias: preview/mutate split lives on OutQueryTarget / OutExecuteTarget.
abstract contract UniswapV3StandardExchangeOutTarget is UniswapV3StandardExchangeOutBase {}
