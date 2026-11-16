// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol";
/// @notice Book `B_ALL9`. pairToken (construction first) 9-dec; next 9; remaining 9/9. After address sort token0..token3 permute. Hook LP stays 18.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_B_ALL9 is UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 9; }
    function _dec1() internal pure override returns (uint8) { return 9; }
    function _dec2() internal pure override returns (uint8) { return 9; }
    function _dec3() internal pure override returns (uint8) { return 9; }
}
