// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DETFEpochNaturalExpansionLib as Lib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";

/// @notice One canonical suite for fixed boundaries and uncapped aggregate catch-up.
contract DETFEpochNaturalExpansionLibTest is Test {
    function _input() private pure returns (Lib.AccrualInput memory in_) {
        in_.isLive = true;
        in_.spotSyntheticPrice = 2e18;
        in_.mintThreshold = 1.05e18;
        in_.totalDetfSupply = 1_000e9;
        in_.lastExpansionTimestamp = 1_000_000;
        in_.nowTimestamp = in_.lastExpansionTimestamp + 8 hours;
        in_.expansionClosureRatePerYearWad = 0.1e18;
    }

    function test_fixedEpochAndRetainedRateDefault() public pure {
        assertEq(Lib.EPOCH, 8 hours);
        assertEq(Lib.resolveClosureRate(0), 0.1e18);
        assertEq(Lib.resolveClosureRate(0.25e18), 0.25e18);
    }

    function test_inertDoesNotStartClock() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.isLive = false;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertEq(minted_, 0);
        assertEq(boundary_, in_.lastExpansionTimestamp);
    }

    function test_hour25Settles24AndPreservesNextBoundary() public pure {
        Lib.AccrualInput memory in_ = _input();
        uint256 one_ = Lib.previewPendingExpansionMint(in_);
        in_.nowTimestamp = in_.lastExpansionTimestamp + 25 hours;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertGt(one_, 0);
        assertEq(minted_, one_ * 3);
        assertEq(boundary_, in_.lastExpansionTimestamp + 24 hours);
        assertEq(boundary_ + Lib.EPOCH, in_.lastExpansionTimestamp + 32 hours);
    }

    function test_sevenDaysIncludesAll21EpochsWithoutCompounding() public pure {
        Lib.AccrualInput memory in_ = _input();
        uint256 one_ = Lib.previewPendingExpansionMint(in_);
        in_.nowTimestamp = in_.lastExpansionTimestamp + 7 days;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertEq(minted_, 21 * one_);
        assertEq(boundary_, in_.nowTimestamp);
    }

    function test_zeroEligibilityStillConsumesAllCompletedBoundaries() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.spotSyntheticPrice = 1e18;
        in_.nowTimestamp = in_.lastExpansionTimestamp + 25 hours;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertEq(minted_, 0);
        assertEq(boundary_, in_.lastExpansionTimestamp + 24 hours);
        in_.lastExpansionTimestamp = boundary_;
        in_.spotSyntheticPrice = 2e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
    }

    function test_zeroTimestampCanBeFirstBondAnchor() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.lastExpansionTimestamp = 0;
        in_.nowTimestamp = 8 hours;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertGt(minted_, 0);
        assertEq(boundary_, 8 hours);
    }

    function test_strictConfiguredMintThreshold() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.mintThreshold = 1.2e18;
        in_.spotSyntheticPrice = in_.mintThreshold - 1;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
        in_.spotSyntheticPrice = in_.mintThreshold;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
        in_.spotSyntheticPrice += 1;
        assertGt(Lib.previewPendingExpansionMint(in_), 0);
    }

    function test_deadbandConsumesEpochWithoutRetroactiveExpansion() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.spotSyntheticPrice = 1.025e18;
        in_.nowTimestamp += 17 hours;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertEq(minted_, 0);
        assertEq(boundary_, in_.lastExpansionTimestamp + 24 hours);
        in_.lastExpansionTimestamp = boundary_;
        in_.spotSyntheticPrice = 2e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
        in_.nowTimestamp = boundary_ + 8 hours;
        assertGt(Lib.previewPendingExpansionMint(in_), 0);
    }

    function test_belowPegThresholdCannotProduceNegativePremium() public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.mintThreshold = 0.9e18;
        in_.spotSyntheticPrice = 0.95e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
        in_.spotSyntheticPrice = 1e18;
        assertEq(Lib.previewPendingExpansionMint(in_), 0);
    }

    function testFuzz_thresholdAndUnchangedRounding(
        uint64 priceSeed_,
        uint64 thresholdSeed_,
        uint64 supplySeed_,
        uint16 epochsSeed_
    ) public pure {
        Lib.AccrualInput memory in_ = _input();
        in_.spotSyntheticPrice = uint256(priceSeed_) + 1;
        in_.mintThreshold = thresholdSeed_;
        in_.totalDetfSupply = supplySeed_;
        uint256 epochs_ = uint256(epochsSeed_) + 1;
        in_.nowTimestamp = in_.lastExpansionTimestamp + epochs_ * 8 hours + 123;
        uint256 expected_;
        if (in_.spotSyntheticPrice > in_.mintThreshold && in_.spotSyntheticPrice > 1e18) {
            uint256 premiumSupply_ = in_.totalDetfSupply * (in_.spotSyntheticPrice - 1e18) / in_.spotSyntheticPrice;
            uint256 perEpochRate_ = in_.expansionClosureRatePerYearWad * 8 hours / 365 days;
            expected_ = (premiumSupply_ * perEpochRate_ / 1e18) * epochs_;
            if (expected_ <= 1) expected_ = 0;
        }
        assertEq(Lib.previewPendingExpansionMint(in_), expected_);
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertEq(minted_, expected_);
        assertEq(boundary_, in_.lastExpansionTimestamp + epochs_ * 8 hours);
    }

    function testFuzz_boundaryRemainderAndSingleSettlement(uint32 elapsed_) public pure {
        Lib.AccrualInput memory in_ = _input();
        uint256 anchor_ = in_.lastExpansionTimestamp;
        in_.nowTimestamp = anchor_ + elapsed_;
        (uint256 minted_, uint256 boundary_) = Lib.computeRealization(in_);
        assertLe(boundary_, in_.nowTimestamp);
        assertLt(in_.nowTimestamp - boundary_, Lib.EPOCH);
        assertEq((boundary_ - anchor_) % Lib.EPOCH, 0);
        in_.lastExpansionTimestamp = boundary_;
        (uint256 repeated_, uint256 repeatedBoundary_) = Lib.computeRealization(in_);
        assertEq(repeated_, 0);
        assertEq(repeatedBoundary_, boundary_);
        if (elapsed_ < Lib.EPOCH) assertEq(minted_, 0);
    }
}
