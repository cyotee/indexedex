// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/**
 * @title IUniswapV4StandardExchangeWeightedBufferHookInit
 * @notice Thin SE Weighted alias of the shared staged pair-init surface (S58).
 * @dev No extra functions. Unmatched on the proxy after finalizeInitialization.
 *      Do not add these views to IUniswapV4StandardExchangeWeightedBufferHook.
 */
interface IUniswapV4StandardExchangeWeightedBufferHookInit is IUniswapV4HookStagedPairInit {}
