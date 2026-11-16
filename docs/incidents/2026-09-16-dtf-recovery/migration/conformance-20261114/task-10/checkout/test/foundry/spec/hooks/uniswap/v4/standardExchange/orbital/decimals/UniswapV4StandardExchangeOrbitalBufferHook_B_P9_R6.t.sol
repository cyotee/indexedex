// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/decimals/UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol";

/// @notice Book `B_P9_R6`. pairToken=token0 9-dec; token1 6; token2 6. After PoolKey sort roles stay token0/1/2.
contract UniswapV4StandardExchangeOrbitalBufferHook_B_P9_R6 is
    UniswapV4StandardExchangeOrbitalBufferHook_Decimals
{
    function _dec0() internal pure override returns (uint8) { return 9; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 18; }
}
