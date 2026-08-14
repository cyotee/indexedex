// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/TestBase_MixedBufferMultiVaultStableDetf_Adversarial.sol";

/// @notice WP-SEC-DETF-CS-A0-001: MixedBuffer first-bond / first-mint cannot drain pre-seeded inventory.
/// @dev Donate before live. Do not count L-RSRV-DUST same-tx self-push as A0. Calls the production proxy.
contract Adversarial_MixedBuffer_A0_Test is TestBase_MixedBufferMultiVaultStableDetf_Adversarial {
    function test_A0_mb_donatedBuffer_bootstrapDoesNotStealOthersSeed() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        _assertInert(instance_);
        IERC20 buffer_ = _bufferOf(instance_);

        uint256 donated_ = 250e18;
        _fundBuffer(attacker, donated_);
        vm.prank(attacker);
        buffer_.transfer(instance_, donated_);
        assertEq(buffer_.balanceOf(instance_), donated_, "buffer idle before bootstrap");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "donor has no detfToken");

        _bootstrapDefault(instance_, alice);
        _assertLive(instance_);

        assertEq(buffer_.balanceOf(instance_), donated_, "bootstrap pull-false ignores idle donation");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "A0: donor not credited by first bond");
    }
}
