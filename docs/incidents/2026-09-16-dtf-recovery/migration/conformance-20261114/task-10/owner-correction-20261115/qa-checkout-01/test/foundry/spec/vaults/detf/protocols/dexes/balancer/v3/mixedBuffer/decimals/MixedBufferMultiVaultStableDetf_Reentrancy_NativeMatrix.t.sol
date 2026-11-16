// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Reentrancy_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Reentrancy_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_Reentrancy_NativeMatrix is MixedBufferMultiVaultStableDetf_Reentrancy_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_control_path_mint_succeeds() public override {
        _runAllNativeBooks(super.setUp, super.test_control_path_mint_succeeds);
    }

    function test_reentrancy_mintBufferPath_nestedHitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_reentrancy_mintBufferPath_nestedHitsIsLocked);
    }

    function test_reentrancy_crossFunction_bond_nestedHitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_reentrancy_crossFunction_bond_nestedHitsIsLocked);
    }

    function test_primaryMint_controlFundsRewardsAndLiquidity() public override {
        _runAllNativeBooks(super.setUp, super.test_primaryMint_controlFundsRewardsAndLiquidity);
    }

    function test_primaryMint_nestedExchangeHitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_primaryMint_nestedExchangeHitsIsLocked);
    }

    function test_primaryMint_nestedBondHitsIsLocked() public override {
        _runAllNativeBooks(super.setUp, super.test_primaryMint_nestedBondHitsIsLocked);
    }

}
