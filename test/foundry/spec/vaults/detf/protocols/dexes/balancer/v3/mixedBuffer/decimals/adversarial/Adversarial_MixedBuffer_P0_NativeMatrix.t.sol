// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_MixedBuffer_P0_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/adversarial/Adversarial_MixedBuffer_P0_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract Adversarial_MixedBuffer_P0_NativeMatrix is Adversarial_MixedBuffer_P0_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_E5_zeroAmount_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_E5_zeroAmount_reverts);
    }

    function test_E5_expiredDeadline_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_E5_expiredDeadline_reverts);
    }

    function test_H3_minOutTooHigh_leavesNoInventory() public override {
        _runAllNativeBooks(super.setUp, super.test_H3_minOutTooHigh_leavesNoInventory);
    }

    function test_preLive_mint_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_preLive_mint_reverts);
    }

    function test_A1_donateBuffer_cannotMintFreeDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_A1_donateBuffer_cannotMintFreeDetf);
    }

    function test_A1_donateVaultShares_cannotMintFreeDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_A1_donateVaultShares_cannotMintFreeDetf);
    }

    function test_A2_donateDetfToDiamond_noTheft() public override {
        _runAllNativeBooks(super.setUp, super.test_A2_donateDetfToDiamond_noTheft);
    }

    function test_A3_D2_unstakeWithoutReceipt_noBptOrBackingDrain() public override {
        _runAllNativeBooks(super.setUp, super.test_A3_D2_unstakeWithoutReceipt_noBptOrBackingDrain);
    }

    function test_D2_claimBond_nonOwner_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_D2_claimBond_nonOwner_reverts);
    }

    function test_D3_finalClaim_cannotPayTwice() public override {
        _runAllNativeBooks(super.setUp, super.test_D3_finalClaim_cannotPayTwice);
    }

    function test_D3_unstake_overRemainingReceipt_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_D3_unstake_overRemainingReceipt_reverts);
    }

    function test_D5_lockClamp_minRevert_maxOk() public override {
        _runAllNativeBooks(super.setUp, super.test_D5_lockClamp_minRevert_maxOk);
    }

    function test_D6_unstakePaysExactlyHeldDetfAndLeavesProtocolLp() public override {
        _runAllNativeBooks(super.setUp, super.test_D6_unstakePaysExactlyHeldDetfAndLeavesProtocolLp);
    }

    function test_F2_createFundedPosition_onlyDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_F2_createFundedPosition_onlyDetf);
    }

    function test_F3_fundRewards_onlyDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_F3_fundRewards_onlyDetf);
    }

    function test_F3_retireEscrowDust_onlyBondNft() public override {
        _runAllNativeBooks(super.setUp, super.test_F3_retireEscrowDust_onlyBondNft);
    }

    function test_F1_diamondCut_notCallableByAttacker() public override {
        _runAllNativeBooks(super.setUp, super.test_F1_diamondCut_notCallableByAttacker);
    }

    function test_F4_noSetWeightsOrThresholds() public override {
        _runAllNativeBooks(super.setUp, super.test_F4_noSetWeightsOrThresholds);
    }

    function test_C1_reenterBond_duringBootstrap_hitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_C1_reenterBond_duringBootstrap_hitsIsLocked);
    }

    function test_C2_reenterExchangeIn_duringBufferMint_hitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_C2_reenterExchangeIn_duringBufferMint_hitsIsLocked);
    }

    function test_C3_bufferMintReenterBond_hitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_C3_bufferMintReenterBond_hitsIsLocked);
    }

    function test_E1_mintThenPartialBurn_conservation() public override {
        _runAllNativeBooks(super.setUp, super.test_E1_mintThenPartialBurn_conservation);
    }

    function test_E4_holderBalance_notDilutedByOthersMint() public override {
        _runAllNativeBooks(super.setUp, super.test_E4_holderBalance_notDilutedByOthersMint);
    }

    function test_B3_thresholdGates_coupleToSynthetic() public override {
        _runAllNativeBooks(super.setUp, super.test_B3_thresholdGates_coupleToSynthetic);
    }

    function test_B1_reserveFallback_mintBurn_boundsSafety() public override {
        _runAllNativeBooks(super.setUp, super.test_B1_reserveFallback_mintBurn_boundsSafety);
    }

    function test_H2_unstake_minOutFail_receiptAndBackingUnchanged() public override {
        _runAllNativeBooks(super.setUp, super.test_H2_unstake_minOutFail_receiptAndBackingUnchanged);
    }

    function test_G1_outerActivity_doesNotBrickInner() public override {
        _runAllNativeBooks(super.setUp, super.test_G1_outerActivity_doesNotBrickInner);
    }

}
