// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4CurveQuadStableSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook_Decimals.sol";
/// @notice Book `B_ALL6`. pairToken (construction first) 6-dec; next 6; remaining 6/6. After address sort t0..t3 permute. Hook LP stays 18.
abstract contract TestBase_UniswapV4CurveQuadStableSwapHook_B_ALL6 is TestBase_UniswapV4CurveQuadStableSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 6; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 6; }
    function _dec3() internal pure override returns (uint8) { return 6; }
}
