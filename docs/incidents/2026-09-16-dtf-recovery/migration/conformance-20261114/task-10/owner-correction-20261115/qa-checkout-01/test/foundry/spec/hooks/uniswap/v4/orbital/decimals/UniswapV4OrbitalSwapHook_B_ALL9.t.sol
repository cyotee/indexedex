// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4OrbitalSwapHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/decimals/UniswapV4OrbitalSwapHook_Decimals.sol";

/// @notice Book `B_ALL9`. pairToken=token0 9-dec; token1 9; token2 9. After PoolKey sort roles stay token0/1/2.
contract UniswapV4OrbitalSwapHook_B_ALL9 is UniswapV4OrbitalSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 9; }
    function _dec1() internal pure override returns (uint8) { return 9; }
    function _dec2() internal pure override returns (uint8) { return 9; }
}
