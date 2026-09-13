// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/decimals/UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol";

/// @notice Book `B_P18_R6`. pairToken=token0 18-dec; token1 6; token2 18. After PoolKey sort roles stay token0/1/2.
contract UniswapV4StandardExchangeOrbitalBufferHook_B_P18_R6 is
    UniswapV4StandardExchangeOrbitalBufferHook_Decimals
{
    function _dec0() internal pure override returns (uint8) { return 18; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 18; }
}
