// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MorphoBlueStandardExchange_Deploy_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_Deploy_Decimals.sol";

/// @notice Combo `U9`: Morpho Blue SE deploy on a 9-dec loan token.
contract MorphoBlueStandardExchange_Deploy_U9 is MorphoBlueStandardExchange_Deploy_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
