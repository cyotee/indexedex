// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_SlipstreamStandardExchange_Decimals} from
    "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA at 18-dec; other token 6-dec.
abstract contract TestBase_SlipstreamStandardExchange_P18_R6 is TestBase_SlipstreamStandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
