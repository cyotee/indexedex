// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title FixtureEconomics
/// @notice Platform fee / bond defaults and CREATE2 salt namespace for architecture deploys.
library FixtureEconomics {
    string internal constant SALT_NS = "RhMain";

    /// @dev Owner-selected metadata for the fee-accrual DETF instance (Phase 08-03).
    string internal constant FEE_ACCRUAL_DETF_NAME = "DTF-DETF";
    string internal constant FEE_ACCRUAL_DETF_SYMBOL = "DTF-DETF";
    uint256 internal constant FEE_ACCRUAL_DETF_WEIGHT = 0.6e18;
    uint256 internal constant FEE_ACCRUAL_WETH_WEIGHT = 0.2e18;
    uint256 internal constant FEE_ACCRUAL_DTF_WEIGHT = 0.2e18;

    uint256 internal constant MIN_LOCK = 86400;
    uint256 internal constant MAX_LOCK = 180 days;

    uint256 internal constant USAGE_FEE = 5e16;
    uint256 internal constant DEX_SWAP_FEE = 3e14;
    uint256 internal constant SEIGNIORAGE = 5e16;
    uint256 internal constant V4_LIQUID_RESERVE = 0.2e18;
}
