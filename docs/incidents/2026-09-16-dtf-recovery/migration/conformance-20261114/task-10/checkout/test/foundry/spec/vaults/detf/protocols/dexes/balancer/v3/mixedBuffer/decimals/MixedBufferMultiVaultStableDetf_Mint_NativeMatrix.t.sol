// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Mint_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Mint_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Mint_NativeMatrix is MixedBufferMultiVaultStableDetf_Mint_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_mint_from_buffer() public override {
        _runAllNativeBooks(super.setUp, super.test_mint_from_buffer);
    }

    function test_liveMint_doesNotJoinDetf() public override {
        _runAllNativeBooks(super.setUp, super.test_liveMint_doesNotJoinDetf);
    }

    function test_mint_from_vault_share() public override {
        _runAllNativeBooks(super.setUp, super.test_mint_from_vault_share);
    }

    function test_mint_n2_each_share() public override {
        _runAllNativeBooks(super.setUp, super.test_mint_n2_each_share);
    }

}
