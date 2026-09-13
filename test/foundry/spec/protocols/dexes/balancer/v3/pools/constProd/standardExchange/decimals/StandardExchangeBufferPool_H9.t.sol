// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeBufferPoolSpec_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/StandardExchangeBufferPool_Decimals.sol";

/// @notice Combo `H9`. pairToken 9-dec; rateAsset 9-dec.
/// @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs rateAsset.
///      vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18.
contract StandardExchangeBufferPool_H9 is StandardExchangeBufferPoolSpec_Decimals {
    function _pairDecimals() internal pure override returns (uint8) {
        return 9;
    }

    function _rateDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
