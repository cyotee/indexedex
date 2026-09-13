// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

/// @title DETFFundedStakingMath
/// @notice Native nine-decimal staking, funded rebase and fixed-principal vesting arithmetic.
/// @dev Gons are internal units. Standing reward weights never create redeemable gons.
library DETFFundedStakingMath {
    uint256 internal constant INITIAL_GONS_PER_UNIT = 1e36;
    uint256 internal constant REWARD_SCALE = 1e54;
    uint256 internal constant WAD = 1e18;

    error InvalidGonsPerUnit();
    error MissingRewardWeight();
    error InvalidVestingDuration();
    error PrincipalAlreadyClaimed(uint256 claimed, uint256 vested);
    error UnfundedBondPrincipal(uint256 stakingValue, uint256 principalRemaining);

    /// @notice Actual DETF amounts assigned once by a funded distribution.
    struct RewardAllocation {
        uint256 staking;
        uint256 fee;
        uint256 creator;
        uint256 dust;
    }

    /// @notice Fixed purchase terms and current attributed staking inventory for one NFT.
    struct BondPosition {
        uint256 principal;
        uint256 claimedPrincipal;
        uint256 stakingGons;
        uint256 startTimestamp;
        uint256 vestingDuration;
    }

    /// @notice Native DETF-equivalent amounts; both claim amounts are paid in sDETF.
    struct BondClaim {
        uint256 vestedPrincipal;
        uint256 principalRemaining;
        uint256 principalDue;
        uint256 rewardsDue;
    }

    /// @notice Gons needed to credit or debit exactly the requested native sDETF amount.
    function _toGons(uint256 amount_, uint256 gonsPerUnit_) internal pure returns (uint256) {
        if (gonsPerUnit_ == 0) revert InvalidGonsPerUnit();
        return Math.mulDiv(amount_, gonsPerUnit_, 1);
    }

    /// @notice Conservatively rounded native amount attributable to these gons.
    function _toAmount(uint256 gons_, uint256 gonsPerUnit_) internal pure returns (uint256) {
        if (gonsPerUnit_ == 0) revert InvalidGonsPerUnit();
        return gons_ / gonsPerUnit_;
    }

    /// @notice Lower the gons-per-unit divisor only to the extent funded rewards permit.
    /// @dev Zero supply preserves the index and all funding as dust. No supply cap or reset.
    /// @return newGonsPerUnit_ Divisor after allocating the representable funded growth.
    /// @return distributed_ Increase in aggregate redeemable native units.
    /// @return dust_ Already allocated ordinary rewards retained for a later funded rebase.
    function _rebase(uint256 totalGons_, uint256 gonsPerUnit_, uint256 fundedReward_)
        internal
        pure
        returns (uint256 newGonsPerUnit_, uint256 distributed_, uint256 dust_)
    {
        uint256 liability_ = _toAmount(totalGons_, gonsPerUnit_);
        if (totalGons_ == 0 || fundedReward_ == 0) {
            return (gonsPerUnit_, 0, fundedReward_);
        }
        uint256 target_ = liability_ + fundedReward_;
        newGonsPerUnit_ = Math.ceilDiv(totalGons_, target_);
        distributed_ = totalGons_ / newGonsPerUnit_ - liability_;
        dust_ = fundedReward_ - distributed_;
    }

    /// @notice Preserve weight-based reward-per-share floor allocation in gons precision.
    /// @dev All reward_ must already be funded. The three allocations and dust sum to it.
    function _allocate(uint256 reward_, uint256 ordinaryGons_, uint256 feeWeight_, uint256 creatorWeight_)
        internal
        pure
        returns (RewardAllocation memory allocation_)
    {
        uint256 totalWeight_ = ordinaryGons_ + feeWeight_ + creatorWeight_;
        if (totalWeight_ == 0) {
            if (reward_ != 0) revert MissingRewardWeight();
            return allocation_;
        }
        uint256 rewardPerShare_ = Math.mulDiv(reward_, REWARD_SCALE, totalWeight_);
        allocation_.staking = Math.mulDiv(ordinaryGons_, rewardPerShare_, REWARD_SCALE);
        allocation_.fee = Math.mulDiv(feeWeight_, rewardPerShare_, REWARD_SCALE);
        allocation_.creator = Math.mulDiv(creatorWeight_, rewardPerShare_, REWARD_SCALE);
        allocation_.dust = reward_ - allocation_.staking - allocation_.fee - allocation_.creator;
    }

    /// @notice Quote vested principal and independent funded rewards without changing the clock.
    function _claim(BondPosition memory position_, uint256 timestamp_, uint256 gonsPerUnit_)
        internal
        pure
        returns (BondClaim memory claim_)
    {
        if (position_.vestingDuration == 0) revert InvalidVestingDuration();
        uint256 elapsed_ = timestamp_ > position_.startTimestamp ? timestamp_ - position_.startTimestamp : 0;
        claim_.vestedPrincipal = elapsed_ >= position_.vestingDuration
            ? position_.principal
            : Math.mulDiv(position_.principal, elapsed_, position_.vestingDuration);
        if (position_.claimedPrincipal > claim_.vestedPrincipal) {
            revert PrincipalAlreadyClaimed(position_.claimedPrincipal, claim_.vestedPrincipal);
        }
        claim_.principalRemaining = position_.principal - position_.claimedPrincipal;
        claim_.principalDue = claim_.vestedPrincipal - position_.claimedPrincipal;
        uint256 stakingValue_ = _toAmount(position_.stakingGons, gonsPerUnit_);
        if (stakingValue_ < claim_.principalRemaining) {
            revert UnfundedBondPrincipal(stakingValue_, claim_.principalRemaining);
        }
        claim_.rewardsDue = stakingValue_ - claim_.principalRemaining;
    }

    /// @notice WAD conversion from one native static SY unit to its funded DETF entitlement.
    function _syExchangeRate(uint256 gonsPerUnit_) internal pure returns (uint256) {
        if (gonsPerUnit_ == 0) revert InvalidGonsPerUnit();
        return Math.mulDiv(INITIAL_GONS_PER_UNIT, WAD, gonsPerUnit_);
    }
}
