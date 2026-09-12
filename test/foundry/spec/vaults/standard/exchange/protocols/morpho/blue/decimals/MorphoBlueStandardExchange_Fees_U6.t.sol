// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MorphoBlueStandardExchange_Fees_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_Fees_Decimals.sol";

/// @notice Combo `U6`: Morpho Blue SE fees on a 6-dec loan token.
contract MorphoBlueStandardExchange_Fees_U6 is MorphoBlueStandardExchange_Fees_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
