// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {P4BalancerInvariantBase} from "./P4BalancerInvariant.t.sol";
import {IP4SERouter} from "./P4BalancerHandler.sol";

/// @notice Liveness probes for SE-router routes that never succeeded in the P4 invariant runs.
contract P4SERouterRoutesTest is P4BalancerInvariantBase {
    address internal user;

    function _aggKey() internal pure returns (string memory) {
        return "P4B_ROUTES";
    }

    function setUp() public override {
        super.setUp();
        user = makeAddr("routeUser");
        dai.mint(user, 10_000e18);
        usdc.mint(user, 10_000e18);
        vm.startPrank(user);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);
        IERC20(address(usdc)).approve(address(permit2), type(uint256).max);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), seRouterAddr, type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), seRouterAddr, type(uint160).max, type(uint48).max);
        permit2.approve(address(seVault), seRouterAddr, type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /// route 2 exact-in: USDC -(SE vault deposit, pretransferred)-> shares -(buffer swap)-> DAI
    function test_route2_exactIn_depositThenSwap() public {
        uint256 d0 = dai.balanceOf(user);
        vm.prank(user);
        uint256 out = IP4SERouter(seRouterAddr).swapSingleTokenExactIn(
            bufferPool, address(usdc), address(seVault), address(dai), address(0), 50e18, 0, block.timestamp + 1 hours, false, ""
        );
        console2.log("route2 exactIn out", out, dai.balanceOf(user) - d0);
    }

    /// route 3 exact-out: DAI -(buffer swap)-> shares -(SE vault withdraw)-> exact USDC
    function test_route3_exactOut_swapThenWithdraw() public {
        uint256 u0 = usdc.balanceOf(user);
        vm.prank(user);
        uint256 paid = IP4SERouter(seRouterAddr).swapSingleTokenExactOut(
            bufferPool, address(dai), address(0), address(usdc), address(seVault), 20e18, 1000e18, block.timestamp + 1 hours, false, ""
        );
        console2.log("route3 exactOut paid", paid, usdc.balanceOf(user) - u0);
    }

    /// control: route 3 exact-in works
    function test_route3_exactIn_swapThenWithdraw() public {
        uint256 u0 = usdc.balanceOf(user);
        vm.prank(user);
        uint256 out = IP4SERouter(seRouterAddr).swapSingleTokenExactIn(
            bufferPool, address(dai), address(0), address(usdc), address(seVault), 20e18, 0, block.timestamp + 1 hours, false, ""
        );
        console2.log("route3 exactIn out", out, usdc.balanceOf(user) - u0);
    }
}
