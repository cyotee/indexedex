// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol";
/// @notice Book `B_ALL6`. pairToken=token0 at 6-dec; token1 6; token2 6. Hook LP / vaultShare stay 18.
abstract contract TestBase_UniswapV4StandardExchangeOrbitalBufferHook_B_ALL6 is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals
{
    function _dec0() internal pure override returns (uint8) { return 6; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 6; }
}
