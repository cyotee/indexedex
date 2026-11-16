// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MorphoBlueStandardExchange_RateProvider_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_RateProvider_Decimals.sol";

/// @notice Combo `U6`: Morpho Blue SE rate provider on a 6-dec loan token.
contract MorphoBlueStandardExchange_RateProvider_U6 is MorphoBlueStandardExchange_RateProvider_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
