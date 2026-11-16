// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {SlipstreamStandardExchangeRoutes_Test_Decimals} from
    "test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/SlipstreamStandardExchangeRoutes_Test_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA.
contract SlipstreamStandardExchangeRoutes_Test_P18_R6 is SlipstreamStandardExchangeRoutes_Test_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
