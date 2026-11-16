// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

import {
    TestBase_MultiVaultWeightedDetf_Adversarial_Decimals
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {
    ILegacyMultiVaultWeightedDetfBonding as IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    ILegacyMultiVaultWeightedDetfInfo as IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

/// @notice Funded bond claim authorization and atomic staking payouts.
abstract contract Adversarial_BondClaim_Decimals is
    TestBase_MultiVaultWeightedDetf_Adversarial_Decimals,
    FundedBondLifecycleAssertions
{
    function test_D2_unstake_withoutStaking_cannotDrainBacking() public {
        address instance_ = _openLiveN1();
        assertEq(_fundedBondStaking(instance_).balanceOf(attacker), 0);
        _assertFundedUnstakeRejected(instance_, attacker, 1, IERC20(instance_), 0);
    }

    function test_D3_fullUnstake_cannotBeRepeated() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 id_,) = _goLiveViaBptBond(instance_, alice, 3_000e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        _assertFundedUnstake(instance_, alice, _fundedBondStaking(instance_).balanceOf(alice));
        _assertFundedUnstakeRejected(instance_, alice, 1, IERC20(instance_), 0);
    }

    function test_D4_unstake_rejectsUnsupportedOutput() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 id_,) = _goLiveViaBptBond(instance_, alice, 1_500e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        assertGt(_fundedBondStaking(instance_).balanceOf(alice), 0);
        _assertFundedUnstakeRejected(instance_, alice, 1, IERC20(makeAddr("unsupported payout")), 0);
    }

    function test_D5_lockClamp_minRevert_maxOk() public {
        address instance_ = _openLiveN1();
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 80e18);
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        vm.expectRevert();
        IMultiVaultWeightedDetfBonding(instance_)
            .bond(seShares[0], shares_, 1 days, attacker, false, block.timestamp + 1 hours);
        // max+ clamp succeeds
        (uint256 tid_,) = IMultiVaultWeightedDetfBonding(instance_)
            .bond(seShares[0], shares_, DEFAULT_MAX_LOCK + 365 days, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock bonds");
    }

    function test_D6_unstake_cannotExceedFundedBalance() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 id_,) = _goLiveViaBptBond(instance_, alice, 2_500e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        uint256 balance_ = _fundedBondStaking(instance_).balanceOf(alice);
        _assertFundedUnstakeRejected(instance_, alice, balance_ + 1, IERC20(instance_), 0);
        _assertFundedUnstake(instance_, alice, balance_ / 5);
        _assertFundedUnstakeRejected(instance_, alice, balance_, IERC20(instance_), 0);
    }
}
