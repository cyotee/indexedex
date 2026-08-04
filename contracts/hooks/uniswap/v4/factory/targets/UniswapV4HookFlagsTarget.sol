// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {UniswapV4HookFlagsRepo} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookFlagsRepo.sol";

/**
 * @title UniswapV4HookFlagsTarget
 * @notice Logic target for instance requiredHookFlags() view.
 */
contract UniswapV4HookFlagsTarget is IUniswapV4HookFlags {
    function requiredHookFlags() public view returns (uint160 flags) {
        return UniswapV4HookFlagsRepo._requiredHookFlags();
    }
}
