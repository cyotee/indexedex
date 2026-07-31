// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Multi-leg mint/burn/claim matrix: N=2..3 lifecycle; same/disparate rateAssets; each leg.
contract MultiVaultWeightedDetf_MultiLeg_Test is TestBase_MultiVaultWeightedDetf {
    function test_n2_mintBurn_eachLeg() public {
        address instance_ = _deployOpenThresholdDetfN(2);
        _goLiveViaBptBond(instance_, alice, 800e18);

        uint256 n_ = IMultiVaultWeightedDetfInfo(instance_).vaultCount();
        assertEq(n_, 2);

        for (uint8 leg; leg < 2; ++leg) {
            uint256 out_ = _mintOnLeg(instance_, leg, bob, 150e18);
            assertTrue(out_ > 0, "minted on leg");
            uint256 bal_ = IERC20(instance_).balanceOf(bob);
            uint256 burnAmt_ = bal_ / 2;
            if (burnAmt_ == 0) burnAmt_ = bal_;
            uint256 burned_ = _burnToLeg(instance_, leg, bob, burnAmt_);
            assertTrue(burned_ > 0, "burned to leg");
            _assertNoFreeInventory(instance_);
        }
    }

    function test_n3_mintBurn_eachLeg() public {
        address instance_ = _deployOpenThresholdDetfN(3);
        _goLiveViaBptBond(instance_, alice, 600e18);

        for (uint8 leg; leg < 3; ++leg) {
            uint256 out_ = _mintOnLeg(instance_, leg, bob, 100e18);
            assertTrue(out_ > 0, "n3 mint");
            uint256 burnAmt_ = IERC20(instance_).balanceOf(bob) / 3;
            if (burnAmt_ == 0) burnAmt_ = IERC20(instance_).balanceOf(bob);
            if (burnAmt_ > 0) {
                _burnToLeg(instance_, leg, bob, burnAmt_);
            }
            _assertNoFreeInventory(instance_);
        }
    }

    function test_n2_disparateRateAssets_claimRedeem_each() public {
        // rated legs: rateAsset0=dai, rateAsset1=weth
        address instance_ = _deployDetfN(2, 0, 0, true, ThresholdMode.Open);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 1_000e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        address[] memory ras_ = info_.rateAssets();
        assertTrue(ras_[0] != ras_[1], "disparate rate assets");

        vm.prank(alice);
        uint256 claimMinted_ = bonding_.sellNFT(tokenId_, alice);
        assertTrue(claimMinted_ > 0, "claim minted");

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(alice);
        assertTrue(claimBal_ > 0, "claim bal");

        // Redeem half to rateAsset[0], half to rateAsset[1] when both rated.
        uint256 half_ = claimBal_ / 2;
        if (half_ == 0) half_ = claimBal_;

        uint256 before0_ = IERC20(ras_[0]).balanceOf(alice);
        vm.prank(alice);
        uint256 out0_ = bonding_.redeemClaim(half_, IERC20(ras_[0]), 0, alice, block.timestamp + 1 hours);
        assertTrue(out0_ > 0, "redeem to rateAsset0");
        assertEq(IERC20(ras_[0]).balanceOf(alice) - before0_, out0_, "rateAsset0 received");

        uint256 remain_ = claim_.balanceOf(alice);
        if (remain_ > 0 && ras_[1] != address(0)) {
            uint256 before1_ = IERC20(ras_[1]).balanceOf(alice);
            vm.prank(alice);
            uint256 out1_ = bonding_.redeemClaim(remain_, IERC20(ras_[1]), 0, alice, block.timestamp + 1 hours);
            assertTrue(out1_ > 0, "redeem to rateAsset1");
            assertEq(IERC20(ras_[1]).balanceOf(alice) - before1_, out1_, "rateAsset1 received");
        }
        _assertNoFreeInventory(instance_);
    }

    function test_n2_sameRateAsset_twoDistinctLegs_claimRedeem() public {
        address instance_ = _deployDetfN2SameRateAsset(0, 0, ThresholdMode.Open);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 900e18);

        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        address[] memory vaults_ = info_.underlyingVaults();
        assertTrue(vaults_[0] != vaults_[1], "distinct vaults");
        address[] memory ras_ = info_.rateAssets();
        assertEq(ras_[0], ras_[1], "same rateAsset address");
        assertEq(ras_[0], address(dai), "both dai-rated");

        // Mint on each leg
        _mintOnLeg(instance_, 0, bob, 120e18);
        _mintOnLeg(instance_, 1, bob, 120e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        vm.prank(alice);
        uint256 minted_ = bonding_.sellNFT(tokenId_, alice);
        assertTrue(minted_ > 0, "claim");

        uint256 claimBal_ = IRebasingClaimToken(info_.rebasingClaimToken()).balanceOf(alice);
        uint256 before_ = dai.balanceOf(alice);
        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(claimBal_, dai, 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "redeem same rateAsset");
        assertEq(dai.balanceOf(alice) - before_, out_, "dai payout");
        _assertNoFreeInventory(instance_);
    }

    function test_n2_bondVaultShare_eachLeg_afterLive() public {
        address instance_ = _deployOpenThresholdDetfN(2);
        _goLiveViaBptBond(instance_, alice, 700e18);

        for (uint8 leg; leg < 2; ++leg) {
            uint256 shares_ = _fundSharesForInstanceLeg(instance_, leg, bob, 100e18);
            address share_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[leg];
            vm.startPrank(bob);
            IERC20(share_).approve(instance_, shares_);
            (uint256 tokenId_, uint256 principal_) = IMultiVaultWeightedDetfBonding(instance_).bond(
                IERC20(share_), shares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
            assertTrue(tokenId_ > 0 && principal_ > 0, "share bond");
        }
    }
}
