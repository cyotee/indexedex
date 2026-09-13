// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_MixedBufferMultiVaultStableDetf_Adversarial} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {TestBase_MixedBufferMultiVaultStableDetf_Decimals} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol";

/// @notice Canonical funded security behavior over real native-decimal token books.
abstract contract TestBase_MixedBufferMultiVaultStableDetf_Adversarial_Decimals is TestBase_MixedBufferMultiVaultStableDetf_Adversarial, TestBase_MixedBufferMultiVaultStableDetf_Decimals {
    function setUp() public override(TestBase_MixedBufferMultiVaultStableDetf_Adversarial, TestBase_MixedBufferMultiVaultStableDetf) {
        TestBase_MixedBufferMultiVaultStableDetf_Adversarial.setUp();
    }

    function _fixtureBufferToken() internal view override(TestBase_MixedBufferMultiVaultStableDetf, TestBase_MixedBufferMultiVaultStableDetf_Decimals) returns (IERC20) {
        return TestBase_MixedBufferMultiVaultStableDetf_Decimals._fixtureBufferToken();
    }

    function _initializeMixedFixtureLegs() internal override(TestBase_MixedBufferMultiVaultStableDetf, TestBase_MixedBufferMultiVaultStableDetf_Decimals) {
        TestBase_MixedBufferMultiVaultStableDetf_Decimals._initializeMixedFixtureLegs();
    }

    function _deployExtraDaiSeVault(uint8 idx) internal override(TestBase_MixedBufferMultiVaultStableDetf, TestBase_MixedBufferMultiVaultStableDetf_Decimals) {
        TestBase_MixedBufferMultiVaultStableDetf_Decimals._deployExtraDaiSeVault(idx);
    }
}
