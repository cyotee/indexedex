// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {Commands} from "@crane/contracts/external/uniswap/universal-router/libraries/Commands.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/// @notice Base-main fork smoke: deploy Coordinator + live venue hop (stock Balancer when code present).
/// @dev FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/routers/balancerV3-uniswapV4/*' -vv
contract BalancerV3UniswapV4CoordinatorRouter_BaseMain_Fork_Test is CraneTest {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    address constant PERMIT2_BASE = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH_BASE = 0x4200000000000000000000000000000000000006;
    address constant UNIVERSAL_ROUTER_BASE = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    // Liquid Base Balancer V3 weighted pool (WETH + paired token) with non-zero live balances.
    address constant LIVE_WETH_PAIR_POOL = 0x8ccAE9702cBBBbA7a4E3752354987d67f496dEDb;
    address constant LIVE_POOL_TOKEN_OUT = 0xBe68bd4a8D4977Eee7b87775411877d73Fc8cdF3;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;

    function setUp() public override {
        super.setUp();
        aliceUser = vm.addr(alicePk);

        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed;
        uint256 n;
        if (UNIVERSAL_ROUTER_BASE.code.length > 0) n++;
        if (BASE_MAIN.BALANCER_V3_ROUTER.code.length > 0) n++;
        seed = new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](n);
        uint256 i;
        if (UNIVERSAL_ROUTER_BASE.code.length > 0) {
            seed[i++] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
                router: UNIVERSAL_ROUTER_BASE,
                kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter
            });
        }
        if (BASE_MAIN.BALANCER_V3_ROUTER.code.length > 0) {
            seed[i++] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
                router: BASE_MAIN.BALANCER_V3_ROUTER,
                kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
            });
        }

        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: address(this), initialRouters: seed});

        coordinator = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, IPermit2(PERMIT2_BASE), IWETH(WETH_BASE), address(0), args
        );
    }

    function test_fork_deployAndAllowlistLiveUR() public view {
        assertTrue(address(coordinator) != address(0));
        assertEq(uint256(Commands.V4_SWAP), 0x10);
        if (UNIVERSAL_ROUTER_BASE.code.length > 0) {
            assertTrue(coordinator.isRouterAllowed(UNIVERSAL_ROUTER_BASE));
            assertEq(
                uint8(coordinator.routerKind(UNIVERSAL_ROUTER_BASE)),
                uint8(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter)
            );
        }
    }

    function test_fork_witnessSurface() public view {
        assertTrue(bytes(coordinator.WITNESS_TYPE_STRING()).length > 20);
        assertTrue(coordinator.WITNESS_TYPEHASH() != bytes32(0));
    }

    /// @dev Live stock Balancer hop: WETH → paired token on a liquid Base V3 pool via Coordinator.
    function test_fork_liveStockBalancerHop() public {
        address stockRouter = BASE_MAIN.BALANCER_V3_ROUTER;
        require(stockRouter.code.length > 0, "stock router missing");
        require(LIVE_WETH_PAIR_POOL.code.length > 0, "pool missing");
        assertTrue(coordinator.isRouterAllowed(stockRouter));

        // Pool WETH side is thin (~7e12 wei); keep hop tiny to avoid MaxInRatio.
        uint256 amountIn = 1e9;
        vm.deal(aliceUser, amountIn);
        vm.startPrank(aliceUser);
        IWETH(WETH_BASE).deposit{value: amountIn}();
        IERC20(WETH_BASE).approve(PERMIT2_BASE, type(uint256).max);
        vm.stopPrank();

        bytes memory stepData =
            abi.encode(LIVE_WETH_PAIR_POOL, WETH_BASE, LIVE_POOL_TOKEN_OUT, uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: stockRouter, tokenOut: LIVE_POOL_TOKEN_OUT, minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: aliceUser,
                tokenIn: WETH_BASE,
                amountIn: amountIn,
                tokenOut: LIVE_POOL_TOKEN_OUT,
                minAmountOut: 1,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });

        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 1);
        uint256 before = IERC20(LIVE_POOL_TOKEN_OUT).balanceOf(aliceUser);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(IERC20(LIVE_POOL_TOKEN_OUT).balanceOf(aliceUser) - before, amountOut);
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
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", IPermit2(PERMIT2_BASE).DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
