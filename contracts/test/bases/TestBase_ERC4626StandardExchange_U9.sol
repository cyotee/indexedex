// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_ERC4626StandardExchange_Decimals} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange_Decimals.sol";

/// @notice ERC-4626 SE TestBase: protocol-vault asset is 9-dec. Combo `U9`.
abstract contract TestBase_ERC4626StandardExchange_U9 is TestBase_ERC4626StandardExchange_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
