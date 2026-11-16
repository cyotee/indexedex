// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC4626StandardExchange_Adversarial_Decimals} from
    "test/foundry/spec/vaults/standard/erc4626/decimals/ERC4626StandardExchange_Adversarial_Decimals.sol";

/// @notice Combo `U6`: ERC-4626 SE adversarial I1–I3 on a 6-dec protocol-vault asset.
contract ERC4626StandardExchange_Adversarial_U6 is ERC4626StandardExchange_Adversarial_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
