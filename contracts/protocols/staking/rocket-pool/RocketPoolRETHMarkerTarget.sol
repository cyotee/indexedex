// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    RocketPoolRETHStandardExchangeCommon
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol";

/**
 * @title RocketPoolRETHMarkerTarget
 * @notice Marker surface (address getters + reserve views). rebalance is on Rebalance facet.
 */
abstract contract RocketPoolRETHMarkerTarget is RocketPoolRETHStandardExchangeCommon {
    // Views inherited from Common.
}
