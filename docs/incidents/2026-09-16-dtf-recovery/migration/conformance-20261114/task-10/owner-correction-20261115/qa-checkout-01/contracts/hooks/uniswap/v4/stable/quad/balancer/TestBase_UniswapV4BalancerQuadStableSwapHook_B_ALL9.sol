// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4BalancerQuadStableSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/stable/quad/balancer/TestBase_UniswapV4BalancerQuadStableSwapHook_Decimals.sol";
/// @notice Book `B_ALL9`. pairToken (construction first) 9-dec; next 9; remaining 9/9. After address sort t0..t3 permute. Hook LP stays 18.
abstract contract TestBase_UniswapV4BalancerQuadStableSwapHook_B_ALL9 is TestBase_UniswapV4BalancerQuadStableSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 9; }
    function _dec1() internal pure override returns (uint8) { return 9; }
    function _dec2() internal pure override returns (uint8) { return 9; }
    function _dec3() internal pure override returns (uint8) { return 9; }
}
