// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_SingleStandardExchangeDETF_Adversarial_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial_Decimals.sol";

/// @notice Combo `P18_R6`. pairToken 18-dec; rateAsset 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract TestBase_SingleStandardExchangeDETF_Adversarial_P18_R6 is TestBase_SingleStandardExchangeDETF_Adversarial_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
