// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MorphoBlueStandardExchange_Interest_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_Interest_Decimals.sol";

/// @notice Combo `U6`: Morpho Blue SE interest on a 6-dec loan token.
contract MorphoBlueStandardExchange_Interest_U6 is MorphoBlueStandardExchange_Interest_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
