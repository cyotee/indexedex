// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchangeIn_ZapOut_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchangeIn_ZapOut_Decimals.sol";

/// @notice Combo `P9_R18`. pairToken = tokenA at 9-dec; other token 18-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchangeIn_ZapOut_P9_R18 is AerodromeStandardExchangeIn_ZapOut_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
