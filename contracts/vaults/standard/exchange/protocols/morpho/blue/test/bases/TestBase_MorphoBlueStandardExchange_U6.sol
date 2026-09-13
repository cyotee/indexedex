// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice Morpho Blue SE TestBase: 6-dec loan token. Combo `U6`. Collateral stays 18.
abstract contract TestBase_MorphoBlueStandardExchange_U6 is TestBase_MorphoBlueStandardExchange_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
