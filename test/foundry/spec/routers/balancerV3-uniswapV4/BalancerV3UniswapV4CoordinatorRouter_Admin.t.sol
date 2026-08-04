// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

contract BalancerV3UniswapV4CoordinatorRouter_Admin_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    IWETH internal weth;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed;
        _deployCoordinator(weth, address(0), seed);
    }

    function test_T21_unregisterThenStepReverts() public {
        address r = address(0xB0B);
        coordinator.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
        assertTrue(coordinator.isRouterAllowed(r));
        coordinator.unregisterRouter(r);
        assertFalse(coordinator.isRouterAllowed(r));
    }

    function test_registerZeroReverts() public {
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.ZeroAddress.selector);
        coordinator.registerRouter(address(0), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
    }

    function test_onlyOwnerRegister() public {
        vm.prank(alice);
        vm.expectRevert();
        coordinator.registerRouter(address(1), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
    }
}
