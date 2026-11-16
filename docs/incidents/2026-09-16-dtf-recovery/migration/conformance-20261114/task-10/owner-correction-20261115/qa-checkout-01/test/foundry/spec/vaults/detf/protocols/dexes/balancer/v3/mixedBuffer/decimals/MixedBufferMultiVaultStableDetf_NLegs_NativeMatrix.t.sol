// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_NLegs_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_NLegs_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_NLegs_NativeMatrix is MixedBufferMultiVaultStableDetf_NLegs_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_n1_full_lifecycle() public override {
        _runAllNativeBooks(super.setUp, super.test_n1_full_lifecycle);
    }

    function test_n2_multi_protocol_lifecycle() public override {
        _runAllNativeBooks(super.setUp, super.test_n2_multi_protocol_lifecycle);
    }

    function test_n3_smoke() public override {
        _runAllNativeBooks(super.setUp, super.test_n3_smoke);
    }

}
