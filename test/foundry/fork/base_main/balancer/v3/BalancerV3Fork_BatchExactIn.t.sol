// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {TestBase_BalancerV3Fork} from "./TestBase_BalancerV3Fork.sol";

/**
 * @title BalancerV3Fork_BatchExactIn_Test
 * @notice Fork tests for BatchExactIn router operations on Base mainnet.
 * @dev Tests batch routing functionality with direct pool swaps.
 *      Validates that the IndexedEx batch router works correctly with live
 *      Balancer V3 Vault infrastructure.
 *
 *      Note: This test focuses on direct pool swaps. Strategy vault operations
 *      (deposit, withdraw, pass-through) would require additional infrastructure
 *      to deploy IndexedEx vaults wrapping Aerodrome pools on mainnet.
 */
contract BalancerV3Fork_BatchExactIn_Test is TestBase_BalancerV3Fork {
    uint256 internal constant SWAP_AMOUNT = 100e18;

    IBalancerV3StandardExchangeBatchRouterExactIn internal batchExactInRouter;

    function setUp() public override {
        super.setUp();
        batchExactInRouter = IBalancerV3StandardExchangeBatchRouterExactIn(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                    Single Path - Direct Pool Swap                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactIn_singlePath_directSwap() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Build single path: DAI -> daiUsdcPool -> USDC
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Execute batch swap
        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify USDC was received
        assertGt(usdcBalAfter - usdcBalBefore, 0, "Fork: Should receive USDC");
        assertEq(pathAmountsOut.length, 1, "Fork: Should have 1 path amount out");
        assertGt(pathAmountsOut[0], 0, "Fork: Path should have output");
    }

    function test_fork_swapExactIn_singlePath_queryVsExec() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        // Build single path
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        vm.startPrank(alice);

        // Approve for both query and execution
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        vm.stopPrank();

        // Query expected output (with snapshot to preserve state)
        uint256 snapshot = vm.snapshotState();

        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsOut,,) = batchExactInRouter.querySwapExactIn(paths, alice, "");

        vm.revertToState(snapshot);

        vm.startPrank(alice);

        // Execute swap
        (uint256[] memory actualAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        // Query and execution should match
        assertEq(actualAmountsOut.length, expectedAmountsOut.length, "Fork: Length mismatch");
        assertApproxEqAbs(actualAmountsOut[0], expectedAmountsOut[0], 1, "Fork: Query vs exec mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Multiple Paths                                */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactIn_multiplePaths() public {
        // Mint tokens to alice
        dai.mint(alice, SWAP_AMOUNT);
        usdc.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve tokens
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        // Build two paths:
        // Path 1: DAI -> USDC
        // Path 2: USDC -> DAI
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](2);

        // Path 1: DAI -> USDC
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps1 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps1[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps1, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Path 2: USDC -> DAI
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps2 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps2[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: false
        });
        paths[1] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(usdc)), steps: steps2, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Execute batch swap
        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        // Verify both paths produced output
        assertEq(pathAmountsOut.length, 2, "Fork: Should have 2 path amounts out");
        assertGt(pathAmountsOut[0], 0, "Fork: Path 1 should have output");
        assertGt(pathAmountsOut[1], 0, "Fork: Path 2 should have output");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Slippage Tests                               */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactIn_slippage_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Build path with unreasonably high minAmountOut
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)),
            steps: steps,
            exactAmountIn: SWAP_AMOUNT,
            minAmountOut: type(uint256).max // Unreasonable minimum
        });

        // Should revert due to slippage
        vm.expectRevert();
        batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();
    }

    function test_fork_swapExactIn_deadline_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Expired deadline
        uint256 expiredDeadline = block.timestamp - 1;

        // Should revert due to expired deadline
        vm.expectRevert();
        batchExactInRouter.swapExactIn(paths, expiredDeadline, false, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Router Safety Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactIn_routerNoRetention() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));
        uint256 routerUsdcAfter = usdc.balanceOf(address(seRouter));

        // Router should not retain any tokens
        assertEq(routerDaiAfter, routerDaiBefore, "Fork: Router should not retain DAI");
        assertEq(routerUsdcAfter, routerUsdcBefore, "Fork: Router should not retain USDC");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_swapExactIn_directSwap(uint256 swapAmount) public {
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 500e18);

        // Mint DAI to alice
        dai.mint(alice, swapAmount);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: swapAmount, minAmountOut: 1
        });

        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify USDC was received
        assertGt(usdcBalAfter - usdcBalBefore, 0, "Fork fuzz: Should receive USDC");
        assertEq(usdcBalAfter - usdcBalBefore, pathAmountsOut[0], "Fork fuzz: Balance matches path output");
    }
}
