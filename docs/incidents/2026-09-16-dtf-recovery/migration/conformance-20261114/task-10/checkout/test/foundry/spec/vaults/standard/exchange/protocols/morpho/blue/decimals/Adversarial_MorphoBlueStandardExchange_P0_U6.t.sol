// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_MorphoBlueStandardExchange_P0_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/Adversarial_MorphoBlueStandardExchange_P0_Decimals.sol";

/// @notice Combo `U6`: Morpho Blue SE adversarial P0 on a 6-dec loan token.
contract Adversarial_MorphoBlueStandardExchange_P0_U6 is Adversarial_MorphoBlueStandardExchange_P0_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
