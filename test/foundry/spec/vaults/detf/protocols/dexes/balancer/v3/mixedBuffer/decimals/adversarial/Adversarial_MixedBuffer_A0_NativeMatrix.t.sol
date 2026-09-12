// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_MixedBuffer_A0_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/adversarial/Adversarial_MixedBuffer_A0_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract Adversarial_MixedBuffer_A0_NativeMatrix is Adversarial_MixedBuffer_A0_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_A0_mb_donatedBuffer_bootstrapDoesNotStealOthersSeed() public override {
        _runAllNativeBooks(super.setUp, super.test_A0_mb_donatedBuffer_bootstrapDoesNotStealOthersSeed);
    }

}
