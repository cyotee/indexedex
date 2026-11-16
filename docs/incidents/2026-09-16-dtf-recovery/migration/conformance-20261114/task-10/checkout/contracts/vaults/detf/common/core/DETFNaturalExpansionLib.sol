// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

/// @title DETFNaturalExpansionLib
/// @notice Retained Balancer premium-closure math over completed eight-hour epochs.
/// @dev D32-D55: the first bond anchors the clock; ineligible completed epochs are
///      consumed, and eligible catch-up has no time or supply-relative cap.
library DETFNaturalExpansionLib {
    /// @notice Funded-model inputs for the retained Balancer premium-closure formula.
    /// @dev No deployment mode, elapsed-time cap, or supply-relative mint cap.
    struct EpochInput {
        bool isLive;
        bool isMintAllowed;
        uint256 syntheticPrice;
        uint256 totalDetfSupply;
        uint256 lastSettledBoundary;
        uint256 nowTimestamp;
        uint256 closureRatePerSecond;
    }

    /// @notice Resolve the existing annual-rate default without any catch-up parameters.
    function resolveClosureRate(uint256 rate_) internal pure returns (uint256) {
        return rate_ == 0 ? DEFAULT_CLOSURE_RATE_PER_SECOND : rate_;
    }

    /// @notice Aggregate all completed eight-hour boundaries with the retained floor order.
    /// @dev The first bond initializes the boundary. Zero eligibility still consumes completed
    ///      epochs; only incomplete elapsed time remains. No historical reinvestment is simulated.
    function computeEpochExpansion(EpochInput memory in_)
        internal pure returns (uint256 mint_, uint256 boundary_)
    {
        boundary_ = in_.lastSettledBoundary;
        if (!in_.isLive || in_.nowTimestamp <= boundary_) return (0, boundary_);
        uint256 completed_ = ((in_.nowTimestamp - boundary_) / 8 hours) * 8 hours;
        boundary_ += completed_;
        if (completed_ == 0 || !in_.isMintAllowed || in_.totalDetfSupply == 0 || in_.syntheticPrice <= ONE) {
            return (0, boundary_);
        }
        mint_ = Math.mulDiv(in_.totalDetfSupply, in_.syntheticPrice - ONE, in_.syntheticPrice);
        mint_ = Math.mulDiv(mint_, in_.closureRatePerSecond, ONE);
        mint_ = Math.mulDiv(mint_, completed_, 1);
        if (mint_ <= DEFAULT_EXPANSION_DUST) mint_ = 0;
    }

    uint256 internal constant ONE = 1e18;
    /// @notice Close ten percent of the premium per year by default, in WAD per second.
    uint256 internal constant DEFAULT_CLOSURE_RATE_PER_SECOND = uint256(1e17) / uint256(365 days);
    /// @notice Preserve the existing native-unit floor below which no DETF is minted.
    uint256 internal constant DEFAULT_EXPANSION_DUST = 1;
}
