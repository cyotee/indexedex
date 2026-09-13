// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_SingleStandardExchangeDETF_Decimals} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice Guards: zero amount, deadline, unsupported route.
abstract contract SingleStandardExchangeDETF_Guards_Decimals is TestBase_SingleStandardExchangeDETF_Decimals {
    function test_guard_zeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ZeroAmount.selector);
        detfExchangeIn.exchangeIn(seShare, 0, IERC20(detf), 0, alice, false, block.timestamp + 1 hours);
    }

    function test_guard_deadlineExpiredReverts() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SingleStandardExchangeDETFRepo.DeadlineExpired.selector, block.timestamp - 1)
        );
        detfExchangeIn.exchangeIn(seShare, 1e18, IERC20(detf), 0, alice, false, block.timestamp - 1);
    }

    function test_guard_unsupportedRouteReverts() public {
        // Passthrough path checks allowlist before mint/burn gates.
        IERC20 junkA_ = IERC20(address(0xBEEF));
        IERC20 junkB_ = IERC20(address(0xCAFE));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SingleStandardExchangeDETFRepo.UnsupportedRoute.selector, junkA_, junkB_)
        );
        detfExchangeIn.exchangeIn(junkA_, 1e18, junkB_, 0, alice, false, block.timestamp + 1 hours);
    }
}
