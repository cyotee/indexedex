// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    ComposedStableCommonDetf_NaturalExpansion_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_NaturalExpansion.t.sol";

/// @dev Skeptic-only probe (temporary). Asserts E6 strong path.
contract E6Probe_ComposedStable_NaturalExpansion is ComposedStableCommonDetf_NaturalExpansion_Test {
    function test_probe_E6_strongPathMustCompound() public {
        userBondId = _setupPolicyExpansionLive(alice, bob);
        uint256 principalBefore_ = _protocolNftPrincipal();
        _warp(1 days);
        (uint256 detfIn_, uint256 bptOut_) = expInfo.compoundProtocolRewards();
        if (bptOut_ == 0) {
            _warp(1 days);
            (detfIn_, bptOut_) = expInfo.compoundProtocolRewards();
        }
        assertGt(bptOut_, 0, "E6 strong path: bptOut must be > 0");
        assertGt(detfIn_, 0, "E6 strong path: detfIn must be > 0");
        assertEq(_protocolNftPrincipal(), principalBefore_ + bptOut_, "principal += bptOut");
    }
}
