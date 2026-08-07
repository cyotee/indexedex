// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {
    SwapPathExactAmountIn,
    SwapPathStep
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/BatchRouterTypes.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/// @notice T3/T4 stock hops + query/allowance against RouterMock + 80/20 weighted pool.
contract BalancerV3UniswapV4CoordinatorRouter_ExactIn_Stock_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();

        aliceUser = vm.addr(alicePk);
        recipient = makeAddr("coordRecipient");

        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](2);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(router), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        seed[1] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(batchRouter),
            kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3BatchRouter
        });
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: address(this), initialRouters: seed});
        coordinator = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, permit2, IWETH(address(weth)), address(0), args
        );

        dai.mint(aliceUser, 10_000e18);
        vm.startPrank(aliceUser);
        dai.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function test_T3_stockSingleHop_previewEqualsExecute() public {
        address tokenOut = address(usdc);
        address tokenIn = address(dai);
        // Ensure token order matches pool: if pool is usdc/dai order for swap direction
        bytes memory stepData = abi.encode(pool, tokenIn, tokenOut, uint256(0), false, bytes(""));

        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: tokenOut, minAmountOut: 0, data: stepData
        });

        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _params(tokenIn, 10e18, tokenOut, steps);
        // Balancer query requires tx.origin == 0 (eth_call / Foundry static-call prank).
        // Snapshot+revert: Vault.quote leaves transient unlock; same-tx execute would see dirty state.
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        uint256 quoted = coordinator.queryExactIn(params);
        vm.revertToState(snap);

        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 0);

        uint256 beforeOut = IERC20(tokenOut).balanceOf(recipient);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);

        assertEq(IERC20(tokenOut).balanceOf(recipient) - beforeOut, amountOut);
        assertGt(amountOut, 0);
        assertEq(amountOut, quoted);
    }

    function test_T4_stockBatchSingleRoot() public {
        SwapPathStep[] memory pathSteps = new SwapPathStep[](1);
        pathSteps[0] = SwapPathStep({pool: pool, tokenOut: IERC20(address(usdc)), isBuffer: false});
        SwapPathExactAmountIn[] memory paths = new SwapPathExactAmountIn[](1);
        paths[0] =
            SwapPathExactAmountIn({tokenIn: IERC20(address(dai)), steps: pathSteps, exactAmountIn: 0, minAmountOut: 0});
        bytes memory stepData = abi.encode(paths, false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(batchRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 5e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 1);
        vm.prank(aliceUser);
        assertGt(coordinator.swapExactInWithPermit(params, permit, sig), 0);
    }

    function test_T4_multiRootBatchReverts() public {
        SwapPathStep[] memory pathSteps = new SwapPathStep[](1);
        pathSteps[0] = SwapPathStep({pool: pool, tokenOut: IERC20(address(usdc)), isBuffer: false});
        SwapPathExactAmountIn[] memory paths = new SwapPathExactAmountIn[](2);
        paths[0] =
            SwapPathExactAmountIn({tokenIn: IERC20(address(dai)), steps: pathSteps, exactAmountIn: 0, minAmountOut: 0});
        paths[1] = paths[0];
        bytes memory stepData = abi.encode(paths, false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(batchRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 1e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 2);
        vm.prank(aliceUser);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_T23_permit2AllowanceCleared() public {
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 2e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 3);
        vm.prank(aliceUser);
        coordinator.swapExactInWithPermit(params, permit, sig);
        (uint160 amount,,) = permit2.allowance(address(coordinator), address(dai), address(router));
        assertEq(uint256(amount), 0);
    }

    /// @dev T11: global minAmountOut not met.
    function test_T11_globalMinOutReverts() public {
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 1e18, address(usdc), steps);
        params.minAmountOut = type(uint256).max;
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 11);
        vm.prank(aliceUser);
        vm.expectRevert();
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @dev T12: per-step minAmountOut not met.
    function test_T12_stepMinOutReverts() public {
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: type(uint256).max, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 1e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 12);
        vm.prank(aliceUser);
        vm.expectRevert();
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @dev T13: happy-path full-route witness succeeds (explicit; same path as T3 execute).
    function test_T13_happyPathWitness() public {
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 3e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 13);
        uint256 beforeOut = IERC20(address(usdc)).balanceOf(recipient);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(IERC20(address(usdc)).balanceOf(recipient) - beforeOut, amountOut);
    }

    /// @dev T22: stock-only allowlist — unregistered SE address reverts.
    function test_T22_stockOnlyAllowlistBlocksOther() public {
        address fakeSe = address(0x5E);
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: fakeSe, tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 1e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 22);
        vm.prank(aliceUser);
        vm.expectRevert(abi.encodeWithSelector(IBalancerV3UniswapV4CoordinatorRouter.RouterNotAllowed.selector, fakeSe));
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function _params(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps
    ) internal view returns (IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory) {
        return IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
            recipient: recipient,
            tokenIn: tokenIn,
            amountIn: amountIn,
            tokenOut: tokenOut,
            minAmountOut: 1,
            deadline: block.timestamp + 1 days,
            ethIn: false,
            ethOut: false,
            steps: steps
        });
    }

    function _sign(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params, uint256 nonce)
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature)
    {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: params.tokenIn, amount: params.amountIn}),
            nonce: nonce,
            deadline: block.timestamp + 1 days
        });
        bytes32 stepsHash = keccak256(abi.encode(params.steps));
        bytes32 witness = keccak256(
            abi.encode(
                coordinator.WITNESS_TYPEHASH(),
                params.recipient,
                params.tokenIn,
                params.amountIn,
                params.tokenOut,
                params.minAmountOut,
                params.deadline,
                params.ethIn,
                params.ethOut,
                stepsHash
            )
        );
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                permit.permitted.token,
                permit.permitted.amount
            )
        );
        bytes32 permitWitnessTypehash = keccak256(
            abi.encodePacked(
                "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Witness witness)",
                "TokenPermissions(address token,uint256 amount)",
                "Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)"
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                permitWitnessTypehash,
                tokenPermissionsHash,
                address(coordinator),
                permit.nonce,
                permit.deadline,
                witness
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
