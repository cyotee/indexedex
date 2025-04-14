// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

/**
 * @title BalancerV3_ExactOut_Fork_Test
 * @notice Fork tests for Balancer V3 batch router exact-out with pretransferred refund semantics.
 * @dev Tests the integration between Balancer V3 batch router and IndexedEx strategy vaults,
 *      verifying that excess pretransferred tokens are correctly refunded to the caller.
 *
 *      Acceptance Criteria:
 *      - Fork test exercises `exchangeOut` via Balancer V3 batch router
 *      - Verifies pretransferred refund is returned to caller
 *      - Verifies exact output amount is received
 *      - Test passes on Base mainnet fork
 *
 *      Origin: IDXEX-034 code review, Suggestion 1
 */
contract BalancerV3_ExactOut_Fork_Test is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant SWAP_AMOUNT = 10e18;
    uint256 internal constant MAX_AMOUNT_IN = 100e18;

    IBalancerV3StandardExchangeBatchRouterExactOut internal batchExactOutRouter;

    function setUp() public override {
        super.setUp();
        batchExactOutRouter = IBalancerV3StandardExchangeBatchRouterExactOut(address(seRouter));
    }

    /* -------------------------------------------------------------------------- */
    /*                    Pretransferred Refund Tests                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Tests that excess pretransferred LP tokens are refunded when using
     *         the Balancer V3 batch router with a strategy vault for exact-out swaps.
     * @dev This is the core test for IDXEX-057: verifies pretransferred refund semantics
     *      work correctly through the Balancer V3 batch router integration.
     */
    function test_fork_exactOut_pretransferredRefund_viaBatchRouter() public {
        // Setup: Alice needs LP tokens (from Aerodrome pool)
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 2);
        require(lpAmount > MAX_AMOUNT_IN, "Need sufficient LP tokens");

        vm.startPrank(alice);

        // Approve the router to pull LP tokens via Permit2
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        // Get preview to determine expected amountIn
        uint256 expectedAmountIn =
            daiUsdcVault.previewExchangeOut(IERC20(address(aeroDaiUsdcPool)), IERC20(address(dai)), SWAP_AMOUNT);
        require(expectedAmountIn > 0 && expectedAmountIn < MAX_AMOUNT_IN, "Preview in valid range");

        // Use maxAmountIn > expectedAmountIn to create surplus scenario
        uint256 maxAmountIn = expectedAmountIn * 2;
        require(maxAmountIn <= lpAmount, "Not enough LP for test");

        uint256 aliceDaiBefore = dai.balanceOf(alice);
        uint256 aliceLpBefore = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        // Build batch path using the strategy vault
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        // Strategy vault step: LP tokens in -> DAI out
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault),
            tokenOut: IERC20(address(dai)),
            isBuffer: false,
            isStrategyVault: true // This is a strategy vault!
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: maxAmountIn,
            exactAmountOut: SWAP_AMOUNT
        });

        // Execute batch swap - the router will pretransfer maxAmountIn to vault
        // and the vault should refund maxAmountIn - actualAmountIn
        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 aliceDaiAfter = dai.balanceOf(alice);
        uint256 aliceLpAfter = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        uint256 actualAmountIn = pathAmountsIn[0];
        uint256 expectedRefund = maxAmountIn - actualAmountIn;

        // Verification 1: Exact DAI amount received
        assertEq(aliceDaiAfter - aliceDaiBefore, SWAP_AMOUNT, "Should receive exact DAI amount");

        // Verification 2: Actual amountIn <= maxAmountIn (slippage protection)
        assertLe(actualAmountIn, maxAmountIn, "AmountIn should not exceed maxAmountIn");
        assertGt(actualAmountIn, 0, "AmountIn should be positive");

        // Verification 3: LP tokens were spent (not all returned)
        uint256 lpSpent = aliceLpBefore - aliceLpAfter;
        assertEq(lpSpent, actualAmountIn, "LP spent should equal actualAmountIn");

        // Verification 4: Refund was received (surplus LP returned)
        assertGt(expectedRefund, 0, "Should have refund when maxAmountIn > actualAmountIn");
        assertEq(
            aliceLpAfter,
            aliceLpBefore - actualAmountIn,
            "Caller should retain unspent LP tokens (refunded via batch settlement)"
        );
    }

    /**
     * @notice Tests exact-out swap via batch router with minimal surplus.
     * @dev Uses a small surplus (0.1%) on maxAmountIn to account for AMM rounding.
     *      Constant product AMMs like Aerodrome can produce 1-2 wei rounding errors,
     *      so a tiny surplus ensures the swap succeeds while still verifying the
     *      core behavior that minimal LP tokens are consumed.
     */
    function test_fork_exactOut_pretransferredMinimalSurplus_smallRefund() public {
        // Setup: Alice needs LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 3);

        vm.startPrank(alice);

        // Approve the router
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        // Get preview to determine expected amount
        uint256 expectedAmountIn =
            daiUsdcVault.previewExchangeOut(IERC20(address(aeroDaiUsdcPool)), IERC20(address(dai)), SWAP_AMOUNT);
        require(expectedAmountIn > 0, "Preview must be non-zero");

        // Use 0.1% surplus to account for AMM rounding (constant product math can produce 1-2 wei errors)
        uint256 maxAmountIn = expectedAmountIn + (expectedAmountIn / 1000);
        require(maxAmountIn <= lpAmount, "Not enough LP for test");

        uint256 aliceDaiBefore = dai.balanceOf(alice);
        uint256 aliceLpBefore = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        // Build batch path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: maxAmountIn,
            exactAmountOut: SWAP_AMOUNT
        });

        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 aliceDaiAfter = dai.balanceOf(alice);
        uint256 aliceLpAfter = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        uint256 actualAmountIn = pathAmountsIn[0];
        uint256 refund = maxAmountIn - actualAmountIn;

        // Verification: DAI received (must be exact)
        assertEq(aliceDaiAfter - aliceDaiBefore, SWAP_AMOUNT, "Should receive DAI amount");

        // Verification: Actual amountIn should match preview exactly
        assertEq(actualAmountIn, expectedAmountIn, "AmountIn should match preview");

        // Verification: Refund should be small (the surplus we added)
        assertLe(refund, expectedAmountIn / 1000 + 2, "Refund should be the surplus amount plus rounding");

        // Verification: Net LP spent equals actualAmountIn
        uint256 lpSpent = aliceLpBefore - aliceLpAfter;
        assertEq(lpSpent, actualAmountIn, "LP spent should equal actualAmountIn");
    }

    /**
     * @notice Tests that querySwapExactOut matches actual swap results for strategy vault.
     * @dev Validates that the query mechanism works correctly for strategy vault exact-out.
     *      Uses a 0.1% surplus on maxAmountIn to account for constant product AMM rounding.
     */
    function test_fork_exactOut_queryMatchesExec_strategyVault() public {
        // Setup: Alice needs LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 2);

        // Build path with 0.1% surplus to handle AMM rounding
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault),
            tokenOut: IERC20(address(usdc)), // Try USDC out this time
            isBuffer: false,
            isStrategyVault: true
        });

        // Use 0.1% surplus to account for constant product AMM rounding errors
        uint256 maxAmountIn = (MAX_AMOUNT_IN * 1001) / 1000;

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: maxAmountIn,
            exactAmountOut: SWAP_AMOUNT / 2
        });

        vm.startPrank(alice);

        // Approve for execution
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        vm.stopPrank();

        // Query expected input (with snapshot to preserve state)
        uint256 snapshot = vm.snapshotState();

        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsIn,,) = batchExactOutRouter.querySwapExactOut(paths, alice, "");

        vm.revertToState(snapshot);

        vm.startPrank(alice);

        uint256 aliceUsdcBefore = usdc.balanceOf(alice);

        // Execute swap
        (uint256[] memory actualAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 aliceUsdcAfter = usdc.balanceOf(alice);

        // Verification: Query and execution should match exactly
        assertEq(actualAmountsIn.length, expectedAmountsIn.length, "Length mismatch");
        assertEq(actualAmountsIn[0], expectedAmountsIn[0], "Query vs exec mismatch");

        // Verification: Exact USDC received
        assertEq(aliceUsdcAfter - aliceUsdcBefore, SWAP_AMOUNT / 2, "Should receive exact USDC");
    }

    /**
     * @notice Tests slippage protection reverts when maxAmountIn is insufficient.
     */
    function test_fork_exactOut_slippage_reverts() public {
        // Setup: Alice needs LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 2);

        vm.startPrank(alice);

        // Approve
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        // Get preview
        uint256 expectedAmountIn =
            daiUsdcVault.previewExchangeOut(IERC20(address(aeroDaiUsdcPool)), IERC20(address(dai)), SWAP_AMOUNT);
        require(expectedAmountIn > 0, "Preview must be non-zero");

        // Build path with maxAmountIn below required
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: expectedAmountIn / 2, // Unreasonably low
            exactAmountOut: SWAP_AMOUNT
        });

        // Should revert due to slippage (strategy vault maxAmount exceeded)
        vm.expectRevert();
        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();
    }

    /**
     * @notice Tests deadline enforcement for batch router exact-out with strategy vault.
     */
    function test_fork_exactOut_deadline_reverts() public {
        // Setup: Alice needs LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 2);

        vm.startPrank(alice);

        // Approve
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: MAX_AMOUNT_IN,
            exactAmountOut: SWAP_AMOUNT
        });

        // Expired deadline
        uint256 expiredDeadline = block.timestamp - 1;

        // Should revert due to expired deadline
        vm.expectRevert();
        batchExactOutRouter.swapExactOut(paths, expiredDeadline, false, "");

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Router Safety Tests                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Tests that the router doesn't retain any tokens after the swap.
     */
    function test_fork_exactOut_routerNoRetention() public {
        // Setup: Alice needs LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 2);

        vm.startPrank(alice);

        // Approve
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerLpBefore = IERC20(address(aeroDaiUsdcPool)).balanceOf(address(seRouter));

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: MAX_AMOUNT_IN,
            exactAmountOut: SWAP_AMOUNT
        });

        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));
        uint256 routerLpAfter = IERC20(address(aeroDaiUsdcPool)).balanceOf(address(seRouter));

        // Router should not retain any tokens
        assertEq(routerDaiAfter, routerDaiBefore, "Router should not retain DAI");
        assertEq(routerLpAfter, routerLpBefore, "Router should not retain LP tokens");
    }

    /* -------------------------------------------------------------------------- */
    /*                            Fuzz Tests                                    */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Fuzz test for exact-out with varying surplus amounts.
     * @dev Tests the core invariant that exact output is received while varying the surplus.
     *      Minimum 0.1% surplus required to account for constant product AMM rounding errors.
     */
    function testFuzz_fork_exactOut_pretransferredRefund(uint256 surplusPct) public {
        // Bound surplus to 0.1% - 100% (minimum 0.1% to handle AMM rounding)
        surplusPct = bound(surplusPct, 1, 100);

        // Setup: Alice needs plenty of LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 10);

        // Get preview
        uint256 expectedAmountIn =
            daiUsdcVault.previewExchangeOut(IERC20(address(aeroDaiUsdcPool)), IERC20(address(dai)), SWAP_AMOUNT);
        vm.assume(expectedAmountIn > 0);
        vm.assume(expectedAmountIn < lpAmount / 2);

        // Calculate maxAmountIn with surplus (add 0.1% minimum to handle AMM rounding, then add fuzzed surplus)
        uint256 maxAmountIn = expectedAmountIn + (expectedAmountIn / 1000) + (expectedAmountIn * surplusPct / 100);
        vm.assume(maxAmountIn <= lpAmount);

        vm.startPrank(alice);

        // Approve
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 aliceDaiBefore = dai.balanceOf(alice);
        uint256 aliceLpBefore = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        // Build path
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);

        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(aeroDaiUsdcPool)),
            steps: steps,
            maxAmountIn: maxAmountIn,
            exactAmountOut: SWAP_AMOUNT
        });

        (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");

        vm.stopPrank();

        uint256 aliceDaiAfter = dai.balanceOf(alice);
        uint256 aliceLpAfter = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        uint256 actualAmountIn = pathAmountsIn[0];

        // Invariant: Exact DAI received (no rounding issues since we use surplus)
        assertEq(aliceDaiAfter - aliceDaiBefore, SWAP_AMOUNT, "Fuzz: Should receive exact DAI");

        // Invariant: Actual amountIn <= maxAmountIn
        assertLe(actualAmountIn, maxAmountIn, "Fuzz: AmountIn should not exceed maxAmountIn");

        // Invariant: Net LP spent equals actualAmountIn
        uint256 lpSpent = aliceLpBefore - aliceLpAfter;
        assertEq(lpSpent, actualAmountIn, "Fuzz: LP spent should equal actualAmountIn");
    }

    /* -------------------------------------------------------------------------- */
    /*                           Helper Functions                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Funds a user with LP tokens from the Aerodrome pool.
     * @param user The address to fund
     * @param lpAmount The amount of LP tokens to provide
     * @return actualLpAmount The actual amount of LP tokens received
     */
    function _fundUserWithLP(address user, uint256 lpAmount) internal returns (uint256 actualLpAmount) {
        // Mint DAI and USDC to this contract
        dai.mint(address(this), lpAmount);
        usdc.mint(address(this), lpAmount);

        // Approve Aerodrome router
        dai.approve(address(aerodromeRouter), lpAmount);
        usdc.approve(address(aerodromeRouter), lpAmount);

        // Add liquidity to get LP tokens for the user
        (,, actualLpAmount) = aerodromeRouter.addLiquidity(
            address(dai),
            address(usdc),
            false, // stable = false (volatile pool)
            lpAmount,
            lpAmount,
            1, // min amount A
            1, // min amount B
            user, // LP tokens go to user
            block.timestamp + 1 hours
        );
    }
}
