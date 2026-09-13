// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_AerodromeStandardExchange_Decimals} from
    "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_Decimals.sol";
/// @notice Combo `P6_R9`. pairToken = tokenA at 6-dec; other token 9-dec.
abstract contract TestBase_AerodromeStandardExchange_P6_R9 is TestBase_AerodromeStandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
