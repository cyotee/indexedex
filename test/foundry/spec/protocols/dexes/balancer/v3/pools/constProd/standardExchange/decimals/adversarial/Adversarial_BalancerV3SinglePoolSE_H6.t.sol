// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_BalancerV3SinglePoolSE_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/adversarial/Adversarial_BalancerV3SinglePoolSE_Decimals.sol";

/// @notice Combo `H6`. pairToken 6-dec; rateAsset 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract Adversarial_BalancerV3SinglePoolSE_H6 is Adversarial_BalancerV3SinglePoolSE_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
