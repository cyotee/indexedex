// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryTarget.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol";

abstract contract UniswapV4FullSpreadHooklessStandardExchangeVaultOutTarget is
    UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryTarget,
    UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget
{}
