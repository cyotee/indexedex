// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Re-export package-adjacent gold TestBase for hermetic specs under FOUNDRY_PROFILE=orbital.
import {
    TestBase_UniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
