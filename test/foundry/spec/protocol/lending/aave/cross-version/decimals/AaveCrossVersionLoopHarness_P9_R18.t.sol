// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopHarness_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopHarness_Decimals.sol";

/// @notice Combo `P9_R18`: pair tokenA 9 / tokenB 18.
contract AaveCrossVersionLoopHarness_P9_R18 is AaveCrossVersionLoopHarness_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
