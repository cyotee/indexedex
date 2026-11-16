// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveCrossVersionLoop_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol";

/// @notice Combo `P9_R6`: pair tokenA 9 / tokenB 6.
abstract contract TestBase_AaveCrossVersionLoop_P9_R6 is TestBase_AaveCrossVersionLoop_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
