// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_NestedPush_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_NestedPush_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_NestedPush_NativeMatrix is MixedBufferMultiVaultStableDetf_NestedPush_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync);
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient);
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts);
    }

    function test_T_NEST_4_noNestedApproveOnFundPath() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_4_noNestedApproveOnFundPath);
    }

    function test_T_NEST_5_standardExactOut_stakesFundedDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_5_standardExactOut_stakesFundedDetf);
    }

    function test_T_NEST_6_holdSetSyncAfterRoute() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_6_holdSetSyncAfterRoute);
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount);
    }

    function test_T_NEST_8_standardExactOut_unstakeLeavesUnusedMaximum() public override {
        _runAllNativeBooks(super.setUp, super.test_T_NEST_8_standardExactOut_unstakeLeavesUnusedMaximum);
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public override {
        _runAllNativeBooks(super.setUp, super.test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU);
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public override {
        _runAllNativeBooks(super.setUp, super.test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts);
    }

}
