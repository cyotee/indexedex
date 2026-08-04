// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {V4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/lens/V4Quoter.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {PathKey} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PathKey.sol";
import {
    PoolModifyLiquidityTest
} from "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/PoolModifyLiquidityTest.sol";
import {UniversalRouter} from "@crane/contracts/external/uniswap/universal-router/UniversalRouter.sol";
import {RouterParameters} from "@crane/contracts/external/uniswap/universal-router/types/RouterParameters.sol";
import {IUniversalRouter} from "@crane/contracts/external/uniswap/universal-router/interfaces/IUniversalRouter.sol";
import {Commands} from "@crane/contracts/external/uniswap/universal-router/libraries/Commands.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

/// @notice T7/T8 Template A/B execute+query; T24 bad template.
contract BalancerV3UniswapV4CoordinatorRouter_ExactIn_UR_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    IWETH internal wethTok;
    IUniversalRouter internal ur;
    V4Quoter internal quoter;
    PoolManager internal manager;
    PoolModifyLiquidityTest internal liqRouter;
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;
    SimpleMintableERC20 internal tokenC;
    PoolKey internal keyAB;
    PoolKey internal keyBC;
    bool internal zeroForOneAB;

    function setUp() public override {
        super.setUp();
        wethTok = IWETH(address(new WETHTestToken()));
        tokenA = new SimpleMintableERC20("A", "A");
        tokenB = new SimpleMintableERC20("B", "B");
        tokenC = new SimpleMintableERC20("C", "C");
        manager = new PoolManager(address(this));
        quoter = new V4Quoter(IPoolManager(address(manager)));
        liqRouter = new PoolModifyLiquidityTest(IPoolManager(address(manager)));

        RouterParameters memory params = RouterParameters({
            permit2: address(permit2),
            weth9: address(wethTok),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(manager),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            spokePool: address(0)
        });
        ur = IUniversalRouter(address(new UniversalRouter(params)));

        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(ur), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter
        });
        _deployCoordinator(wethTok, address(quoter), seed);

        // Sort tokens for pool keys
        (address a0, address a1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        keyAB = PoolKey({
            currency0: Currency.wrap(a0),
            currency1: Currency.wrap(a1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        zeroForOneAB = address(tokenA) == a0;

        (address b0, address b1) =
            address(tokenB) < address(tokenC) ? (address(tokenB), address(tokenC)) : (address(tokenC), address(tokenB));
        keyBC = PoolKey({
            currency0: Currency.wrap(b0),
            currency1: Currency.wrap(b1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        manager.initialize(keyAB, SQRT_PRICE_1_1);
        manager.initialize(keyBC, SQRT_PRICE_1_1);
        _seedLiquidity(keyAB);
        _seedLiquidity(keyBC);

        tokenA.mint(alice, 100_000e18);
        tokenB.mint(alice, 100_000e18);
        vm.startPrank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        tokenB.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function _seedLiquidity(PoolKey memory key) internal {
        address t0 = Currency.unwrap(key.currency0);
        address t1 = Currency.unwrap(key.currency1);
        SimpleMintableERC20(t0).mint(address(this), 1_000_000e18);
        SimpleMintableERC20(t1).mint(address(this), 1_000_000e18);
        SimpleMintableERC20(t0).approve(address(liqRouter), type(uint256).max);
        SimpleMintableERC20(t1).approve(address(liqRouter), type(uint256).max);
        // Full-range-ish ticks for spacing 60
        int24 tickLower = -887220;
        int24 tickUpper = 887220;
        liqRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(1_000_000e18)),
                salt: bytes32(0)
            }),
            bytes("")
        );
    }

    function test_T7_urCommandsConstantAndAllowlist() public view {
        assertEq(Commands.V4_SWAP, 0x10);
        assertTrue(coordinator.isRouterAllowed(address(ur)));
    }

    function test_T24_badTemplateRevertsInvalidStepData() public {
        bytes memory bad = abi.encode(uint8(99), uint256(1));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(ur), tokenOut: address(tokenB), minAmountOut: 0, data: bad
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(tokenA), 1e18, address(tokenB), steps);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData.selector);
        coordinator.queryExactIn(params);
    }

    /// @dev T7 Template A: successful queryExactIn + execute via liquid V4 pool.
    function test_T7_templateA_queryAndExecute() public {
        bool zfo = zeroForOneAB;
        address tokenIn = address(tokenA);
        address tokenOut = address(tokenB);
        bytes memory data = abi.encode(uint8(1), keyAB, zfo, bytes(""), uint128(0));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(ur), tokenOut: tokenOut, minAmountOut: 0, data: data
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _params(tokenIn, 10e18, tokenOut, steps);

        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        uint256 quoted = coordinator.queryExactIn(params);
        vm.revertToState(snap);
        assertGt(quoted, 0);

        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 7, block.timestamp + 1 days);
        uint256 before = SimpleMintableERC20(tokenOut).balanceOf(bob);
        vm.prank(alice);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(SimpleMintableERC20(tokenOut).balanceOf(bob) - before, amountOut);
        assertEq(amountOut, quoted);
    }

    /// @dev T8 Template B multi-hop A→B→C via two V4 pools.
    function test_T8_templateB_multiHopExecute() public {
        // currencyIn = tokenA; path: A→B then B→C
        Currency currencyIn = Currency.wrap(address(tokenA));
        PathKey[] memory path = new PathKey[](2);
        // hop to B
        {
            (address x0, address x1) = address(tokenA) < address(tokenB)
                ? (address(tokenA), address(tokenB))
                : (address(tokenB), address(tokenA));
            // intermediate is B
            path[0] = PathKey({
                intermediateCurrency: Currency.wrap(address(tokenB)),
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(address(0)),
                hookData: bytes("")
            });
            // silence unused
            x0;
            x1;
        }
        path[1] = PathKey({
            intermediateCurrency: Currency.wrap(address(tokenC)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0)),
            hookData: bytes("")
        });

        bytes memory data = abi.encode(uint8(2), currencyIn, path, uint128(0));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(ur), tokenOut: address(tokenC), minAmountOut: 0, data: data
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _params(address(tokenA), 5e18, address(tokenC), steps);

        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        uint256 quoted = coordinator.queryExactIn(params);
        vm.revertToState(snap);
        assertGt(quoted, 0);

        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 8, block.timestamp + 1 days);
        uint256 before = tokenC.balanceOf(bob);
        vm.prank(alice);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(tokenC.balanceOf(bob) - before, amountOut);
        assertEq(amountOut, quoted);
    }

    function _params(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps
    ) internal view returns (IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory) {
        return IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
            recipient: bob,
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
