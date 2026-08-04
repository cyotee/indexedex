// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";
import {
    CoordinatorSeRouterDeployLib
} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorSeRouterDeployLib.sol";
import {
    CoordinatorWitnessSignLib
} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorWitnessSignLib.sol";

/// @notice T9 interleaved multi-family exact-in + T26 donation-safe ledger.
contract BalancerV3UniswapV4CoordinatorRouter_ExactIn_Interleaved_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3StandardExchangeRouterProxy internal seRouter;
    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();
        aliceUser = vm.addr(alicePk);
        recipient = makeAddr("interleaveRecipient");
        seRouter = CoordinatorSeRouterDeployLib.deploy(
            create3Factory, diamondPackageFactory, IVault(address(vault)), permit2, IWETH(address(weth))
        );
        _deployCoordinator();
        dai.mint(aliceUser, 100_000e18);
        usdc.mint(aliceUser, 100_000e18);
        vm.startPrank(aliceUser);
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function _deployCoordinator() internal {
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](2);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(router), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        seed[1] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(seRouter), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter
        });
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: address(this), initialRouters: seed});
        coordinator = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, permit2, IWETH(address(weth)), address(0), args
        );
    }

    /// @dev T9: 3 steps, 2 families (stock → SE → stock).
    function test_T9_threeStepStockSeStock() public {
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](3);
        steps[0] = _stock(address(dai), address(usdc));
        steps[1] = _se(address(usdc), address(dai));
        steps[2] = _stock(address(dai), address(usdc));

        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _p(address(dai), 20e18, address(usdc), steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            CoordinatorWitnessSignLib.sign(Vm(address(vm)), permit2, coordinator, params, alicePk, 9);
        uint256 before = IERC20(address(usdc)).balanceOf(recipient);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(IERC20(address(usdc)).balanceOf(recipient) - before, amountOut);
        assertEq(IERC20(address(usdc)).balanceOf(address(coordinator)), 0);
    }

    /// @dev T10: stock → SE → stock (same as T9; documents batch family via SE hop using SE adapter).
    function test_T10_multiFamilyThreeStep() public {
        test_T9_threeStepStockSeStock();
    }

    /// @dev T26: donate intermediate USDC; hop2 must not spend donation.
    function test_T26_donationDoesNotInflateNextHopInput() public {
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](2);
        steps[0] = _stock(address(dai), address(usdc));
        steps[1] = _se(address(usdc), address(dai));
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _p(address(dai), 10e18, address(dai), steps);

        (ISignatureTransfer.PermitTransferFrom memory permit0, bytes memory sig0) =
            CoordinatorWitnessSignLib.sign(Vm(address(vm)), permit2, coordinator, params, alicePk, 26);
        vm.prank(aliceUser);
        uint256 out0 = coordinator.swapExactInWithPermit(params, permit0, sig0);

        usdc.mint(address(coordinator), 500e18);
        (ISignatureTransfer.PermitTransferFrom memory permit1, bytes memory sig1) =
            CoordinatorWitnessSignLib.sign(Vm(address(vm)), permit2, coordinator, params, alicePk, 27);
        vm.prank(aliceUser);
        uint256 out1 = coordinator.swapExactInWithPermit(params, permit1, sig1);
        assertEq(IERC20(address(usdc)).balanceOf(address(coordinator)), 500e18);
        assertLt(out1, out0 * 2);
        assertGt(out1, out0 / 2);
    }

    function _stock(address tokenIn, address tokenOut)
        internal
        view
        returns (IBalancerV3UniswapV4CoordinatorRouter.RouteStep memory)
    {
        return IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router),
            tokenOut: tokenOut,
            minAmountOut: 0,
            data: abi.encode(pool, tokenIn, tokenOut, uint256(0), false, bytes(""))
        });
    }

    function _se(address tokenIn, address tokenOut)
        internal
        view
        returns (IBalancerV3UniswapV4CoordinatorRouter.RouteStep memory)
    {
        return IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(seRouter),
            tokenOut: tokenOut,
            minAmountOut: 0,
            data: abi.encode(
                uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.SingleExactIn),
                pool,
                tokenIn,
                address(0),
                tokenOut,
                address(0),
                uint256(0),
                false,
                bytes("")
            )
        });
    }

    function _p(
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
}
