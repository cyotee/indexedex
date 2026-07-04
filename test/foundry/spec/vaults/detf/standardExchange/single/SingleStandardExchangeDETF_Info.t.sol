// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";

/// @notice Phase 5 Info surface: role refs, thresholds, synthetic gate views.
contract SingleStandardExchangeDETF_Info_Test is TestBase_SingleStandardExchangeDETF {
    function test_info_roleWiring() public view {
        assertEq(detfInfo.standardExchangeVault(), address(seVault));
        assertEq(detfInfo.standardExchangeVaultShare(), address(seShare));
        assertEq(detfInfo.rateTarget(), address(rateTargetToken));
        assertTrue(detfInfo.reservePool() != address(0));
        assertTrue(detfInfo.bondNftVault() != address(0));
    }

    function test_info_thresholdsDefault() public view {
        assertEq(detfInfo.mintThreshold(), 1.05e18);
        assertEq(detfInfo.burnThreshold(), 0.95e18);
    }

    function test_info_afterBootstrap_syntheticGates() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 synth_ = detfInfo.syntheticPrice();
        assertTrue(synth_ > 0, "synthetic readable");

        // Default mint gate: allowed only if synthetic > 1.05e18.
        if (synth_ > 1.05e18) {
            assertTrue(detfInfo.isMintingAllowed(), "mint allowed above mintThreshold");
        } else {
            assertFalse(detfInfo.isMintingAllowed(), "mint blocked at/below mintThreshold");
        }

        // Default burn gate: allowed only if synthetic < 0.95e18.
        if (synth_ < 0.95e18) {
            assertTrue(detfInfo.isBurningAllowed(), "burn allowed below burnThreshold");
        } else {
            assertFalse(detfInfo.isBurningAllowed(), "burn blocked at/above burnThreshold");
        }

        // At near-peg bootstrap, both gates should be closed (deadband).
        // Assert the coupling: isMintingAllowed() == (synth > mintThreshold).
        assertEq(detfInfo.isMintingAllowed(), synth_ > detfInfo.mintThreshold(), "mint gate coupling");
        assertEq(detfInfo.isBurningAllowed(), synth_ < detfInfo.burnThreshold(), "burn gate coupling");
    }
}
