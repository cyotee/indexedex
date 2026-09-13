// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4DualSEBCPHook_B6M3_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/UniswapV4DualSEBCPHook_B6M3_Decimals.sol";

/// @notice Dual cell `D_U6_U9`. Left SE underlying 6-dec, right 9-dec.
contract UniswapV4DualSEBCPHook_B6M3_D_U6_U9 is UniswapV4DualSEBCPHook_B6M3_Decimals {
    function _leftDecimals() internal pure override returns (uint8) { return 6; }
    function _rightDecimals() internal pure override returns (uint8) { return 9; }
}
