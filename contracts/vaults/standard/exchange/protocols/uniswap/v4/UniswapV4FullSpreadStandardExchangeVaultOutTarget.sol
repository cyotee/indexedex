// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget.sol";
import {
    UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol";

abstract contract UniswapV4FullSpreadStandardExchangeVaultOutTarget is
    UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget,
    UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget
{}
