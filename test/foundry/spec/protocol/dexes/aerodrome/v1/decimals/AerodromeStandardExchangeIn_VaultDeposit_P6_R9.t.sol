// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeStandardExchangeIn_VaultDeposit_Decimals} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/AerodromeStandardExchangeIn_VaultDeposit_Decimals.sol";

/// @notice Combo `P6_R9`. pairToken = tokenA at 6-dec; other token 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeStandardExchangeIn_VaultDeposit_P6_R9 is AerodromeStandardExchangeIn_VaultDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
