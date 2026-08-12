// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title MintSplit
 * @notice Shared mint fee/seigniorage split for DETF families (L-STRUCT-1).
 * @dev Single definition imported by Uni V4 / Balancer DETF Commons; do not re-declare.
 */
struct MintSplit {
    uint256 grossDetf;
    uint256 userDetf;
    uint256 feeToDetf;
    uint256 inventoryDetf;
}
