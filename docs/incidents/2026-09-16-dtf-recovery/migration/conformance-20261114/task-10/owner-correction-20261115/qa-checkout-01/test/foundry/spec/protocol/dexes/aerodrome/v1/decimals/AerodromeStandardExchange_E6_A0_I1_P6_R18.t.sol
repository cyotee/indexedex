// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchange_E6_A0_I1_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchange_E6_A0_I1_Decimals.sol";

/// @notice Combo `P6_R18`. pairToken = tokenA at 6-dec; other token 18-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchange_E6_A0_I1_P6_R18 is AerodromeStandardExchange_E6_A0_I1_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
