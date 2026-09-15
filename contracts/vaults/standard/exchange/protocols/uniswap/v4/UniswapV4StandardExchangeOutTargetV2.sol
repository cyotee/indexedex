// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeOutQueryTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutQueryTargetV2.sol";
import {
    UniswapV4StandardExchangeOutExecuteTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutExecuteTargetV2.sol";

abstract contract UniswapV4StandardExchangeOutTargetV2 is
    UniswapV4StandardExchangeOutQueryTargetV2,
    UniswapV4StandardExchangeOutExecuteTargetV2
{}
