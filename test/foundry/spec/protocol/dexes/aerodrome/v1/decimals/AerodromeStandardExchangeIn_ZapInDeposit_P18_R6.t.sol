// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchangeIn_ZapInDeposit_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchangeIn_ZapInDeposit_Decimals.sol";

/// @notice Combo `P18_R6`. pairToken = tokenA at 18-dec; other token 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchangeIn_ZapInDeposit_P18_R6 is AerodromeStandardExchangeIn_ZapInDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
