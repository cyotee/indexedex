// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Bootstrap_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Bootstrap_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Bootstrap_NativeMatrix is MixedBufferMultiVaultStableDetf_Bootstrap_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_bootstrap_permissionless_third_party() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_permissionless_third_party);
    }

    function test_bootstrap_second_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_second_reverts);
    }

    function test_bootstrap_zero_buffer_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_zero_buffer_reverts);
    }

    function test_bootstrap_zero_share_leg_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_zero_share_leg_reverts);
    }

    function test_bootstrap_peg_seed_n1() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_peg_seed_n1);
    }

    function test_bootstrap_ungated_by_synthetic() public override {
        _runAllNativeBooks(super.setUp, super.test_bootstrap_ungated_by_synthetic);
    }

}
