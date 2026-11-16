// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeBufferPool_RateTrackingTest_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/StandardExchangeBufferPool_RateTracking_Decimals.sol";

/// @notice Combo `P18_R9`. pairToken 18-dec; rateAsset 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract StandardExchangeBufferPool_RateTracking_P18_R9 is StandardExchangeBufferPool_RateTrackingTest_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
