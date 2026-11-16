// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4OrbitalSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook_Decimals.sol";
/// @notice Book `B_P18_R6`. pairToken=token0 at 18-dec; token1 6; token2 18. Hook LP stays 18.
abstract contract TestBase_UniswapV4OrbitalSwapHook_B_P18_R6 is TestBase_UniswapV4OrbitalSwapHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 18; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 18; }
}
