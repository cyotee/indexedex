// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

/// @title UniswapV4DetfHookStagedInitLib
/// @notice Granular door + finalize helpers for Uni V4 SE buffer hooks.
library UniswapV4DetfHookStagedInitLib {
    function openProductPair(address hook, address tokenA, address tokenB) internal {
        IUniswapV4HookStagedPairInit(hook).deployPair(tokenA, tokenB);
    }

    function finalizeHook(address hook) internal {
        IUniswapV4HookStagedPairInit(hook).finalizeInitialization();
    }
}
