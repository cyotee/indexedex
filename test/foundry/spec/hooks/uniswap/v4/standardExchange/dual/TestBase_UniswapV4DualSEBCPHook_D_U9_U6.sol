// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4DualSEBCPHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Decimals.sol";
/// @notice Dual cell `D_U9_U6`: left SE underlying 9-dec, right 6-dec.
abstract contract TestBase_UniswapV4DualSEBCPHook_D_U9_U6 is TestBase_UniswapV4DualSEBCPHook_Decimals {
    function _leftDecimals() internal pure override returns (uint8) { return 9; }
    function _rightDecimals() internal pure override returns (uint8) { return 6; }
}
