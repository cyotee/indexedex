// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Routes_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Routes_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Routes_NativeMatrix is MixedBufferMultiVaultStableDetf_Routes_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_share_to_share_InvalidRoute() public override {
        _runAllNativeBooks(super.setUp, super.test_share_to_share_InvalidRoute);
    }

    function test_unconfigured_token_InvalidRoute() public override {
        _runAllNativeBooks(super.setUp, super.test_unconfigured_token_InvalidRoute);
    }

    function test_exactOut_InvalidRoute() public override {
        _runAllNativeBooks(super.setUp, super.test_exactOut_InvalidRoute);
    }

}
