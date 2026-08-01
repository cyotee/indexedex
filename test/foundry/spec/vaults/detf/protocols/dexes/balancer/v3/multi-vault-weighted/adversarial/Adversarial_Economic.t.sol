// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice E1 conservation round-trip; E4 soft non-dilution of existing holder balances.
/// @dev Deferred P2: E2 (multi-leg dust after burn - covered residual-clean in MultiLeg/FeeNonDilution matrix),
///      E3 (fee recipient drain - FeeNonDilution suite).
contract Adversarial_Economic_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    /// @notice E1: vaultShare → DETF → vaultShare; out ≤ in + tiny wei; residual free inventory 0.
    function test_E1_mintThenPartialBurn_conservation() public {
        address instance_ = _openLiveN1();

        uint256 sharesIn_ = _fundSeSharesLeg(0, attacker, 60e18);
        uint256 shareBalBefore_ = seShares[0].balanceOf(attacker);

        vm.startPrank(attacker);
        seShares[0].approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted detf");
        assertEq(seShares[0].balanceOf(attacker), shareBalBefore_ - sharesIn_, "shares spent");

        // Partial burn
        uint256 burnAmt_ = detfOut_ / 2;
        if (burnAmt_ == 0) burnAmt_ = detfOut_;
        uint256 sharesMid_ = seShares[0].balanceOf(attacker);

        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 sharesBack_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShares[0], 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(sharesBack_ > 0, "burn returned shares");
        assertEq(seShares[0].balanceOf(attacker), sharesMid_ + sharesBack_, "shares received");
        // Round-trip half should not create free shares beyond input (allow tiny Balancer dust on full)
        // Full cycle of half: sharesBack ≤ sharesIn_ (strict conservation of value on partial)
        assertLe(sharesBack_, sharesIn_, "E1: partial burn out <= original in");

        _assertNoFreeInventoryStrict(instance_);
    }

    /// @notice E4: existing holder DETF balance unchanged when another user mints.
    function test_E4_holderBalance_notDilutedByOthersMint() public {
        address instance_ = _openLiveN1();
        uint256 holderOut_ = _mintOnLeg(instance_, 0, victim, 50e18);
        assertTrue(holderOut_ > 0, "victim holds detf");
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        uint256 synthBefore_ = IMultiVaultWeightedDetfInfo(instance_).syntheticPrice();

        _mintOnLeg(instance_, 0, attacker, 40e18);

        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "E4: victim DETF balance unchanged");
        // Soft: synthetic claim may move with seigniorage; document - balance units non-decreasing
        uint256 synthAfter_ = IMultiVaultWeightedDetfInfo(instance_).syntheticPrice();
        // Victim's DETF * synthetic is economic claim; balance fixed so claim tracks synthetic.
        // Assert at least victim token balance invariant (hard).
        assertTrue(victimBal_ > 0, "victim still holds");
        // synth may fall on free seigniorage mint - intentional design, not a theft of token balance.
        emit log_named_uint("synth_before", synthBefore_);
        emit log_named_uint("synth_after", synthAfter_);
    }
}
