// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";

/// @notice Stata SE TestBase: listed NINE (9-dec) as Stata base. Combo `U9`. SE vaultShare stays 18.
contract TestBase_AaveV3StataStandardExchange_U9 is TestBase_AaveV3StataStandardExchange_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
