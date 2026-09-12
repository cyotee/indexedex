// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MorphoBlueStandardExchange_Invariant_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_Invariant_Decimals.sol";

/// @notice Combo `U9`: Morpho Blue SE invariants on a 9-dec loan token.
contract MorphoBlueStandardExchange_Invariant_U9 is MorphoBlueStandardExchange_Invariant_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
