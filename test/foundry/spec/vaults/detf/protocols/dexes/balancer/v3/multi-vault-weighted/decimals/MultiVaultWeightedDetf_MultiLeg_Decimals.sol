// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiVaultWeightedDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfDFPkg.sol";

import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

import {
    TestBase_MultiVaultWeightedDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    ILegacyMultiVaultWeightedDetfBonding as IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    ILegacyMultiVaultWeightedDetfInfo as IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Multi-leg mint/burn/claim matrix: N=2..3 lifecycle; same/disparate rateAssets; each leg.
abstract contract MultiVaultWeightedDetf_MultiLeg_Decimals is
    TestBase_MultiVaultWeightedDetf_Decimals,
    FundedBondLifecycleAssertions
{
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

    function test_n2_disparateRateAssets_fundedBondPayout() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(2, 0, 0, true);
        args_.rateAssets[1] = IERC20(address(restToken));
        address instance_ = _deployWithArgs(args_);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 1_000e18);
        address[] memory rates_ = IMultiVaultWeightedDetfInfo(instance_).rateAssets();
        assertTrue(rates_[0] != rates_[1], "disparate rate assets");
        _assertBondMaturePreviewEqualsPayment(instance_, tokenId_, alice);
        _assertFundedUnstake(instance_, alice, _fundedBondStaking(instance_).balanceOf(alice) / 10);
        _assertNoFreeInventory(instance_);
    }

    function test_n2_sameRateAsset_distinctLegs_fundedBondPayout() public {
        address instance_ = _deployDetfN2SameRateAsset(0, 0, ThresholdMode.Open);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 900e18);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        address[] memory vaults_ = info_.underlyingVaults();
        assertTrue(vaults_[0] != vaults_[1], "distinct vaults");
        address[] memory rates_ = info_.rateAssets();
        assertEq(rates_[0], rates_[1], "shared rate asset");
        assertTrue(rates_[0] != address(0));
        assertGt(_mintOnLeg(instance_, 0, bob, 120e18), 0);
        assertGt(_mintOnLeg(instance_, 1, bob, 120e18), 0);
        _assertBondMaturePreviewEqualsPayment(instance_, tokenId_, alice);
        _assertFundedUnstake(instance_, alice, _fundedBondStaking(instance_).balanceOf(alice) / 10);
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
            (uint256 tokenId_, uint256 principal_) = IMultiVaultWeightedDetfBonding(instance_)
                .bond(IERC20(share_), shares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
            vm.stopPrank();
            assertTrue(tokenId_ > 0 && principal_ > 0, "share bond");
        }
    }
}
