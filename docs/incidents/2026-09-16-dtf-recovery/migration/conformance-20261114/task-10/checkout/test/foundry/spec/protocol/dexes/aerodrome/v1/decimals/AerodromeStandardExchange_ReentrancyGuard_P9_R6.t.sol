// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchange_ReentrancyGuard_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchange_ReentrancyGuard_Decimals.sol";

/// @notice Combo `P9_R6`. pairToken = tokenA at 9-dec; other token 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchange_ReentrancyGuard_P9_R6 is AerodromeStandardExchange_ReentrancyGuard_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
