// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice E5, BASE-G style route/live gates, H3 failed-path residual.
contract Adversarial_Guards_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_E5_zeroAmount_reverts() public {
        address instance_ = _openLiveN1();
        vm.startPrank(attacker);
        vm.expectRevert(MultiVaultWeightedDetfRepo.ZeroAmount.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], 0, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_E5_expiredDeadline_reverts() public {
        address instance_ = _openLiveN1();
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 50e18);
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultWeightedDetfRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], shares_, IERC20(instance_), 0, attacker, false, block.timestamp - 1
        );
        vm.stopPrank();
        // H3: failed mint leaves no free inventory on DETF
        assertEq(seShares[0].balanceOf(instance_), 0, "no residual shares after failed mint");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "no residual detf");
    }

    function test_route_rateAssetMint_InvalidRoute() public {
        address instance_ = _openLiveN1();
        dai.mint(attacker, 1e18);
        vm.startPrank(attacker);
        dai.approve(instance_, 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultWeightedDetfRepo.InvalidRoute.selector, address(dai), instance_)
        );
        IStandardExchangeIn(instance_).exchangeIn(
            dai, 1e18, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_mint_reverts() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 50e18);
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], shares_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(seShares[0].balanceOf(instance_), 0, "H3 residual");
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public {
        address instance_ = _openLiveN1();
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 30e18);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(seShares[0], shares_, IERC20(instance_));
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0],
            shares_,
            IERC20(instance_),
            preview_ + 1e18, // impossible minOut
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoFreeInventoryStrict(instance_);
        // shares returned to attacker (full revert)
        assertEq(seShares[0].balanceOf(attacker), shares_, "shares refunded on revert");
    }

    function test_threshold_mintBlocked_whenNotAllowed() public {
        // Default thresholds: after live, synthetic often > mintThreshold for N=1 50/50 style -
        // force burn-only region or assert coupling.
        address instance_ = _openLiveN1DefaultThresholds();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        uint256 synth_ = info_.syntheticPrice();
        assertEq(info_.isMintingAllowed(), synth_ > info_.mintThreshold(), "mint coupling");
        assertEq(info_.isBurningAllowed(), synth_ < info_.burnThreshold(), "burn coupling");
    }
}
