// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Nested_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Nested_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Nested_NativeMatrix is MixedBufferMultiVaultStableDetf_Nested_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_nestedDetf_asLeg_outerMintBurnBond() public override {
        _runAllNativeBooks(super.setUp, super.test_nestedDetf_asLeg_outerMintBurnBond);
    }

}
