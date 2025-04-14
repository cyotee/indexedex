// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

contract BalancerV3_ExactOut_Regression is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant SWAP_AMOUNT = 10e18;
    uint256 internal constant MAX_AMOUNT_IN = 100e18;

    IBalancerV3StandardExchangeBatchRouterExactOut internal batchExactOutRouter;

    function setUp() public override {
        super.setUp();
        batchExactOutRouter = IBalancerV3StandardExchangeBatchRouterExactOut(address(seRouter));
    }

    /// @notice Regression test: previewExchangeOut must match actual executed input when using small surplus and pretransferred flows
    function test_regression_previewMatchesExec_pretransferred() public {
        // Provide Alice with LP tokens
        uint256 lpAmount = _fundUserWithLP(alice, MAX_AMOUNT_IN * 3);

        // Prepare approvals and capture balances
        vm.startPrank(alice);
        IERC20(address(aeroDaiUsdcPool)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(aeroDaiUsdcPool), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 expectedAmountIn =
            daiUsdcVault.previewExchangeOut(IERC20(address(aeroDaiUsdcPool)), IERC20(address(dai)), SWAP_AMOUNT);
        require(expectedAmountIn > 0, "Preview non-zero");

        // Add a tiny 0.1% surplus to avoid AMM rounding failures
        uint256 maxAmountIn = expectedAmountIn + (expectedAmountIn / 1000);
        require(maxAmountIn <= lpAmount, "Not enough LP for test");

        uint256 aliceDaiBefore = dai.balanceOf(alice);
        uint256 aliceLpBefore = IERC20(address(aeroDaiUsdcPool)).balanceOf(alice);

        // Build batch path using the strategy vault step
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

        // Assert preview matches executed input
        assertEq(actualAmountIn, expectedAmountIn, "Preview must match executed amountIn");

        // Assert exact output received
        assertEq(aliceDaiAfter - aliceDaiBefore, SWAP_AMOUNT, "Should receive exact DAI amount");

        // Assert LP spent equals actualAmountIn
        uint256 lpSpent = aliceLpBefore - aliceLpAfter;
        assertEq(lpSpent, actualAmountIn, "LP spent should equal actualAmountIn");
    }

    /* -------------------------------------------------------------------------- */
    /*                           Helper Functions                                 */
    /* -------------------------------------------------------------------------- */

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
