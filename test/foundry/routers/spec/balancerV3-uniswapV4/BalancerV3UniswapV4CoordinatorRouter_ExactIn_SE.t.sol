// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/// @notice T5/T6 SE hops against a real SE diamond on the lean 8020 weighted vault fixture
///         (avoids full SE TestBase + Aerodrome graph → stack-too-deep under via_ir).
contract BalancerV3UniswapV4CoordinatorRouter_ExactIn_SE_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3StandardExchangeRouter_FactoryService for *;
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3StandardExchangeRouterProxy internal seRouter;
    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal signerPk = 0xA11CE;
    address internal signer;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();

        signer = vm.addr(signerPk);
        recipient = makeAddr("coordSeRecipient");

        seRouter = _deploySeRouter();
        coordinator = _deployCoordinator(address(seRouter));

        dai.mint(signer, 10_000e18);
        vm.startPrank(signer);
        dai.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function _deploySeRouter() internal returns (IBalancerV3StandardExchangeRouterProxy se) {
        IFacet senderGuard = IFacet(address(new SenderGuardFacet()));
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        pkgInit.senderGuardFacet = senderGuard;
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        pkgInit.balancerV3StandardExchangePermit2WitnessFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.permit2 = permit2;
        pkgInit.weth = IWETH(address(weth));

        IBalancerV3StandardExchangeRouterDFPkg sePkg =
            create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        se = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(sePkg);
    }

    function _deployCoordinator(address se) internal returns (IBalancerV3UniswapV4CoordinatorRouter coord) {
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: se, kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter
        });
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: address(this), initialRouters: seed});
        coord = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, permit2, IWETH(address(weth)), address(0), args
        );
    }

    /// @dev T5: SE single direct hop; queryExactIn == execute.
    function test_T5_seSingleHop_previewEqualsExecute() public {
        address pool = address(daiUsdc8020WeightedPool);
        bytes memory stepData = abi.encode(
            uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.SingleExactIn),
            pool,
            address(dai),
            address(0),
            address(usdc),
            address(0),
            uint256(0),
            false,
            bytes("")
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(seRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });

        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 10e18, address(usdc), steps);

        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        uint256 quoted = coordinator.queryExactIn(params);
        vm.revertToState(snap);

        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 0);
        uint256 beforeOut = IERC20(address(usdc)).balanceOf(recipient);
        vm.prank(signer);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);

        assertEq(IERC20(address(usdc)).balanceOf(recipient) - beforeOut, amountOut);
        assertGt(amountOut, 0);
        assertEq(amountOut, quoted);
    }

    /// @dev T6: SE batch single-root.
    function test_T6_seBatchSingleRoot() public {
        bytes memory stepData = _encodeSeBatch(address(dai), address(daiUsdc8020WeightedPool), address(usdc));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(seRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 5e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 1);
        vm.prank(signer);
        assertGt(coordinator.swapExactInWithPermit(params, permit, sig), 0);
    }

    function test_T6_seBatchMultiRootReverts() public {
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory pathSteps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        pathSteps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdc8020WeightedPool),
            tokenOut: IERC20(address(usdc)),
            isBuffer: false,
            isStrategyVault: false
        });
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](2);
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: pathSteps, exactAmountIn: 0, minAmountOut: 0
        });
        paths[1] = paths[0];
        bytes memory stepData =
            abi.encode(uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.BatchExactIn), paths, false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(seRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 1e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 2);
        vm.prank(signer);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_T23_sePermit2AllowanceCleared() public {
        bytes memory stepData = abi.encode(
            uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.SingleExactIn),
            address(daiUsdc8020WeightedPool),
            address(dai),
            address(0),
            address(usdc),
            address(0),
            uint256(0),
            false,
            bytes("")
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(seRouter), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(dai), 2e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 3);
        vm.prank(signer);
        coordinator.swapExactInWithPermit(params, permit, sig);
        (uint160 amount,,) = permit2.allowance(address(coordinator), address(dai), address(seRouter));
        assertEq(uint256(amount), 0);
    }

    function _encodeSeBatch(address tokenIn, address pool, address tokenOut) internal pure returns (bytes memory) {
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory pathSteps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        pathSteps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: pool, tokenOut: IERC20(tokenOut), isBuffer: false, isStrategyVault: false
        });
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(tokenIn), steps: pathSteps, exactAmountIn: 0, minAmountOut: 0
        });
        return
            abi.encode(uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.BatchExactIn), paths, false, bytes(""));
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
