// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_SingleStandardExchangeDETF_Decimals} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

/// @notice Combo `P6_R18`. pairToken 6-dec; rateAsset 18-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
abstract contract TestBase_SingleStandardExchangeDETF_P6_R18 is TestBase_SingleStandardExchangeDETF_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
