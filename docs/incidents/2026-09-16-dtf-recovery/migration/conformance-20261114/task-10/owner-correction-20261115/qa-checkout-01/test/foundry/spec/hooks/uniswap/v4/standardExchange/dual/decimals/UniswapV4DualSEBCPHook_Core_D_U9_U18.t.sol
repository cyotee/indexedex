// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4DualSEBCPHook_Core_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/UniswapV4DualSEBCPHook_Core_Decimals.sol";

/// @notice Dual cell `D_U9_U18`. Left SE underlying 9-dec, right 18-dec.
contract UniswapV4DualSEBCPHook_Core_D_U9_U18 is UniswapV4DualSEBCPHook_Core_Decimals {
    function _leftDecimals() internal pure override returns (uint8) { return 9; }
    function _rightDecimals() internal pure override returns (uint8) { return 18; }
}
