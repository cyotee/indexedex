// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    EtherFiWeETHStandardExchangeCommon
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol";

/**
 * @title EtherFiWeETHMarkerTarget
 * @notice Marker surface (address getters + reserve views). rebalance is on Rebalance facet.
 */
abstract contract EtherFiWeETHMarkerTarget is EtherFiWeETHStandardExchangeCommon {
    // Views inherited from Common. rebalance() implemented on RebalanceTarget.
}
