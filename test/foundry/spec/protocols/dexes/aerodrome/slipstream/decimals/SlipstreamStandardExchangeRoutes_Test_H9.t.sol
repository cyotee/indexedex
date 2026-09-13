// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {SlipstreamStandardExchangeRoutes_Test_Decimals} from
    "test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/SlipstreamStandardExchangeRoutes_Test_Decimals.sol";
/// @notice Combo `H9`. pairToken = tokenA.
contract SlipstreamStandardExchangeRoutes_Test_H9 is SlipstreamStandardExchangeRoutes_Test_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
