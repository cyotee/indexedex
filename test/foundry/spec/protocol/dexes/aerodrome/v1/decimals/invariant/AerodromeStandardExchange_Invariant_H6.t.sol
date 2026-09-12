// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchange_Invariant_Decimals} from
    "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/invariant/AerodromeStandardExchange_Invariant_Decimals.sol";

/// @notice Combo `H6`. pairToken = tokenA at 6-dec; other token 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
/// forge-config: default.invariant.runs = 24
/// forge-config: default.invariant.depth = 10
contract AerodromeStandardExchange_Invariant_H6 is AerodromeStandardExchange_Invariant_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
