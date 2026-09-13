// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

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
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy));
    }

    function test_info_inert_isAllowedFalse() public view {
        assertFalse(detfInfo.isReserveLive());
        assertFalse(detfInfo.isMintingAllowed(), "inert mint false (live-coupled)");
        assertFalse(detfInfo.isBurningAllowed(), "inert burn false (live-coupled)");
    }

    function test_info_afterBootstrap_syntheticGates() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 synth_ = detfInfo.syntheticPrice();
        assertTrue(synth_ > 0, "synthetic readable");
        assertTrue(detfInfo.isReserveLive(), "live after bootstrap");

        // Live + Policy: is*Allowed == synthetic deadband (strict inequalities).
        assertEq(
            detfInfo.isMintingAllowed(),
            synth_ > detfInfo.mintThreshold(),
            "mint gate coupling (live + Policy)"
        );
        assertEq(
            detfInfo.isBurningAllowed(),
            synth_ < detfInfo.burnThreshold(),
            "burn gate coupling (live + Policy)"
        );
    }
}
