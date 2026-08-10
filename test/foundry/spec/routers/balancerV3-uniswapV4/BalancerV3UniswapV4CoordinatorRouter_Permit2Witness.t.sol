// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {SignatureVerification} from "@crane/contracts/protocols/utils/permit2/SignatureVerification.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

/// @notice T13/T14 witness binding (exact Permit2 fail selectors)
contract BalancerV3UniswapV4CoordinatorRouter_Permit2Witness_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;
    IWETH internal weth;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));
        tokenA = new SimpleMintableERC20("A", "A");
        tokenB = new SimpleMintableERC20("B", "B");
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(0xBEEF), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        _deployCoordinator(weth, address(0), seed);
        tokenA.mint(alice, 100e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
    }

    function test_T14_witnessMismatchReverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
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
        // Sign honest params then tamper recipient → Permit2 InvalidSigner (witness bound).
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 0, block.timestamp + 1 days);
        params.recipient = makeAddr("attacker");
        vm.prank(alice);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }
}
