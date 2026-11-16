// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_Bonding_Test} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Bonding.t.sol";
import {TestBase_MixedBufferMultiVaultStableDetf_Decimals} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf_Decimals.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Runs the canonical funded behavior with actual native-decimal token books.
abstract contract MixedBufferMultiVaultStableDetf_Bonding_Decimals is
    MixedBufferMultiVaultStableDetf_Bonding_Test, TestBase_MixedBufferMultiVaultStableDetf_Decimals
{
    function setUp() public override(MixedBufferMultiVaultStableDetf_Bonding_Test, TestBase_MixedBufferMultiVaultStableDetf) {
        MixedBufferMultiVaultStableDetf_Bonding_Test.setUp();
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
