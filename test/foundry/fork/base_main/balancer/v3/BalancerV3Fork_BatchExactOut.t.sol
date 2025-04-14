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
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {TestBase_BalancerV3Fork} from "./TestBase_BalancerV3Fork.sol";

/**
 * @title BalancerV3Fork_BatchExactOut_Test
 * @notice Fork tests for BatchExactOut router operations on Base mainnet.
 * @dev Tests batch routing functionality with exact output swaps.
 *      Validates that the IndexedEx batch router works correctly with live
 *      Balancer V3 Vault infrastructure.
 *
 *      Note: This test focuses on direct pool swaps. Strategy vault operations
 *      would require additional infrastructure to deploy IndexedEx vaults
 *      wrapping Aerodrome pools on mainnet.
 */
contract BalancerV3Fork_BatchExactOut_Test is TestBase_BalancerV3Fork {
    uint256 internal constant SWAP_AMOUNT = 100e18;
    uint256 internal constant MAX_AMOUNT_IN = 200e18;

    IBalancerV3StandardExchangeBatchRouterExactOut internal batchExactOutRouter;

    function setUp() public override {
        super.setUp();
        batchExactOutRouter = IBalancerV3StandardExchangeBatchRouterExactOut(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                    Single Path - Direct Pool Swap                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactOut_singlePath_directSwap() public {
        // Mint DAI to alice (more than needed for maxAmountIn)
        dai.mint(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Build single path: DAI -> daiUsdcPool -> exact USDC out
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT
        });

        // Execute batch swap
        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify exact USDC was received
        assertGe(usdcBalAfter - usdcBalBefore, SWAP_AMOUNT, "Fork: Should receive at least exact USDC");

        // Verify results
        assertEq(pathAmountsIn.length, 1, "Fork: Should have 1 path amount in");
        assertGt(pathAmountsIn[0], 0, "Fork: Path should have input");
        assertLe(pathAmountsIn[0], MAX_AMOUNT_IN, "Fork: Should not exceed max amount in");
    }

    function test_fork_swapExactOut_singlePath_queryVsExec() public {
        // Mint DAI to alice
        dai.mint(alice, MAX_AMOUNT_IN);

        // Build single path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT
        });

        vm.startPrank(alice);

        // Approve for both query and execution
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        vm.stopPrank();

        // Query expected input (with snapshot to preserve state)
        uint256 snapshot = vm.snapshotState();

        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsIn,,) = batchExactOutRouter.querySwapExactOut(paths, alice, "");

        vm.revertToState(snapshot);

        vm.startPrank(alice);

        // Execute swap
        (uint256[] memory actualAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        // Query and execution should match
        assertEq(actualAmountsIn.length, expectedAmountsIn.length, "Fork: Length mismatch");
        assertApproxEqAbs(actualAmountsIn[0], expectedAmountsIn[0], 1, "Fork: Query vs exec mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Multiple Paths                                */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactOut_multiplePaths() public {
        // Mint tokens to alice
        dai.mint(alice, MAX_AMOUNT_IN);
        usdc.mint(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);

        // Approve tokens
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        // Build two paths:
        // Path 1: DAI -> exact USDC out
        // Path 2: USDC -> exact DAI out
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](2);

        // Path 1: DAI -> USDC
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps1 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps1[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps1, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT / 2
        });

        // Path 2: USDC -> DAI
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps2 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps2[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: false
        });
        paths[1] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(usdc)), steps: steps2, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT / 2
        });

        // Execute batch swap
        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        // Verify both paths produced input amounts
        assertEq(pathAmountsIn.length, 2, "Fork: Should have 2 path amounts in");
        assertGt(pathAmountsIn[0], 0, "Fork: Path 1 should have input");
        assertGt(pathAmountsIn[1], 0, "Fork: Path 2 should have input");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Slippage Tests                               */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactOut_slippage_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Build path with unreasonably low maxAmountIn
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)),
            steps: steps,
            maxAmountIn: 1, // Unreasonably low maximum
            exactAmountOut: SWAP_AMOUNT
        });

        // Should revert due to slippage
        vm.expectRevert();
        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();
    }

    function test_fork_swapExactOut_deadline_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT
        });

        // Expired deadline
        uint256 expiredDeadline = block.timestamp - 1;

        // Should revert due to expired deadline
        vm.expectRevert();
        batchExactOutRouter.swapExactOut(paths, expiredDeadline, false, "");

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Router Safety Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_fork_swapExactOut_routerNoRetention() public {
        // Mint DAI to alice
        dai.mint(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, maxAmountIn: MAX_AMOUNT_IN, exactAmountOut: SWAP_AMOUNT
        });

        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

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

    function testFuzz_fork_swapExactOut_directSwap(uint256 amountOut) public {
        // Bound swap amount to reasonable range
        amountOut = bound(amountOut, 1e18, 500e18);

        // Mint more than enough DAI to alice
        uint256 maxIn = amountOut * 2;
        dai.mint(alice, maxIn);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, maxAmountIn: maxIn, exactAmountOut: amountOut
        });

        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify exact USDC was received
        assertGe(usdcBalAfter - usdcBalBefore, amountOut, "Fork fuzz: Should receive at least exact USDC");
        assertLe(pathAmountsIn[0], maxIn, "Fork fuzz: Should not exceed max amount in");
    }
}
