// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Pricing_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Pricing_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Pricing_NativeMatrix is MixedBufferMultiVaultStableDetf_Pricing_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_synthetic_readable_inert() public override {
        _runAllNativeBooks(super.setUp, super.test_synthetic_readable_inert);
    }

    function test_synthetic_after_bootstrap() public override {
        _runAllNativeBooks(super.setUp, super.test_synthetic_after_bootstrap);
    }

    function test_gate_coupling_matches_thresholds() public override {
        _runAllNativeBooks(super.setUp, super.test_gate_coupling_matches_thresholds);
    }

    function test_mint_swaps_when_gate_closed() public override {
        _runAllNativeBooks(super.setUp, super.test_mint_swaps_when_gate_closed);
    }

    function test_burn_swaps_when_gate_closed() public override {
        _runAllNativeBooks(super.setUp, super.test_burn_swaps_when_gate_closed);
    }

}
