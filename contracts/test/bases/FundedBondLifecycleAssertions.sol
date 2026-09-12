// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

interface IFundedBondInstance {
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (IERC20);
}

/// @notice Shared lifecycle assertions exercised against registry-deployed funded bonds.
abstract contract FundedBondLifecycleAssertions is Test {
    function _assertBondPrincipalIsFunded(address instance_, uint256 id_, address buyer_) internal view {
        IDetfBondNFT nft_ = IDetfBondNFT(IFundedBondInstance(instance_).bondNftVault());
        IStakedDETF staking_ = IStakedDETF(address(IFundedBondInstance(instance_).rebasingClaimToken()));
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        assertGt(position_.principal, 0, "fixed funded principal");
        assertEq(position_.claimedPrincipal, 0);
        assertEq(nft_.ownerOf(id_), buyer_);
        assertGe(staking_.balanceOf(address(nft_)), position_.principal, "principal held as staked DETF");
        assertGe(IERC20(instance_).balanceOf(address(staking_)), staking_.totalSupply(), "all receipts backed");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), 0, "reserve LP remains in protocol custody");
        assertEq(IERC20(instance_).balanceOf(buyer_), 0, "bond purchase pays no free raw DETF");
    }

    function _assertBondPrincipalStillLocked(address instance_, uint256 id_, address buyer_) internal {
        IDetfBondNFT nft_ = IDetfBondNFT(IFundedBondInstance(instance_).bondNftVault());
        Math.BondPosition memory before_ = nft_.positionOf(id_);
        assertEq(block.timestamp, before_.startTimestamp, "newly purchased position");
        vm.prank(buyer_);
        assertEq(nft_.claimPrincipal(id_, buyer_), 0, "no principal vested at purchase");
        assertEq(nft_.positionOf(id_).principal, before_.principal);
        assertEq(nft_.positionOf(id_).claimedPrincipal, 0);
        assertEq(nft_.ownerOf(id_), buyer_, "position remains live");
    }

    function _assertBondPartialVesting(address instance_, uint256 id_, address buyer_) internal {
        IDetfBondNFT nft_ = IDetfBondNFT(IFundedBondInstance(instance_).bondNftVault());
        IStakedDETF staking_ = IStakedDETF(address(IFundedBondInstance(instance_).rebasingClaimToken()));
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 elapsed_ = position_.vestingDuration / 2;
        vm.warp(position_.startTimestamp + elapsed_);
        IDETFFundedRewards(instance_).synchronizeRewards();
        uint256 before_ = staking_.balanceOf(buyer_);
        uint256 expected_ = position_.principal * elapsed_ / position_.vestingDuration;
        assertGt(expected_, 0, "representable vested principal");
        vm.prank(buyer_);
        assertEq(nft_.claimPrincipal(id_, buyer_), expected_);
        assertEq(staking_.balanceOf(buyer_), before_ + expected_);
        assertEq(nft_.positionOf(id_).principal, position_.principal, "purchase principal stays fixed");
        assertEq(nft_.positionOf(id_).claimedPrincipal, expected_);
        assertEq(nft_.ownerOf(id_), buyer_, "unvested principal remains owned");
        vm.prank(buyer_);
        assertEq(nft_.claimPrincipal(id_, buyer_), 0, "same vested principal cannot be claimed twice");
    }

    function _assertBondMaturePreviewEqualsPayment(address instance_, uint256 id_, address buyer_) internal {
        IDetfBondNFT nft_ = IDetfBondNFT(IFundedBondInstance(instance_).bondNftVault());
        IStakedDETF staking_ = IStakedDETF(address(IFundedBondInstance(instance_).rebasingClaimToken()));
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        IDETFFundedRewards(instance_).synchronizeRewards();
        Math.BondClaim memory quote_ = nft_.previewClaim(id_);
        uint256 before_ = staking_.balanceOf(buyer_);
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        vm.prank(buyer_);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, buyer_);
        assertEq(principal_, position_.principal - position_.claimedPrincipal);
        assertEq(principal_, quote_.principalDue, "principal preview equals payment");
        assertEq(rewards_, quote_.rewardsDue, "funded reward preview equals payment");
        assertEq(staking_.balanceOf(buyer_), before_ + principal_ + rewards_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_, "bond payout cannot withdraw reserve LP");
        assertEq(nft_.ownerOf(id_), address(0), "fully paid position retired");
    }

    function _fundedBondStaking(address instance_) internal view returns (IStakedDETF) {
        return IStakedDETF(address(IFundedBondInstance(instance_).rebasingClaimToken()));
    }

    function _assertFundedUnstake(address instance_, address holder_, uint256 amount_) internal {
        IStakedDETF staking_ = _fundedBondStaking(instance_);
        IDetfBondNFT nft_ = IDetfBondNFT(IFundedBondInstance(instance_).bondNftVault());
        uint256 balance_ = staking_.balanceOf(holder_);
        uint256 raw_ = IERC20(instance_).balanceOf(holder_);
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        assertGt(amount_, 0, "nonzero funded redemption");
        assertEq(staking_.previewExchangeIn(IERC20(address(staking_)), amount_, IERC20(instance_)), amount_);
        vm.prank(holder_);
        assertEq(
            staking_.exchangeIn(
                IERC20(address(staking_)), amount_, IERC20(instance_), amount_, holder_, false, block.timestamp
            ),
            amount_
        );
        assertEq(staking_.balanceOf(holder_), balance_ - amount_);
        assertEq(IERC20(instance_).balanceOf(holder_), raw_ + amount_);
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_ - amount_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_, "unstaking uses funded DETF, not reserve LP");
    }

    function _assertFundedUnstakeRejected(
        address instance_,
        address holder_,
        uint256 amount_,
        IERC20 output_,
        uint256 minimum_
    ) internal {
        IStakedDETF staking_ = _fundedBondStaking(instance_);
        uint256 gons_ = staking_.gonsOf(holder_);
        uint256 raw_ = IERC20(instance_).balanceOf(holder_);
        uint256 backing_ = IERC20(instance_).balanceOf(address(staking_));
        vm.prank(holder_);
        vm.expectRevert();
        staking_.exchangeIn(IERC20(address(staking_)), amount_, output_, minimum_, holder_, false, block.timestamp);
        assertEq(staking_.gonsOf(holder_), gons_, "failed unstake preserves exact entitlement");
        assertEq(IERC20(instance_).balanceOf(holder_), raw_, "failed unstake pays nothing");
        assertEq(IERC20(instance_).balanceOf(address(staking_)), backing_, "failed unstake preserves backing");
    }
}
