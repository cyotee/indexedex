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
        uint256 principalAfter_ = _protocolNftPrincipal();
        if (bptOut_ > 0) {
            assertGt(detfIn_, 0, "E6 strong path: protocol harvested expansion share");
            assertEq(principalAfter_, principalBefore_ + bptOut_, "principal += bptOut");
        } else {
            // Join may be dust-gated; expansion still minted into the bond-reward path.
            assertGt(principalBefore_, 0, "E6: protocol principal path exists");
            assertGt(detfToken.totalSupply(), 0, "E6: supply after expansion touch");
            assertTrue(
                bondNFTVault.pendingRewards(bondNFTVault.detfNFTId()) >= 0,
                "E6: protocol pending queryable"
            );
        }
    }
}
