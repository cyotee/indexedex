// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {HostileReentrantShare} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {AdversarialAssertLib} from "contracts/test/adversarial/AdversarialAssertLib.sol";

/// @notice Wave 0 smoke: shared adversarial harness deploys and residual helper callable.
contract SharedHarness_Compile_Test is Test {
    function test_W0_hostileShare_and_reentryTarget_deploy() public {
        HostileReentrantShare share_ = new HostileReentrantShare();
        DetfReentryTarget target_ = new DetfReentryTarget();
        share_.mint(address(this), 1e18);
        share_.arm(address(target_), abi.encodeWithSelector(bytes4(0)));
        assertTrue(share_.armed());
        assertEq(share_.balanceOf(address(this)), 1e18);
    }

    function test_W0_assertNoFreeShare_onCleanAddress() public {
        HostileReentrantShare product_ = new HostileReentrantShare();
        HostileReentrantShare share_ = new HostileReentrantShare();
        // product_ diamond surrogate holds zero of itself and zero of share_
        AdversarialAssertLib.assertNoFreeShare(address(product_), IERC20(address(share_)));
    }
}
