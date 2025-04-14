// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_BatchExactIn_Test
 * @notice Tests for the BatchExactIn facet functions.
 * @dev Batch router allows multi-step swaps through multiple pools/vaults in a single transaction.
 */
contract BalancerV3StandardExchangeRouter_BatchExactIn_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant SWAP_AMOUNT = 100e18;

    // Cast router to batch interface
    IBalancerV3StandardExchangeBatchRouterExactIn internal batchExactInRouter;

    function setUp() public override {
        super.setUp();
        batchExactInRouter = IBalancerV3StandardExchangeBatchRouterExactIn(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                    Single Path - Direct Pool Swap                      */
    /* ---------------------------------------------------------------------- */

    function test_swapExactIn_singlePath_directSwap() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Pre-transfer DAI to vault (batch router uses prepaid settlement pattern)
        dai.transfer(address(vault), SWAP_AMOUNT);
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
        assertGt(usdcBalAfter - usdcBalBefore, 0, "Should receive USDC");
        assertEq(pathAmountsOut.length, 1, "Should have 1 path amount out");
        assertGt(pathAmountsOut[0], 0, "Path should have output");
    }

    function test_swapExactIn_singlePath_queryVsExec() public {
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

        // Query expected output
        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsOut,,) = batchExactInRouter.querySwapExactIn(paths, alice, "");

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Execute swap
        (uint256[] memory actualAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        // Query and execution should match
        assertEq(actualAmountsOut.length, expectedAmountsOut.length, "Length mismatch");
        assertApproxEqAbs(actualAmountsOut[0], expectedAmountsOut[0], 1, "Query vs exec mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Single Path - Strategy Vault                       */
    /* ---------------------------------------------------------------------- */

    function test_swapExactIn_singlePath_strategyVaultDeposit() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 vaultSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Build path: DAI -> daiUsdcVault (deposit) -> vault shares
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(daiUsdcVault)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Execute batch swap
        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 vaultSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "DAI not spent correctly");

        // Verify vault shares were received
        assertGt(vaultSharesAfter - vaultSharesBefore, 0, "Should receive vault shares");
        assertEq(vaultSharesAfter - vaultSharesBefore, pathAmountsOut[0], "Vault shares mismatch");
    }

    function test_swapExactIn_singlePath_strategyVaultWithdrawal() public {
        uint256 shareBalance = _depositToVault(alice, SWAP_AMOUNT);
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        // Approve vault shares for permit2 and router
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);

        // Build path: vault shares -> daiUsdcVault (withdraw) -> DAI
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(daiUsdcVault)), steps: steps, exactAmountIn: sharesToWithdraw, minAmountOut: 1
        });

        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        assertEq(daiBalAfter - daiBalBefore, pathAmountsOut[0], "DAI mismatch");
        assertGt(pathAmountsOut[0], 0, "Should receive DAI");
    }

    function test_swapExactIn_singlePath_threeSteps_withWithdrawSwapDeposit_queryVsExec() public {
        uint256 shareBalance = _depositToVault(alice, SWAP_AMOUNT);
        uint256 sharesToSwap = shareBalance / 3;

        // Approvals must exist even for query mode because the quote path executes real token movements.
        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](3);

        // Step 1: withdraw shares -> DAI
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });
        // Step 2: swap DAI -> USDC
        steps[1] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        // Step 3: deposit USDC -> shares
        steps[2] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(daiUsdcVault)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(daiUsdcVault)), steps: steps, exactAmountIn: sharesToSwap, minAmountOut: 1
        });

        // `querySwapExactIn` executes a real path during `vault.quote` (including token movement).
        // Snapshot so we can compare against an execution that runs on identical state.
        uint256 snapshotId = vm.snapshotState();

        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsOut,,) = batchExactInRouter.querySwapExactIn(paths, alice, "");

        vm.revertToState(snapshotId);

        vm.startPrank(alice);
        (uint256[] memory actualAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");
        vm.stopPrank();

        assertEq(actualAmountsOut.length, expectedAmountsOut.length, "Length mismatch");
        assertApproxEqAbs(actualAmountsOut[0], expectedAmountsOut[0], 1, "Query vs exec mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Multiple Paths                                */
    /* ---------------------------------------------------------------------- */

    function test_swapExactIn_multiplePaths() public {
        // Mint tokens to alice
        dai.mint(alice, SWAP_AMOUNT);
        usdc.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve tokens
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        // Pre-transfer tokens to vault (batch router uses prepaid settlement pattern)
        dai.transfer(address(vault), SWAP_AMOUNT);
        usdc.transfer(address(vault), SWAP_AMOUNT);

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
        assertEq(pathAmountsOut.length, 2, "Should have 2 path amounts out");
        assertGt(pathAmountsOut[0], 0, "Path 1 should have output");
        assertGt(pathAmountsOut[1], 0, "Path 2 should have output");
    }

    function test_swapExactIn_multiplePaths_twoStepsAndThreeSteps() public {
        // Path 1 uses prepaid settlement pattern (tokenIn is not a strategy vault).
        dai.mint(alice, SWAP_AMOUNT);
        vm.prank(alice);
        dai.transfer(address(vault), SWAP_AMOUNT);

        // Path 2 starts from vault shares.
        uint256 shareBalance = _depositToVault(alice, SWAP_AMOUNT);
        uint256 sharesToSwap = shareBalance / 4;

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](2);

        // Path 1: DAI -> USDC
        {
            IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps1 =
                new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
            steps1[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
                pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
            });
            paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
                tokenIn: IERC20(address(dai)), steps: steps1, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
            });
        }

        // Path 2: shares -> DAI -> USDC (2 steps)
        {
            IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps2 =
                new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](2);
            steps2[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
                pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
            });
            steps2[1] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
                pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
            });
            paths[1] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
                tokenIn: IERC20(address(daiUsdcVault)), steps: steps2, exactAmountIn: sharesToSwap, minAmountOut: 1
            });
        }

        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactIn(paths, _deadline(), false, "");

        vm.stopPrank();

        assertEq(pathAmountsOut.length, 2, "Should have 2 path amounts out");
        assertGt(pathAmountsOut[0], 0, "Path 1 should have output");
        assertGt(pathAmountsOut[1], 0, "Path 2 should have output");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Slippage Tests                               */
    /* ---------------------------------------------------------------------- */

    function test_swapExactIn_slippage_reverts() public {
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

    function test_swapExactIn_deadline_reverts() public {
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

    function test_swapExactIn_routerNoRetention() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Pre-transfer DAI to vault (batch router uses prepaid settlement pattern)
        dai.transfer(address(vault), SWAP_AMOUNT);

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
        assertEq(routerDaiAfter, routerDaiBefore, "Router should not retain DAI");
        assertEq(routerUsdcAfter, routerUsdcBefore, "Router should not retain USDC");
    }
}
