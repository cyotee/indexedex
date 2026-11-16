// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveCrossVersionLoopHarness_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopHarness_Decimals.sol";

/// @notice Combo `H6`: Aave loop harness, both tokens 6-dec.
contract AaveCrossVersionLoopHarness_H6 is AaveCrossVersionLoopHarness_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
