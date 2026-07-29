// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @notice Mixed rated + unrated legs; unrated has no rateAsset redeem target.
contract MultiVaultWeightedDetf_MixedRated_Test is TestBase_MultiVaultWeightedDetf {
    function test_mixedRatedUnrated_mintBothLegs() public {
        address instance_ = _deployDetfNMixedRated(2, 0, 0, ThresholdMode.Open);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        address[] memory ras_ = info_.rateAssets();
        assertTrue(ras_[0] != address(0), "leg0 rated");
        assertEq(ras_[1], address(0), "leg1 unrated");

        _goLiveViaBptBond(instance_, alice, 700e18);

        uint256 m0_ = _mintOnLeg(instance_, 0, bob, 100e18);
        uint256 m1_ = _mintOnLeg(instance_, 1, bob, 100e18);
        assertTrue(m0_ > 0 && m1_ > 0, "both legs mint");

        uint256 burn0_ = m0_ / 2;
        if (burn0_ > 0) _burnToLeg(instance_, 0, bob, burn0_);
        uint256 burn1_ = IERC20(instance_).balanceOf(bob) / 2;
        if (burn1_ > 0) _burnToLeg(instance_, 1, bob, burn1_);
        _assertNoFreeInventory(instance_);
    }

    function test_mixed_claimRedeem_onlyRatedLeg() public {
        address instance_ = _deployDetfNMixedRated(2, 0, 0, ThresholdMode.Open);
        // Larger bootstrap so protocol BPT unwind stays above Balancer min token balances.
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 5_000e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);

        vm.prank(alice);
        uint256 minted_ = bonding_.sellNFT(tokenId_, alice);
        assertTrue(minted_ > 0, "claim minted");

        address rated_ = info_.rateAssets()[0];
        uint256 claimBal_ = IERC20(info_.rebasingClaimToken()).balanceOf(alice);
        // Redeem a small slice so proportional exit keeps Balancer min balances.
        uint256 redeemAmt_ = claimBal_ / 20;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        uint256 before_ = IERC20(rated_).balanceOf(alice);
        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(redeemAmt_, IERC20(rated_), 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "redeem rated");
        assertEq(IERC20(rated_).balanceOf(alice) - before_, out_, "payout");

        // Unrated leg has no rateAsset — zero address is invalid route for redeem
        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(1, IERC20(address(0)), 0, alice, block.timestamp + 1 hours);
    }
}
