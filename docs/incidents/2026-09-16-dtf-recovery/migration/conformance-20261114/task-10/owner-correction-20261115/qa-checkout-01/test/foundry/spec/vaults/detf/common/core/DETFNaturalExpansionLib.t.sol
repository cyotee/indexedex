// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DETFNaturalExpansionLib as Expansion} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";

/// @notice Balancer-specific floor order; shared across all four Balancer DETF families.
contract DETFNaturalExpansionLibTest is Test {
    function _input(uint256 elapsed_) private pure returns (Expansion.EpochInput memory) {
        return Expansion.EpochInput(true, true, 2e18, 1_000e9, 1_000, 1_000 + elapsed_, 1e12);
    }

    function test_hour25Settles24AndRetainsPartialEpoch() public pure {
        (uint256 amount_, uint256 boundary_) = Expansion.computeEpochExpansion(_input(25 hours));
        assertEq(amount_, 43_200e6);
        assertEq(boundary_, 1_000 + 24 hours);
    }

    function test_weekHasNoOneDayOrSupplyRelativeCap() public pure {
        (uint256 amount_, uint256 boundary_) = Expansion.computeEpochExpansion(_input(7 days));
        assertEq(amount_, 302_400e6);
        assertGt(amount_, 1_000e9 * 50 / 10_000);
        assertEq(boundary_, 1_000 + 7 days);
        (uint256 oneEpoch_,) = Expansion.computeEpochExpansion(_input(8 hours));
        assertEq(amount_, oneEpoch_ * 21);
    }

    function test_zeroEligibilityAdvancesBoundaryWithoutMint() public pure {
        Expansion.EpochInput memory input_ = _input(25 hours);
        input_.isMintAllowed = false;
        (uint256 amount_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(amount_, 0);
        assertEq(boundary_, 1_000 + 24 hours);
        input_.isMintAllowed = true;
        input_.syntheticPrice = 1e18;
        (amount_, boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(amount_, 0);
        assertEq(boundary_, 1_000 + 24 hours);
    }

    function test_inertClockDoesNotAccrue() public pure {
        Expansion.EpochInput memory input_ = _input(7 days);
        input_.isLive = false;
        (uint256 amount_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(amount_, 0);
        assertEq(boundary_, input_.lastSettledBoundary);
    }

    function test_sameBoundaryCannotBeConsumedTwice() public pure {
        Expansion.EpochInput memory input_ = _input(25 hours);
        (, input_.lastSettledBoundary) = Expansion.computeEpochExpansion(input_);
        (uint256 amount_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(amount_, 0);
        assertEq(boundary_, input_.lastSettledBoundary);
    }

    function testFuzz_catchUpPreservesBoundaryAndIncompleteTime(uint32 elapsed_) public pure {
        Expansion.EpochInput memory input_ = _input(elapsed_);
        (, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq((boundary_ - input_.lastSettledBoundary) % 8 hours, 0);
        assertLe(boundary_, input_.nowTimestamp);
        assertLt(input_.nowTimestamp - boundary_, 8 hours);
    }

    function test_defaultRateAndExplicitRatesResolveWithoutCaps() public pure {
        assertEq(Expansion.resolveClosureRate(0), uint256(1e17) / 365 days);
        assertEq(Expansion.resolveClosureRate(1), 1);
        assertEq(Expansion.resolveClosureRate(type(uint256).max), type(uint256).max);
    }

    function test_zeroSupplyConsumesCompletedEpochs() public pure {
        Expansion.EpochInput memory input_ = _input(25 hours); input_.totalDetfSupply = 0;
        (uint256 mint_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 0); assertEq(boundary_, 1_000 + 24 hours);
    }

    function test_zeroAndTinyRatesPreservePerSecondFloor() public pure {
        Expansion.EpochInput memory input_ = _input(8 hours); input_.closureRatePerSecond = 0;
        (uint256 mint_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 0); assertEq(boundary_, 1_000 + 8 hours);
        input_.closureRatePerSecond = 1; input_.totalDetfSupply = 1e24;
        (mint_, boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 500_000 * 8 hours); assertEq(boundary_, 1_000 + 8 hours);
    }

    function test_incompleteAndBackwardClockDoNotAccrue() public pure {
        Expansion.EpochInput memory input_ = _input(8 hours - 1);
        (uint256 mint_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 0); assertEq(boundary_, input_.lastSettledBoundary);
        input_.nowTimestamp = input_.lastSettledBoundary - 1;
        (mint_, boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 0); assertEq(boundary_, input_.lastSettledBoundary);
    }

    function test_largeSupplyUsesFullPrecisionWithoutProductOverflow() public pure {
        Expansion.EpochInput memory input_ = _input(7 days);
        input_.totalDetfSupply = uint256(1) << 200; input_.closureRatePerSecond = 1e18;
        (uint256 mint_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, (uint256(1) << 199) * 7 days);
        assertEq(boundary_, 1_000 + 7 days);
    }

    function test_nativeDustFloorsBeforeElapsedMultiplication() public pure {
        Expansion.EpochInput memory input_ = _input(8 hours);
        input_.totalDetfSupply = 3; input_.closureRatePerSecond = 1;
        (uint256 mint_, uint256 boundary_) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 0); assertEq(boundary_, 1_000 + 8 hours);
        input_.closureRatePerSecond = 1e18;
        (mint_,) = Expansion.computeEpochExpansion(input_);
        assertEq(mint_, 8 hours, "one native unit per second survives the first two floors");
    }
}
