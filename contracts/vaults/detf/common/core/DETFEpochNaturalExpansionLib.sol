// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

/// @title DETFEpochNaturalExpansionLib
/// @notice Epoch premium-closure natural expansion (Uni V4 Single SE CP DETF PRD §10; planned shared form).
/// @dev Whole-epoch catch-up only. `maxCatchUpEpochs == 0` means unlimited epochs.
library DETFEpochNaturalExpansionLib {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant YEAR = 365 days;
    uint256 internal constant DEFAULT_EPOCH_LENGTH = 8 hours;
    /// @notice 10% of premium closed per year (WAD).
    uint256 internal constant DEFAULT_CLOSURE_RATE_PER_YEAR_WAD = 0.10e18;
    uint256 internal constant DEFAULT_EXPANSION_DUST = 1;

    struct AccrualInput {
        bool isLive;
        bool isPolicyMode;
        uint256 spotSyntheticPrice; // S_spot at 1e18 peg scale (not debt-inclusive)
        uint256 totalDetfSupply;
        uint256 lastExpansionTimestamp;
        uint256 nowTimestamp;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs; // 0 = unlimited
    }

    /// @notice Resolve PkgArgs zeros → PRD defaults.
    function resolveExpansionParams(
        uint256 epochLengthArg_,
        uint256 closureRatePerYearArg_,
        uint256 maxCatchUpEpochsArg_
    )
        internal
        pure
        returns (uint256 epochLength_, uint256 closureRatePerYear_, uint256 maxCatchUpEpochs_)
    {
        epochLength_ = epochLengthArg_ == 0 ? DEFAULT_EPOCH_LENGTH : epochLengthArg_;
        closureRatePerYear_ =
            closureRatePerYearArg_ == 0 ? DEFAULT_CLOSURE_RATE_PER_YEAR_WAD : closureRatePerYearArg_;
        // 0 is meaningful: unlimited catch-up.
        maxCatchUpEpochs_ = maxCatchUpEpochsArg_;
    }

    /// @notice Pure preview of pending expansion mint (debt). Does not advance clock.
    function previewPendingExpansionMint(AccrualInput memory in_) internal pure returns (uint256 mint_) {
        if (!in_.isLive || !in_.isPolicyMode) return 0;
        if (in_.lastExpansionTimestamp == 0) return 0;
        if (in_.nowTimestamp <= in_.lastExpansionTimestamp) return 0;
        if (in_.totalDetfSupply == 0 || in_.expansionEpochLength == 0) return 0;
        if (in_.spotSyntheticPrice <= ONE) return 0;

        uint256 epochs_ = (in_.nowTimestamp - in_.lastExpansionTimestamp) / in_.expansionEpochLength;
        if (in_.expansionMaxCatchUpEpochs > 0 && epochs_ > in_.expansionMaxCatchUpEpochs) {
            epochs_ = in_.expansionMaxCatchUpEpochs;
        }
        if (epochs_ == 0) return 0;

        uint256 closurePerEpoch_ =
            Math.mulDiv(in_.expansionClosureRatePerYearWad, in_.expansionEpochLength, YEAR);
        uint256 premium_ = in_.spotSyntheticPrice - ONE;
        // mintPerEpoch = totalSupply * premium * closurePerEpoch / (1e18 * S_spot)
        uint256 mintPerEpoch_ = Math.mulDiv(in_.totalDetfSupply, premium_, in_.spotSyntheticPrice);
        mintPerEpoch_ = Math.mulDiv(mintPerEpoch_, closurePerEpoch_, ONE);
        mint_ = mintPerEpoch_ * epochs_;
        if (mint_ <= DEFAULT_EXPANSION_DUST) return 0;
    }

    /// @notice Compute mint + new lastExpansionTimestamp for realize path.
    /// @dev Seed path: last == 0 → set last = now, mint 0.
    function computeRealization(AccrualInput memory in_)
        internal
        pure
        returns (uint256 mintAmount_, uint256 newLastTimestamp_)
    {
        if (!in_.isLive || !in_.isPolicyMode) {
            return (0, in_.lastExpansionTimestamp);
        }
        if (in_.lastExpansionTimestamp == 0) {
            return (0, in_.nowTimestamp);
        }

        uint256 epochs_ = 0;
        if (in_.nowTimestamp > in_.lastExpansionTimestamp && in_.expansionEpochLength > 0) {
            epochs_ = (in_.nowTimestamp - in_.lastExpansionTimestamp) / in_.expansionEpochLength;
            if (in_.expansionMaxCatchUpEpochs > 0 && epochs_ > in_.expansionMaxCatchUpEpochs) {
                epochs_ = in_.expansionMaxCatchUpEpochs;
            }
        }

        mintAmount_ = previewPendingExpansionMint(in_);
        if (epochs_ == 0) {
            return (0, in_.lastExpansionTimestamp);
        }
        newLastTimestamp_ = in_.lastExpansionTimestamp + epochs_ * in_.expansionEpochLength;
        if (mintAmount_ == 0) {
            // Still advance whole epochs so catch-up does not re-walk the same window forever.
            return (0, newLastTimestamp_);
        }
    }
}
