// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeOutQueryTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol";
import {
    UniswapV4StandardExchangeOutExecuteTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol";

abstract contract UniswapV4StandardExchangeOutTarget is
    UniswapV4StandardExchangeOutQueryTarget,
    UniswapV4StandardExchangeOutExecuteTarget
{}
