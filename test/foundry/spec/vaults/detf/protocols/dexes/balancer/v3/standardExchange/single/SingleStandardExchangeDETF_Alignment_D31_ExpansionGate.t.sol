// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice D31 realize-then-gate on Balancer Single SE.
contract SingleStandardExchangeDETF_Alignment_D31_ExpansionGate is TestBase_SingleStandardExchangeDETF {
    function test_D31_4_openMintDoesNotExpand() public {
        detf = _deployOpenModeDetf("D31 SSE Open", "d31sse");
        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        _bootstrapViaFirstBond(alice, 1_200e18);
        uint256 last_ = detfInfo.lastExpansionTimestamp();
        vm.warp(block.timestamp + 30 days);
        assertEq(detfInfo.lastExpansionTimestamp(), last_, "D31-4 Open clock idle");
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Open));
    }
}
