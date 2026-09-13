// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/decimals/UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol";

/// @notice Book `B_P9_R18`. pairToken=token0 9-dec; token1 18; token2 18. After PoolKey sort roles stay token0/1/2.
contract UniswapV4StandardExchangeOrbitalBufferHook_B_P9_R18 is
    UniswapV4StandardExchangeOrbitalBufferHook_Decimals
{
    function _dec0() internal pure override returns (uint8) { return 9; }
    function _dec1() internal pure override returns (uint8) { return 18; }
    function _dec2() internal pure override returns (uint8) { return 18; }
}
