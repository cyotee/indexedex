// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4CurveQuadStableSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook_Decimals.sol";
/// @notice Book `B_P6_R9`. pairToken (construction first) 6-dec; next 9; remaining 18/18. After address sort t0..t3 permute. Hook LP stays 18.
abstract contract TestBase_UniswapV4CurveQuadStableSwapHook_B_P6_R9 is TestBase_UniswapV4CurveQuadStableSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 6; }
    function _dec1() internal pure override returns (uint8) { return 9; }
    function _dec2() internal pure override returns (uint8) { return 18; }
    function _dec3() internal pure override returns (uint8) { return 18; }
}
