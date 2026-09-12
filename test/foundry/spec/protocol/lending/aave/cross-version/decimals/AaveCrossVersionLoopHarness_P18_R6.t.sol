// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopHarness_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopHarness_Decimals.sol";

/// @notice Combo `P18_R6`: pair tokenA 18 / tokenB 6.
contract AaveCrossVersionLoopHarness_P18_R6 is AaveCrossVersionLoopHarness_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
