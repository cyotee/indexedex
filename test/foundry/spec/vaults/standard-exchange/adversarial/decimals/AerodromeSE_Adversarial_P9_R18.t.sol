// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AerodromeSE_Adversarial_Decimals} from "test/foundry/spec/vaults/standard-exchange/adversarial/decimals/AerodromeSE_Adversarial_Decimals.sol";

/// @notice Combo `P9_R18`. pairToken = tokenA at 9-dec; other token 18-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
///      vaultShare stays 18.
contract AerodromeSE_Adversarial_P9_R18 is AerodromeSE_Adversarial_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
