// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_BalancerV3SinglePoolSE_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/adversarial/Adversarial_BalancerV3SinglePoolSE_Decimals.sol";

/// @notice Combo `P9_R18`. pairToken 9-dec; rateAsset 18-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract Adversarial_BalancerV3SinglePoolSE_P9_R18 is Adversarial_BalancerV3SinglePoolSE_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
