// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Guards_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Guards_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Guards_NativeMatrix is MixedBufferMultiVaultStableDetf_Guards_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_zero_amount_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_zero_amount_reverts);
    }

    function test_deadline_expired_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_deadline_expired_reverts);
    }

    function test_peg_seed_pure_formula_n1() public override {
        _runAllNativeBooks(super.setUp, super.test_peg_seed_pure_formula_n1);
    }

}
