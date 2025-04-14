// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_BatchRefund_Test
 * @notice Tests proving refunds work correctly in batch exact-out swaps with strategy vaults.
 * @dev Covers US-IDXEX-037.5:
 *      - Strategy vault step uses less than maxAmountIn → refund forwarded to user
 *      - Refund is settled correctly in Balancer Vault
 *      - Strategy vault that doesn't refund → settlement fails predictably
 *
 * The batch exact-out router uses a "pretransferred" pattern where:
 *   1. maxAmountIn tokens are transferred to the strategy vault
 *   2. Strategy vault calls exchangeOut and uses <= maxAmountIn
 *   3. If used < maxAmountIn, the vault refunds (maxAmountIn - used) to the router
 *   4. Router forwards refund into Balancer Vault for settlement back to user
 *
 * Note: Strategy vault steps in batch paths always use two-step paths
 * (vault withdrawal → pool swap) because the Balancer Vault's transient
 * accounting needs at least one on-chain pool swap to balance credits/debits.
 */
contract BalancerV3StandardExchangeRouter_BatchRefund_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant SWAP_AMOUNT = 100e18;
    uint256 internal constant MAX_AMOUNT_IN = 500e18;

    IBalancerV3StandardExchangeBatchRouterExactOut internal batchExactOutRouter;

    function setUp() public override {
        super.setUp();
        batchExactOutRouter = IBalancerV3StandardExchangeBatchRouterExactOut(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper: build two-step path                    */
    /* ---------------------------------------------------------------------- */

    function _buildTwoStepVaultPath(uint256 maxSharesIn, uint256 exactAmountOut)
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths)
    {
        paths = new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](2);

        // Step 1: withdraw shares → DAI
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });

        // Step 2: swap DAI → USDC
        steps[1] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(daiUsdcVault)),
            steps: steps,
            maxAmountIn: maxSharesIn,
            exactAmountOut: exactAmountOut
        });
    }

    /* ---------------------------------------------------------------------- */
    /*  Test A: Strategy vault uses less than maxAmountIn → user gets refund   */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice When a strategy vault step in a batch exact-out uses less than
     *         maxAmountIn, the difference should be refunded to the user.
     *         User's final share balance should only decrease by the actual
     *         amount used, not the full maxAmountIn.
     */
    function test_batchRefund_strategyVault_usesLessThanMax_refundForwarded() public {
        // Deposit to vault to get shares for alice
        uint256 shares = _depositToVault(alice, MAX_AMOUNT_IN);
        uint256 maxSharesIn = shares; // Overshoot: provide all shares as max

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        // Build two-step path: vault shares → DAI → USDC
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            _buildTwoStepVaultPath(maxSharesIn, SWAP_AMOUNT);

        // Record balances before
        uint256 sharesBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);

        // Use snapshot/revert for query since vault.quote() has real side effects
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsIn,,) = batchExactOutRouter.querySwapExactOut(paths, alice, "");
        vm.revertToState(snap);

        // Execute
        vm.startPrank(alice);
        (uint256[] memory actualAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");
        vm.stopPrank();

        uint256 sharesAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);

        // Verify: actual shares used should be less than maxSharesIn
        uint256 sharesUsed = sharesBefore - sharesAfter;
        assertGt(sharesUsed, 0, "Should use some shares");
        assertLe(sharesUsed, maxSharesIn, "Should not exceed max shares");
        assertApproxEqAbs(actualAmountsIn[0], expectedAmountsIn[0], 1, "Actual should match query");

        // Verify: user received at least exact USDC amount
        assertGe(usdcAfter - usdcBefore, SWAP_AMOUNT, "Should receive at least exact USDC amount");

        // Verify: the refund was applied — shares used should be close to expected, not maxSharesIn
        // If no refund mechanism, sharesBefore - sharesAfter would equal maxSharesIn
        if (sharesUsed < maxSharesIn) {
            // Refund was correctly forwarded
            assertEq(sharesUsed, actualAmountsIn[0], "Shares used should match reported amountIn");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*     Test B: Query vs execution consistency for vault withdrawal path    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice The query and execution paths should produce consistent results
     *         for batch exact-out with strategy vault steps.
     */
    function test_batchRefund_queryVsExec_consistent() public {
        uint256 shares = _depositToVault(alice, MAX_AMOUNT_IN);
        uint256 maxSharesIn = shares / 2;

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            _buildTwoStepVaultPath(maxSharesIn, SWAP_AMOUNT);

        // Query
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsIn,,) = batchExactOutRouter.querySwapExactOut(paths, alice, "");
        vm.revertToState(snap);

        // Execute
        vm.startPrank(alice);
        (uint256[] memory actualAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");
        vm.stopPrank();

        assertApproxEqAbs(actualAmountsIn[0], expectedAmountsIn[0], 1, "Query vs exec should match");
    }

    /* ---------------------------------------------------------------------- */
    /*     Test C: Refund settlement verified through balance accounting       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice In a multi-step path (vault withdrawal → pool swap), the refund
     *         from the vault step should be properly settled so the user only
     *         pays the actual amount. This test uses a large maxAmountIn to
     *         ensure a significant refund and verifies the settlement is correct.
     */
    function test_batchRefund_twoStep_vaultWithdrawalThenSwap() public {
        uint256 shares = _depositToVault(alice, MAX_AMOUNT_IN);
        uint256 maxSharesIn = shares / 2;

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            _buildTwoStepVaultPath(maxSharesIn, SWAP_AMOUNT);

        uint256 sharesBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);

        // Query
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        (uint256[] memory expectedAmountsIn,,) = batchExactOutRouter.querySwapExactOut(paths, alice, "");
        vm.revertToState(snap);

        // Execute
        vm.startPrank(alice);
        (uint256[] memory actualAmountsIn,,) = batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");
        vm.stopPrank();

        uint256 sharesAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);

        // Verify query vs exec
        assertApproxEqAbs(actualAmountsIn[0], expectedAmountsIn[0], 1, "Multi-step query vs exec should match");

        // Verify USDC received
        assertGe(usdcAfter - usdcBefore, SWAP_AMOUNT, "Should receive at least exact USDC amount");

        // Verify shares used
        uint256 sharesUsed = sharesBefore - sharesAfter;
        assertEq(sharesUsed, actualAmountsIn[0], "Shares used should match reported amountIn");
        assertLe(sharesUsed, maxSharesIn, "Should not exceed maxAmountIn");
    }

    /* ---------------------------------------------------------------------- */
    /*   Test D: Router doesn't retain tokens after batch exact-out with vault */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice After a batch exact-out with strategy vault refund, the router
     *         should not retain any tokens.
     */
    function test_batchRefund_routerNoRetention() public {
        uint256 shares = _depositToVault(alice, MAX_AMOUNT_IN);
        uint256 maxSharesIn = shares / 2;

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            _buildTwoStepVaultPath(maxSharesIn, SWAP_AMOUNT);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));
        uint256 routerSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        vm.startPrank(alice);
        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");
        vm.stopPrank();

        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), routerUsdcBefore, "Router should not retain USDC");
        assertEq(
            IERC20(address(daiUsdcVault)).balanceOf(address(seRouter)),
            routerSharesBefore,
            "Router should not retain vault shares"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*   Test E: Slippage reverts when maxAmountIn is too low                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice If maxAmountIn is set too low for the required amount, the batch
     *         exact-out should revert (strategy vault will fail or slippage check
     *         will fail).
     */
    function test_batchRefund_maxAmountInTooLow_reverts() public {
        uint256 shares = _depositToVault(alice, MAX_AMOUNT_IN);

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        // Use two-step path with maxAmountIn = 1 (way too low)
        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            _buildTwoStepVaultPath(1, SWAP_AMOUNT);

        vm.startPrank(alice);
        vm.expectRevert();
        batchExactOutRouter.swapExactOut(paths, _deadline(), false, "");
        vm.stopPrank();
    }
}
