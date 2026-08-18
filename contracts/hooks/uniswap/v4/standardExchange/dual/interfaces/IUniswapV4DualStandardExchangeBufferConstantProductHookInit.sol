// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/**
 * @title IUniswapV4DualStandardExchangeBufferConstantProductHookInit
 * @notice Thin Dual alias of the shared staged pair-door ABI (S58).
 */
interface IUniswapV4DualStandardExchangeBufferConstantProductHookInit is
    IUniswapV4HookStagedPairInit
{}
