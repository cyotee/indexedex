// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title FixtureEconomics
/// @notice Platform fee / bond defaults and CREATE2 salt namespace for architecture deploys.
library FixtureEconomics {
    string internal constant SALT_NS = "RhMain";

    uint256 internal constant MIN_LOCK = 86400;
    uint256 internal constant MAX_LOCK = 180 days;

    uint256 internal constant USAGE_FEE = 5e16;
    uint256 internal constant DEX_SWAP_FEE = 3e14;
    uint256 internal constant SEIGNIORAGE = 5e16;
    uint256 internal constant V4_LIQUID_RESERVE = 0.2e18;
}
