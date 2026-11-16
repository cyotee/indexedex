// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LidoWstETHStandardExchangeCommon} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol";

/**
 * @title LidoWstETHMarkerTarget
 * @notice Marker surface (address getters + reserve views). rebalance is on Rebalance facet.
 */
abstract contract LidoWstETHMarkerTarget is LidoWstETHStandardExchangeCommon {
    // Views inherited from Common. rebalance() implemented on RebalanceTarget.
}
