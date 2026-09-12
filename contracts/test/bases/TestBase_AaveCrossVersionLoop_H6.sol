// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveCrossVersionLoop_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol";

/// @notice Combo `H6`: tokenA 6 / tokenB 6. pairToken = tokenA.
contract TestBase_AaveCrossVersionLoop_H6 is TestBase_AaveCrossVersionLoop_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
