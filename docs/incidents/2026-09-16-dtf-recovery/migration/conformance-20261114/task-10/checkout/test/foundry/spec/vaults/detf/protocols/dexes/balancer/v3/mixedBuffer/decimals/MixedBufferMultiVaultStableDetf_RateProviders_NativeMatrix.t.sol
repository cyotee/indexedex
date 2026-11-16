// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_RateProviders_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_RateProviders_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_RateProviders_NativeMatrix is MixedBufferMultiVaultStableDetf_RateProviders_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_share_STANDARD_default() public override {
        _runAllNativeBooks(super.setUp, super.test_share_STANDARD_default);
    }

    function test_share_WITH_RATE_matrix() public override {
        _runAllNativeBooks(super.setUp, super.test_share_WITH_RATE_matrix);
    }

}
