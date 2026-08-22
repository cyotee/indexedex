// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

contract MultiVaultWeightedDetf_Alignment_D31_ExpansionGate is TestBase_MultiVaultWeightedDetf {
    function test_D31_4_openDoesNotExpandOnCompound() public {
        detf = _deployOpenModeDetf("D31 MVW", "d31mvw");
        detfInfo = IMultiVaultWeightedDetfInfo(detf);
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 30 days);
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4");
    }
}
