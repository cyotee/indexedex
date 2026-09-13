// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_SingleStandardExchangeDETF_Decimals} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

/// @notice Combo `H9`. pairToken 9-dec; rateAsset 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
abstract contract TestBase_SingleStandardExchangeDETF_H9 is TestBase_SingleStandardExchangeDETF_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
