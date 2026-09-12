// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SingleStandardExchangeDETF_Burn_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/SingleStandardExchangeDETF_Burn_Decimals.sol";

/// @notice Combo `P9_R6`. pairToken 9-dec; rateAsset 6-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract SingleStandardExchangeDETF_Burn_P9_R6 is SingleStandardExchangeDETF_Burn_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
