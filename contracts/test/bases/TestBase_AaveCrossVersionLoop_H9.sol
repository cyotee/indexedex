// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveCrossVersionLoop_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol";

/// @notice Combo `H9`: tokenA 9 / tokenB 9. pairToken = tokenA.
contract TestBase_AaveCrossVersionLoop_H9 is TestBase_AaveCrossVersionLoop_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
