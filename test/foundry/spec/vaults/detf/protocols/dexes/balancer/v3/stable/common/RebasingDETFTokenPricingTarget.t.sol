// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    RebasingDETFTokenPricingHarness,
    TestBase_ComposedStableCommonDetf_Components
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Components.sol';

contract RebasingDETFTokenPricingTarget_Test is TestBase_ComposedStableCommonDetf_Components {
    function test_previewRebasingDetfTokenReserveBpt_returnsProtocolReserveSlice() public {
        mockDetfOwnedReserveBpt(7, 40e18);
        mockRebasingShareQuote(5e18, 10e18, 80e18);

        assertEq(pricingHarness.previewRebasingDetfTokenReserveBpt(5e18), 5e18);
    }

    function test_previewReservePoolDecomposition_returnsProRataLegs() public {
        uint256[] memory balances = new uint256[](3);
        balances[0] = 60e18;
        balances[1] = 20e18;
        balances[2] = 20e18;

        mockReservePoolDynamicData(balances, 100e18);

        (uint256 detfAmount, uint256 stableAmount, uint256 commonAmount) =
            pricingHarness.previewReservePoolDecomposition(10e18);

        assertEq(detfAmount, 6e18);
        assertEq(stableAmount, 2e18);
        assertEq(commonAmount, 2e18);
    }

    function test_syntheticDetfEthPrice_usesExternalBackingOnly() public {
        uint256[] memory balances = new uint256[](3);
        balances[0] = 60e18;
        balances[1] = 20e18;
        balances[2] = 20e18;

        mockReservePoolDynamicData(balances, 100e18);
        mockReservePoolBalance(10e18);
        mockDetfTotalSupply(100e18);
        mockStablePoolEthQuote(2e18, 8e18);
        mockCommonPoolEthQuote(2e18, 4e18);

        assertEq(pricingHarness.syntheticDetfEthPrice(), 127659574468085106);
    }

    function test_previewRebasingDetfTokenEthValue_addsDetfLegAtSyntheticPrice() public {
        uint256[] memory balances = new uint256[](3);
        balances[0] = 60e18;
        balances[1] = 20e18;
        balances[2] = 20e18;

        mockReservePoolDynamicData(balances, 100e18);
        mockReservePoolBalance(10e18);
        mockDetfTotalSupply(100e18);
        mockStablePoolEthQuote(2e18, 8e18);
        mockCommonPoolEthQuote(2e18, 4e18);

        assertEq(pricingHarness.previewRebasingDetfTokenEthValue(10e18), 12765957446808510636);
    }

    function test_previewHelpers_returnZero_whenPricingDependenciesUnset() public {
        RebasingDETFTokenPricingHarness uninitializedHarness = new RebasingDETFTokenPricingHarness();

        assertEq(uninitializedHarness.previewStablePoolBptEthValue(1e18), 0);
        assertEq(uninitializedHarness.previewCommonPoolBptEthValue(1e18), 0);
        assertEq(uninitializedHarness.syntheticDetfEthPrice(), 0);
        assertEq(uninitializedHarness.previewRebasingDetfTokenReserveBpt(1e18), 0);
        assertEq(uninitializedHarness.previewRebasingDetfTokenEthValue(1e18), 0);
    }
}