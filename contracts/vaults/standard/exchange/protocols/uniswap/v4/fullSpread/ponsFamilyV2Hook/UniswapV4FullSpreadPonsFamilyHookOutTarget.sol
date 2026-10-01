// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4FullSpreadPonsFamilyHookOutQueryTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutQueryTarget.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol";

abstract contract UniswapV4FullSpreadPonsFamilyHookOutTarget is
    UniswapV4FullSpreadPonsFamilyHookOutQueryTarget,
    UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget
{}
