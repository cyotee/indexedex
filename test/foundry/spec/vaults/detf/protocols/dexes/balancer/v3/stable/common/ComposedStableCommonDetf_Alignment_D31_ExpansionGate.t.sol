// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";

contract ComposedStableCommonDetf_Alignment_D31_ExpansionGate is ComposedStableCommonDetf_IntegratedDeploy_Test {
    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function test_D31_4_openDoesNotExpandOnCompound() public {
        _bootstrapReserveGraph();
        IComposedStableCommonDetfInfo info = IComposedStableCommonDetfInfo(deployedDetfVault);
        uint256 last_ = info.lastExpansionTimestamp();
        vm.warp(block.timestamp + 30 days);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(info.lastExpansionTimestamp(), last_, "D31-4");
    }
}
