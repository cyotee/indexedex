// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    DETFEpochNaturalExpansionLib as Lib
} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";

/// @notice Pure unit tests for epoch premium-closure expansion formula (PRD §10).
contract DETFEpochNaturalExpansionLibTest is Test {
    function test_resolve_zeros_to_defaults() public pure {
        (uint256 epoch, uint256 rate, uint256 maxCatch) = Lib.resolveExpansionParams(0, 0, 0);
        assertEq(epoch, Lib.DEFAULT_EPOCH_LENGTH);
        assertEq(rate, Lib.DEFAULT_CLOSURE_RATE_PER_YEAR_WAD);
        assertEq(maxCatch, 0); // unlimited kept
    }

    function test_preview_zero_when_not_live_or_open() public pure {
        Lib.AccrualInput memory in_;
        in_.isLive = false;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = 2e18;
        in_.totalDetfSupply = 1e18;
        in_.lastExpansionTimestamp = 1000;
        in_.nowTimestamp = 1000 + 8 hours;
        in_.expansionEpochLength = 8 hours;
        in_.expansionClosureRatePerYearWad = 0.10e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);

        in_.isLive = true;
        in_.isPolicyMode = false; // Open
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
    }

    function test_preview_zero_before_first_seed() public pure {
        Lib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = 2e18;
        in_.totalDetfSupply = 1e18;
        in_.lastExpansionTimestamp = 0; // not seeded
        in_.nowTimestamp = 1 days;
        in_.expansionEpochLength = 8 hours;
        in_.expansionClosureRatePerYearWad = 0.10e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
    }

    function test_preview_accrues_whole_epochs_only() public pure {
        Lib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = 2e18; // 100% premium
        in_.totalDetfSupply = 1_000e18;
        in_.lastExpansionTimestamp = 1_000_000;
        in_.expansionEpochLength = 8 hours;
        in_.expansionClosureRatePerYearWad = 0.10e18; // 10%/yr
        in_.expansionMaxCatchUpEpochs = 0;

        // Less than one epoch → 0
        in_.nowTimestamp = in_.lastExpansionTimestamp + 8 hours - 1;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);

        // Exactly one epoch
        in_.nowTimestamp = in_.lastExpansionTimestamp + 8 hours;
        uint256 one = Lib.previewPendingExpansionMint(in_);
        assertGt(one, 0);

        // Two epochs ≈ 2x
        in_.nowTimestamp = in_.lastExpansionTimestamp + 16 hours;
        uint256 two = Lib.previewPendingExpansionMint(in_);
        assertEq(two, one * 2);
    }

    function test_realize_seeds_clock_without_mint() public pure {
        Lib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = 5e18;
        in_.totalDetfSupply = 1e18;
        in_.lastExpansionTimestamp = 0;
        in_.nowTimestamp = 42;
        in_.expansionEpochLength = 8 hours;
        in_.expansionClosureRatePerYearWad = 4.4e18;

        (uint256 mint, uint256 newTs) = Lib.computeRealization(in_);
        assertEq(mint, 0);
        assertEq(newTs, 42);
    }

    function test_no_expansion_at_or_below_peg() public pure {
        Lib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = 1e18;
        in_.totalDetfSupply = 1e18;
        in_.lastExpansionTimestamp = 1000;
        in_.nowTimestamp = 1000 + 30 days;
        in_.expansionEpochLength = 8 hours;
        in_.expansionClosureRatePerYearWad = 4.4e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
    }
}
