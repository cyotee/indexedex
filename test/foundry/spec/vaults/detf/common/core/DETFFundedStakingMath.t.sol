// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @title DETFFundedStakingMathTest
/// @notice Common arithmetic coverage shared by every funded DETF integration.
contract DETFFundedStakingMathTest is Test {
    uint256 internal constant K = 1e36;

    /// @notice A depositor's exact raw principal survives non-unit indexes and account dust.
    function testFuzz_exactPrincipalCreditAndDebit(uint128 amount_, uint96 divisor_, uint96 residue_) public pure {
        uint256 k_ = uint256(divisor_) + 1;
        uint256 prior_ = uint256(residue_);
        uint256 credit_ = StakingMath._toGons(amount_, k_);
        assertEq(StakingMath._toAmount(prior_ + credit_, k_) - StakingMath._toAmount(prior_, k_), amount_);
        assertEq(StakingMath._toAmount(credit_, k_), amount_);
        assertEq(prior_ + credit_ - StakingMath._toGons(amount_, k_), prior_);
    }

    /// @notice A funded rebase conserves the reward and never reduces any unchanged position.
    function testFuzz_fundedRebaseConservation(uint128 gons_, uint96 divisor_, uint96 reward_, uint128 holderSeed_)
        public
        pure
    {
        uint256 k_ = uint256(divisor_) + 1;
        (uint256 next_, uint256 distributed_, uint256 dust_) = StakingMath._rebase(gons_, k_, reward_);
        assertLe(next_, k_);
        assertGt(next_, 0);
        assertEq(distributed_ + dust_, reward_);
        assertEq(uint256(gons_) / next_ - uint256(gons_) / k_, distributed_);
        uint256 holder_ = uint256(holderSeed_) % (uint256(gons_) + 1);
        assertGe(holder_ / next_, holder_ / k_);
    }

    /// @notice Tiny funded amounts that cannot change the divisor remain accounted dust.
    function test_rebaseQuantizationDoesNotOverissue() public pure {
        (uint256 next_, uint256 distributed_, uint256 dust_) = StakingMath._rebase(101, 10, 1);
        assertEq(next_, 10);
        assertEq(distributed_, 0);
        assertEq(dust_, 1);
        (next_, distributed_, dust_) = StakingMath._rebase(101, 10, 2);
        assertEq(next_, 9);
        assertEq(distributed_, 1);
        assertEq(dust_, 1);
    }

    /// @notice Empty supply and zero funding preserve the previously funded index.
    function test_emptyAndUnfundedRebasePreserveIndex() public pure {
        (uint256 next_, uint256 distributed_, uint256 dust_) = StakingMath._rebase(0, K / 2, 17);
        assertEq(next_, K / 2);
        assertEq(distributed_, 0);
        assertEq(dust_, 17);
        (next_, distributed_, dust_) = StakingMath._rebase(K + 1, K, 0);
        assertEq(next_, K);
        assertEq(distributed_, 0);
        assertEq(dust_, 0);
    }

    /// @notice The full distribution funds either ordinary growth, fee receipts or explicit dust.
    function test_allocationWorkedExample() public pure {
        StakingMath.RewardAllocation memory a_ = StakingMath._allocate(100e9, 85e9 * K, 10e9 * K, 5e9 * K);
        assertEq(a_.staking, 85e9);
        assertEq(a_.fee, 10e9);
        assertEq(a_.creator, 5e9);
        assertEq(a_.dust, 0);
    }

    /// @notice Standing weights continue to receive rewards after every ordinary position exits.
    function test_standingWeightsOnlyDistributeWholePot() public pure {
        StakingMath.RewardAllocation memory a_ = StakingMath._allocate(100e9, 0, 2 * K, K);
        assertEq(a_.staking, 0);
        assertEq(a_.fee, 66_666_666_666);
        assertEq(a_.creator, 33_333_333_333);
        assertEq(a_.dust, 1);
    }

    /// @notice Independent category floors cannot create unfunded receipts.
    function testFuzz_allocationConservation(uint96 reward_, uint96 ordinary_, uint96 fee_, uint96 creator_)
        public
        pure
    {
        StakingMath.RewardAllocation memory a_ =
            StakingMath._allocate(reward_, uint256(ordinary_) + K, uint256(fee_) + K, uint256(creator_) + K);
        assertEq(a_.staking + a_.fee + a_.creator + a_.dust, reward_);
    }

    /// @notice The accepted halfway example separates claimable principal from independent yield.
    function test_halfwayPrincipalAndRewardClaims() public pure {
        StakingMath.BondPosition memory p_ = StakingMath.BondPosition(100e9, 0, 110e9 * K, 1_000, 100);
        StakingMath.BondClaim memory c_ = StakingMath._claim(p_, 1_050, K);
        assertEq(c_.principalDue, 50e9);
        assertEq(c_.rewardsDue, 10e9);
        assertEq(c_.principalRemaining, 100e9);

        p_.stakingGons -= c_.rewardsDue * K;
        c_ = StakingMath._claim(p_, 1_050, K);
        assertEq(c_.principalDue, 50e9);
        assertEq(c_.rewardsDue, 0);
        assertEq(c_.principalRemaining, 100e9);

        p_.stakingGons -= c_.principalDue * K;
        p_.claimedPrincipal += c_.principalDue;
        c_ = StakingMath._claim(p_, 1_050, K);
        assertEq(c_.principalDue, 0);
        assertEq(c_.rewardsDue, 0);
        assertEq(c_.principalRemaining, 50e9);
        c_ = StakingMath._claim(p_, 1_100, K);
        assertEq(c_.principalDue, 50e9);
    }

    /// @notice The final raw principal unit vests fully at maturity despite intermediate floors.
    function test_linearVestingFloorsAndFinalUnit() public pure {
        StakingMath.BondPosition memory p_ = StakingMath.BondPosition(7, 0, 7 * K, 100, 3);
        assertEq(StakingMath._claim(p_, 99, K).principalDue, 0);
        assertEq(StakingMath._claim(p_, 100, K).principalDue, 0);
        assertEq(StakingMath._claim(p_, 101, K).principalDue, 2);
        assertEq(StakingMath._claim(p_, 102, K).principalDue, 4);
        assertEq(StakingMath._claim(p_, 103, K).principalDue, 7);
        assertEq(StakingMath._claim(p_, type(uint256).max, K).principalDue, 7);
    }

    /// @notice A deficit must be surfaced rather than hidden as zero reward.
    function test_principalDeficitReverts() public {
        vm.expectRevert(abi.encodeWithSelector(StakingMath.UnfundedBondPrincipal.selector, 99, 100));
        this.quoteClaim(StakingMath.BondPosition(100, 0, 99 * K, 100, 100), 150, K);
    }

    /// @notice A static wrapper rate increases with a funded staking index, in raw units.
    function test_staticSyRateUsesFundedIndex() public pure {
        assertEq(StakingMath._syExchangeRate(K), 1e18);
        assertEq(StakingMath._syExchangeRate(K / 2), 2e18);
        assertEq(StakingMath._syExchangeRate(K / 4), 4e18);
    }

    /// @notice External call boundary for checking the production library's revert data.
    function quoteClaim(StakingMath.BondPosition memory position_, uint256 timestamp_, uint256 divisor_)
        external
        pure
        returns (StakingMath.BondClaim memory)
    {
        return StakingMath._claim(position_, timestamp_, divisor_);
    }
}
