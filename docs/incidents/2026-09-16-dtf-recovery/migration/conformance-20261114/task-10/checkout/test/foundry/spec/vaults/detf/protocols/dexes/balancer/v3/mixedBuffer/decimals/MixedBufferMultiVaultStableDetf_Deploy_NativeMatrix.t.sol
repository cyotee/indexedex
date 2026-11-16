// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Deploy_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Deploy_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Deploy_NativeMatrix is MixedBufferMultiVaultStableDetf_Deploy_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_deploy_inert_n1() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_inert_n1);
    }

    function test_deploy_n2() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_n2);
    }

    function test_deploy_n3_smoke() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_n3_smoke);
    }

    function test_deploy_reverts_invalid_vault_count_zero() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_reverts_invalid_vault_count_zero);
    }

    function test_deploy_reverts_duplicate_vault() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_reverts_duplicate_vault);
    }

    function test_deploy_reverts_bad_amp() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_reverts_bad_amp);
    }

    function test_deploy_reverts_rp_length_mismatch() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_reverts_rp_length_mismatch);
    }

    function test_deploy_via_registry_not_new() public override {
        _runAllNativeBooks(super.setUp, super.test_deploy_via_registry_not_new);
    }

}
