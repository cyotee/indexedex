// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Burn_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Burn_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Burn_NativeMatrix is MixedBufferMultiVaultStableDetf_Burn_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_burn_to_buffer() public override {
        _runAllNativeBooks(super.setUp, super.test_burn_to_buffer);
    }

    function test_burn_to_vaultShare() public override {
        _runAllNativeBooks(super.setUp, super.test_burn_to_vaultShare);
    }

}
