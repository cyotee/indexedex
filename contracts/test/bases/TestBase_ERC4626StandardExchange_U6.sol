// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_ERC4626StandardExchange_Decimals} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange_Decimals.sol";

/// @notice ERC-4626 SE TestBase: protocol-vault asset is 6-dec. Combo `U6`.
abstract contract TestBase_ERC4626StandardExchange_U6 is TestBase_ERC4626StandardExchange_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
