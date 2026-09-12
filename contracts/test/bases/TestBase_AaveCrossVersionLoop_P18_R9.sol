// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveCrossVersionLoop_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol";

/// @notice Combo `P18_R9`: pair tokenA 18 / tokenB 9.
contract TestBase_AaveCrossVersionLoop_P18_R9 is TestBase_AaveCrossVersionLoop_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
