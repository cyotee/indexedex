// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReferenceTest[]
/// @notice Executable arithmetic witnesses for open Gate A, not a deployed-vault security proof.
/// @dev No production issuance helper is implemented until the owner ratifies recovery ownership.
contract UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReferenceTest is Test {
    /// @notice Entering at depressed realizable value shares recovery of pre-existing opposing inventory.
    function test_witnessPositiveValueRecoveryParticipation() public pure {
        uint256 supply = 100;
        uint256 beforeValue = 100;
        uint256 contribution = 100;
        uint256 minted = supply * contribution / beforeValue;
        assertEq(minted, 100);
        uint256 afterRecovery = beforeValue + contribution + 100;
        uint256 entrantEntitlement = minted * afterRecovery / (supply + minted);
        uint256 incumbentEntitlement = supply * afterRecovery / (supply + minted);
        assertEq(entrantEntitlement, 150);
        assertEq(incumbentEntitlement, 150);
        assertEq(entrantEntitlement + incumbentEntitlement, afterRecovery);
        assertEq(200 - incumbentEntitlement, 50, "recovery participation transferred to entrant");
    }

    /// @notice Placement loss breaks the shortcut from value growth to isolated token credit.
    function test_witnessPlacementLossBreaksCreditEquivalence() public pure {
        uint256 growthMint = uint256(1000) * (1098 - 1000) / 1000;
        uint256 creditMint = uint256(1000) * 100 / 1000;
        assertEq(growthMint, 98);
        assertEq(creditMint, 100);
        assertLt(uint256(1098) * 1000, uint256(1000) * (1000 + creditMint));
        assertEq(uint256(1098) * 1000, uint256(1000) * (1000 + growthMint));
    }

    /// @notice Recovery enabled by new placement can exceed the actual caller contribution.
    function test_witnessContributionEnabledRecovery() public pure {
        uint256 mint = uint256(1000) * (1150 - 1000) / 1000;
        assertEq(mint, 150);
        assertGt(mint, 100, "growth candidate allocates recovery-enabled growth to entrant");
    }

    /// @notice A virtual positive denominator is an ownership policy, not algebra for the zero-V candidate.
    function test_witnessZeroValueHasNoDefinedCandidate() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x12)));
        this.candidate(100, 0, 100);
    }

    /// @notice Owner ruling O3 assigns pre-existing realizable residuals to the first depositor.
    function test_bootstrapResidualBelongsToFirstDepositor() public pure {
        uint256 donated = 100;
        uint256 contributed = 100;
        uint256 issuedShares = contributed;
        uint256 callerEntitlement = (donated + contributed) * issuedShares / issuedShares;
        assertEq(callerEntitlement, 200);
        assertEq(callerEntitlement - contributed, donated);
    }

    /// @notice The candidate's algebra preserves same-state V/share before unmodeled costs, but says nothing about recovery.
    function testFuzz_growthCandidatePerShare(uint64 supplySeed_, uint64 valueSeed_, uint64 growth_) public pure {
        uint256 supply = uint256(supplySeed_) + 1;
        uint256 value = uint256(valueSeed_) + 1;
        uint256 minted = supply * growth_ / value;
        assertGe((value + growth_) * supply, value * (supply + minted));
    }

    /// @notice Bounded test-local arithmetic only, intentionally retaining division-by-zero failure.
    function candidate(uint64 supply_, uint64 before_, uint64 after_) external pure returns (uint256) {
        return uint256(supply_) * (uint256(after_) - before_) / before_;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultAccountingReferenceTest[]
