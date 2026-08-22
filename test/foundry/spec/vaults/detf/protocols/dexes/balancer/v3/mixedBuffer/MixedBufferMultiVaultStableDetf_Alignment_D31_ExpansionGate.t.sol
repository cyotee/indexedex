// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

contract MixedBufferMultiVaultStableDetf_Alignment_D31_ExpansionGate is TestBase_MixedBufferMultiVaultStableDetf {
    function test_D31_4_openDoesNotExpandOnCompound() public {
        detf = _deployOpenModeDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        _bootstrapDefault(detf, alice);
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 30 days);
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4");
    }
}
