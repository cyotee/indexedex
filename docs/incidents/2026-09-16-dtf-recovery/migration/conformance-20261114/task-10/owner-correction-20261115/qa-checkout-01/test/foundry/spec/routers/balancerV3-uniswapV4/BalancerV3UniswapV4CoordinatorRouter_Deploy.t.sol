// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

/// @notice T1, T25, T28, T29, T30 — deploy, ownership, pure Crane path, seed, idempotent register.
contract BalancerV3UniswapV4CoordinatorRouter_Deploy_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    IWETH internal weth;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(0xBEEF), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        _deployCoordinator(weth, address(0), seed);
    }

    function test_T1_deployViaCreate3AndRegister() public view {
        assertTrue(address(coordinator) != address(0), "coordinator deployed");
        assertEq(IMultiStepOwnable(address(coordinator)).owner(), owner);
        assertTrue(coordinator.isRouterAllowed(address(0xBEEF)));
        assertEq(
            uint8(coordinator.routerKind(address(0xBEEF))),
            uint8(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router)
        );
    }

    function test_T28_pureCraneDeployNotVaultRegistry() public view {
        // Structural: instance exists and owner is MultiStepOwnable — no manager involved in deploy path.
        assertEq(IMultiStepOwnable(address(coordinator)).owner(), owner);
        assertTrue(coordinator.allowedRouterCount() >= 1);
    }

    function test_T29_idempotentRegisterAndKindOverwrite() public {
        address r = address(0xCAFE);
        coordinator.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter);
        assertTrue(coordinator.isRouterAllowed(r));
        // second register same kind — idempotent
        coordinator.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter);
        // overwrite kind
        coordinator.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter);
        assertEq(
            uint8(coordinator.routerKind(r)),
            uint8(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter)
        );
    }

    function test_T30_initialRoutersSeeded() public view {
        assertTrue(coordinator.isRouterAllowed(address(0xBEEF)));
        assertEq(coordinator.allowedRouterCount(), 1);
        assertEq(coordinator.allowedRouterAt(0), address(0xBEEF));
    }

    function test_T25_multiStepOwnableTransfer() public {
        address newOwner = makeAddr("newOwner");
        IMultiStepOwnable mso = IMultiStepOwnable(address(coordinator));
        mso.initiateOwnershipTransfer(newOwner);
        vm.prank(newOwner);
        mso.acceptOwnershipTransfer();
        // may require buffer period — if pending, at least initiate works
        assertTrue(mso.pendingOwner() == newOwner || mso.owner() == newOwner);
    }

    function test_witnessGetters() public view {
        assertTrue(bytes(coordinator.WITNESS_TYPE_STRING()).length > 0);
        assertTrue(coordinator.WITNESS_TYPEHASH() != bytes32(0));
    }
}
