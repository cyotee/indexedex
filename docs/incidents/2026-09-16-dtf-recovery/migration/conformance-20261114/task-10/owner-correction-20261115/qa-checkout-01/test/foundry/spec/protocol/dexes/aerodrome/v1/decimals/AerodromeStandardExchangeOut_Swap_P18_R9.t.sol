// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchangeOut_Swap_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchangeOut_Swap_Decimals.sol";

/// @notice Combo `P18_R9`. pairToken = tokenA at 18-dec; other token 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchangeOut_Swap_P18_R9 is AerodromeStandardExchangeOut_Swap_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
