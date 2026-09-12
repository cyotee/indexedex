// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_SingleSE_A0Crops_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/adversarial/Adversarial_A0Crops_Decimals.sol";

/// @notice Combo `P18_R9`. pairToken 18-dec; rateAsset 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract Adversarial_A0Crops_P18_R9_BalV3StaSin is Adversarial_SingleSE_A0Crops_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
