// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title IUniswapV4HookFlags
 * @notice Instance surface for required Uniswap V4 hook permission flags.
 */
interface IUniswapV4HookFlags {
    /// @notice Required hook permission flags stored at init from the package pure flags.
    function requiredHookFlags() external view returns (uint160 flags);
}
