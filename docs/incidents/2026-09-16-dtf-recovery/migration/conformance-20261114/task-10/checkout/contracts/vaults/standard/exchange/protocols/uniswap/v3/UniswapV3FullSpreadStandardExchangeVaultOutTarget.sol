// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV3FullSpreadStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol";

/// @dev Leftover alias: preview/mutate split lives on OutQueryTarget / OutExecuteTarget.
abstract contract UniswapV3FullSpreadStandardExchangeVaultOutTarget is UniswapV3FullSpreadStandardExchangeVaultOutBase {}
