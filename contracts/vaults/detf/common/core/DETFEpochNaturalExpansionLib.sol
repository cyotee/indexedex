// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

/// @title DETFEpochNaturalExpansionLib
/// @notice Fixed eight-hour aggregate premium closure, anchored by the first successful bond.
library DETFEpochNaturalExpansionLib {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant YEAR = 365 days;
    uint256 internal constant EPOCH = 8 hours;
    uint256 internal constant DEFAULT_CLOSURE_RATE_PER_YEAR_WAD = 0.10e18;
    uint256 internal constant DEFAULT_EXPANSION_DUST = 1;

    struct AccrualInput {
        bool isLive;
        uint256 spotSyntheticPrice;
        uint256 mintThreshold;
        uint256 totalDetfSupply;
        uint256 lastExpansionTimestamp;
        uint256 nowTimestamp;
        uint256 expansionClosureRatePerYearWad;
    }

    /// @notice Retain the family's annual closure-rate default.
    function resolveClosureRate(uint256 rateArg_) internal pure returns (uint256) {
        return rateArg_ == 0 ? DEFAULT_CLOSURE_RATE_PER_YEAR_WAD : rateArg_;
    }

    /// @notice Quote from actual current supply and price, preserving the per-epoch floor order.
    /// @dev The caller supplies the highest non-DETF synthetic price. Eligibility is strictly
    /// above the mint threshold and peg. No historical compounding or catch-up cap.
    function previewPendingExpansionMint(AccrualInput memory in_) internal pure returns (uint256 mint_) {
        if (!in_.isLive || in_.nowTimestamp <= in_.lastExpansionTimestamp) return 0;
        if (
            in_.totalDetfSupply == 0 || in_.spotSyntheticPrice <= ONE
                || in_.spotSyntheticPrice <= in_.mintThreshold
        ) return 0;
        uint256 epochs_ = (in_.nowTimestamp - in_.lastExpansionTimestamp) / EPOCH;
        if (epochs_ == 0) return 0;
        uint256 closurePerEpoch_ = Math.mulDiv(in_.expansionClosureRatePerYearWad, EPOCH, YEAR);
        uint256 perEpoch_ = Math.mulDiv(in_.totalDetfSupply, in_.spotSyntheticPrice - ONE, in_.spotSyntheticPrice);
        perEpoch_ = Math.mulDiv(perEpoch_, closurePerEpoch_, ONE);
        mint_ = perEpoch_ * epochs_;
        if (mint_ <= DEFAULT_EXPANSION_DUST) return 0;
    }

    /// @notice Consume all completed boundaries even when no eligible expansion is minted.
    /// @dev Initialization belongs to the first-bond transaction; timestamp zero is a valid anchor.
    function computeRealization(AccrualInput memory in_)
        internal pure returns (uint256 mintAmount_, uint256 newLastTimestamp_)
    {
        newLastTimestamp_ = in_.lastExpansionTimestamp;
        if (!in_.isLive || in_.nowTimestamp <= newLastTimestamp_) return (0, newLastTimestamp_);
        uint256 epochs_ = (in_.nowTimestamp - newLastTimestamp_) / EPOCH;
        newLastTimestamp_ += epochs_ * EPOCH;
        mintAmount_ = previewPendingExpansionMint(in_);
    }
}
