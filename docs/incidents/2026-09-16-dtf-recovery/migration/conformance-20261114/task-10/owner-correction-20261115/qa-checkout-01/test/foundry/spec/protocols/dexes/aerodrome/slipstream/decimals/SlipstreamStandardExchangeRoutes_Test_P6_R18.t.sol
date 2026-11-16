// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {SlipstreamStandardExchangeRoutes_Test_Decimals} from
    "test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/SlipstreamStandardExchangeRoutes_Test_Decimals.sol";
/// @notice Combo `P6_R18`. pairToken = tokenA.
contract SlipstreamStandardExchangeRoutes_Test_P6_R18 is SlipstreamStandardExchangeRoutes_Test_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
