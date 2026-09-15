// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV3StandardExchangeOutBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeOutBaseV2.sol";

/// @dev Leftover alias: preview/mutate split lives on OutQueryTarget / OutExecuteTarget.
abstract contract UniswapV3StandardExchangeOutTargetV2 is UniswapV3StandardExchangeOutBaseV2 {}
