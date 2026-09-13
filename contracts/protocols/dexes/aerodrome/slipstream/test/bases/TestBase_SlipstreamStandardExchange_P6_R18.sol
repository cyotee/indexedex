// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_SlipstreamStandardExchange_Decimals} from
    "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange_Decimals.sol";
/// @notice Combo `P6_R18`. pairToken = tokenA at 6-dec; other token 18-dec.
abstract contract TestBase_SlipstreamStandardExchange_P6_R18 is TestBase_SlipstreamStandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
