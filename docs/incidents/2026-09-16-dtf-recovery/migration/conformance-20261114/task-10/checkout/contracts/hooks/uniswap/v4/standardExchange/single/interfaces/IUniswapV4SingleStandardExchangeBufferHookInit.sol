// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/**
 * @title IUniswapV4SingleStandardExchangeBufferHookInit
 * @notice Thin Single SE Buffer alias of the shared staged pair-door ABI (S58).
 */
interface IUniswapV4SingleStandardExchangeBufferHookInit is IUniswapV4HookStagedPairInit {}
