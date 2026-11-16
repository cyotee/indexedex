// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {SlipstreamStandardExchange_Routes_Decimals} from
    "test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/SlipstreamStandardExchange_Routes_Decimals.sol";
/// @notice Combo `P6_R9`. pairToken = tokenA.
contract SlipstreamStandardExchange_Routes_P6_R9 is SlipstreamStandardExchange_Routes_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
