// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC4626StandardExchange_Morpho_Decimals} from
    "test/foundry/spec/vaults/standard/erc4626/decimals/ERC4626StandardExchange_Morpho_Decimals.sol";

/// @notice Combo `U9`: ERC-4626 SE Morpho flavor on a 9-dec loan token.
contract ERC4626StandardExchange_Morpho_U9 is ERC4626StandardExchange_Morpho_Decimals {
    function _loanDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
