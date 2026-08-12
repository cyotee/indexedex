// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

contract BalancerV3UniswapV4CoordinatorRouter_Admin_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    IWETH internal weth;
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));
        tokenA = new SimpleMintableERC20("A", "A");
        tokenB = new SimpleMintableERC20("B", "B");
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed;
        _deployCoordinator(weth, address(0), seed);
    }

    /// @notice T21: unregister then money entry reverts RouterNotAllowed (not view-only theater).
    function test_T21_unregisterThenStepReverts() public {
        address r = address(0xB0B);
        coordinator.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
        assertTrue(coordinator.isRouterAllowed(r));
        coordinator.unregisterRouter(r);
        assertFalse(coordinator.isRouterAllowed(r));

        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: r, tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 21, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IBalancerV3UniswapV4CoordinatorRouter.RouterNotAllowed.selector, r));
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_registerZeroReverts() public {
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.ZeroAddress.selector);
        coordinator.registerRouter(address(0), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
    }

    function test_onlyOwnerRegister() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, alice));
        coordinator.registerRouter(address(1), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router);
    }
}
