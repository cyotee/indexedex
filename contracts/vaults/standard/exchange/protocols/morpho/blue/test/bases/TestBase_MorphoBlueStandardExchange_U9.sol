// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice Morpho Blue SE TestBase: 9-dec loan token. Combo `U9`. Collateral stays 18.
contract TestBase_MorphoBlueStandardExchange_U9 is TestBase_MorphoBlueStandardExchange_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
