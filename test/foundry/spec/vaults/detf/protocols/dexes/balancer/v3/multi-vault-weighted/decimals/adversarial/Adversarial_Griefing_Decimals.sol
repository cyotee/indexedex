// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

import {
    TestBase_MultiVaultWeightedDetf_Adversarial_Decimals
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    ILegacyMultiVaultWeightedDetfBonding as IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    ILegacyMultiVaultWeightedDetfInfo as IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

/// @notice Funded bond claim authorization and atomic staking payouts.
abstract contract Adversarial_Griefing_Decimals_DexBalV3Mul is
    TestBase_MultiVaultWeightedDetf_Adversarial_Decimals,
    FundedBondLifecycleAssertions
{
    /// @notice H2: impossible minOut reverts whole redeem; claim not permanently burned.
    function test_H2_unstake_minimumFailure_preservesFundedClaim() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 id_,) = _goLiveViaBptBond(instance_, alice, 2_500e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        uint256 amount_ = _fundedBondStaking(instance_).balanceOf(alice) / 10;
        assertGt(amount_, 0);
        _assertFundedUnstakeRejected(instance_, alice, amount_, IERC20(instance_), amount_ + 1);
        _assertFundedUnstake(instance_, alice, amount_);
    }

    /// @notice H2b: full claim redeem either succeeds or reverts cleanly (no partial strand).
    function test_H2_fullUnstake_paysEntireFundedBalance() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 id_,) = _goLiveViaBptBond(instance_, alice, 5_000e18);
        _mintOnLeg(instance_, 0, bob, 200e18);
        _assertBondMaturePreviewEqualsPayment(instance_, id_, alice);
        _assertFundedUnstake(instance_, alice, _fundedBondStaking(instance_).balanceOf(alice));
        assertEq(_fundedBondStaking(instance_).gonsOf(alice), 0, "full exit retires fractional gons");
    }
}
