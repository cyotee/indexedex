// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4OrbitalSwapHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/decimals/UniswapV4OrbitalSwapHook_Decimals.sol";

/// @notice Book `B_P6_R18`. pairToken=token0 6-dec; token1 18; token2 18. After PoolKey sort roles stay token0/1/2.
contract UniswapV4OrbitalSwapHook_B_P6_R18 is UniswapV4OrbitalSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 6; }
    function _dec1() internal pure override returns (uint8) { return 18; }
    function _dec2() internal pure override returns (uint8) { return 18; }
}
