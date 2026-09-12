// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchangeIn_Swap_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchangeIn_Swap_Decimals.sol";

/// @notice Combo `H6`. pairToken = tokenA at 6-dec; other token 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchangeIn_Swap_H6 is AerodromeStandardExchangeIn_Swap_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
