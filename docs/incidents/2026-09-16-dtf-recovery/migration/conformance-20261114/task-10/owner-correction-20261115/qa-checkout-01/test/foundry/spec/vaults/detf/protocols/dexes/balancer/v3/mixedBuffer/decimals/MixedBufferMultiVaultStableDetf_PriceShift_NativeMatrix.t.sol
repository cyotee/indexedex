// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_PriceShift_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_PriceShift_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_PriceShift_NativeMatrix is MixedBufferMultiVaultStableDetf_PriceShift_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_defaultThresholds_gate_coupling_afterBootstrap() public override {
        _runAllNativeBooks(super.setUp, super.test_defaultThresholds_gate_coupling_afterBootstrap);
    }

    function test_underlyingSwap_opensMintAndBurn_underDefaultThresholds() public override {
        _runAllNativeBooks(super.setUp, super.test_underlyingSwap_opensMintAndBurn_underDefaultThresholds);
    }

}
