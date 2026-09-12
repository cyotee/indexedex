// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC4626StandardExchange_Routes_Decimals} from
    "test/foundry/spec/vaults/standard/erc4626/decimals/ERC4626StandardExchange_Routes_Decimals.sol";

/// @notice Combo `U6`: ERC-4626 SE Routes on a 6-dec protocol-vault asset.
contract ERC4626StandardExchange_Routes_U6 is ERC4626StandardExchange_Routes_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
