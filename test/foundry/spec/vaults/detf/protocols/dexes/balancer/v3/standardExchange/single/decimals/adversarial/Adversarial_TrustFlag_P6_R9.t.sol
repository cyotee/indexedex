// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_SingleSE_TrustFlag_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/adversarial/Adversarial_TrustFlag_Decimals.sol";

/// @notice Combo `P6_R9`. pairToken 6-dec; rateAsset 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract Adversarial_TrustFlag_P6_R9 is Adversarial_SingleSE_TrustFlag_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
