// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol";
/// @notice Book `B_P18_R6`. pairToken (construction first) 18-dec; next 6; remaining 18/18. After address sort token0..token3 permute. Hook LP stays 18.
abstract contract TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_B_P18_R6 is TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 18; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 18; }
    function _dec3() internal pure override returns (uint8) { return 18; }
}
