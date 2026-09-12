// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopHarness_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopHarness_Decimals.sol";

/// @notice Combo `P6_R9`: pair tokenA 6 / tokenB 9.
contract AaveCrossVersionLoopHarness_P6_R9 is AaveCrossVersionLoopHarness_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
