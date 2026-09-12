// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

import {
    TestBase_MultiVaultWeightedDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    ILegacyMultiVaultWeightedDetfInfo as IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    ILegacyMultiVaultWeightedDetfBonding as IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Mixed rated + unrated legs; unrated has no rateAsset redeem target.
abstract contract MultiVaultWeightedDetf_MixedRated_Decimals is
    TestBase_MultiVaultWeightedDetf_Decimals,
    FundedBondLifecycleAssertions
{
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

    function test_mixedRated_bondPayout_unstakesOneToOne() public {
        address instance_ = _deployDetfNMixedRated(2, 0, 0, ThresholdMode.Open);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 5_000e18);
        address[] memory rateAssets_ = IMultiVaultWeightedDetfInfo(instance_).rateAssets();
        assertTrue(rateAssets_[0] != address(0));
        assertEq(rateAssets_[1], address(0));
        _assertBondMaturePreviewEqualsPayment(instance_, tokenId_, alice);
        uint256 amount_ = _fundedBondStaking(instance_).balanceOf(alice) / 20;
        _assertFundedUnstake(instance_, alice, amount_);
        _assertFundedUnstakeRejected(instance_, alice, 1, IERC20(address(0)), 0);
    }
}
