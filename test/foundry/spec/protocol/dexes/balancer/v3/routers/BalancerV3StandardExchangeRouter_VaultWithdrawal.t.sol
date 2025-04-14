// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_VaultWithdrawal_Test
 * @notice Tests for the Strategy Vault Withdrawal route.
 * @dev Strategy Vault Withdrawal: User withdraws underlying tokens from a vault via the router.
 *      Route: vault shares (tokenIn) -> vault.exchangeIn/exchangeOut() -> tokenOut
 *      Conditions: pool == tokenOutVault, tokenIn == tokenOutVault, tokenOut != tokenOutVault
 */
contract BalancerV3StandardExchangeRouter_VaultWithdrawal_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant DEPOSIT_AMOUNT = 100e18;
    uint256 internal shareBalance;

    function setUp() public override {
        super.setUp();
        // Pre-deposit to get some vault shares for alice
        shareBalance = _depositToVault(alice, DEPOSIT_AMOUNT);
    }

    /* ---------------------------------------------------------------------- */
    /*                        ExactIn Withdrawal Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_vaultWithdrawal_exactIn_sharesToDai() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        // Approve vault shares for permit2 and router
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        // Execute withdrawal: vault shares -> DAI
        // pool = vault, tokenIn = vault (shares), tokenInVault = 0, tokenOut = DAI, tokenOutVault = vault
        uint256 daiReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool
            IERC20(address(daiUsdcVault)), // tokenIn (vault shares)
            _noVault(), // tokenInVault (none)
            IERC20(address(dai)), // tokenOut
            daiUsdcVault, // tokenOutVault
            sharesToWithdraw, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify shares were spent
        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Shares not spent correctly");

        // Verify DAI was received
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "DAI not received correctly");
        assertGt(daiReceived, 0, "Should receive DAI");
    }

    function test_vaultWithdrawal_exactIn_sharesToUsdc() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        // Approve vault shares for permit2 and router
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Execute withdrawal: vault shares -> USDC
        uint256 usdcReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool
            IERC20(address(daiUsdcVault)), // tokenIn (vault shares)
            _noVault(), // tokenInVault
            IERC20(address(usdc)), // tokenOut
            daiUsdcVault, // tokenOutVault
            sharesToWithdraw, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify shares were spent
        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Shares not spent correctly");

        // Verify USDC was received
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "USDC not received correctly");
        assertGt(usdcReceived, 0, "Should receive USDC");
    }

    function test_vaultWithdrawal_exactIn_queryVsExec() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        // Query expected output
        vm.prank(address(0), address(0));
        uint256 expectedDai = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            alice,
            ""
        );

        vm.startPrank(alice);

        // Approve
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        // Execute withdrawal
        uint256 actualDai = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        // Query and execution should match closely
        assertApproxEqAbs(actualDai, expectedDai, 1, "Query vs exec mismatch");
    }

    function test_vaultWithdrawal_exactIn_slippage_reverts() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        // Query expected output
        vm.prank(address(0), address(0));
        uint256 expectedDai = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            alice,
            ""
        );

        vm.startPrank(alice);

        // Approve
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        // Try to execute with unreasonably high minAmountOut
        uint256 unreasonableMin = expectedDai * 2;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            unreasonableMin,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    function test_vaultWithdrawal_exactIn_multipleWithdrawals() public {
        uint256 withdrawAmount = shareBalance / 4;

        vm.startPrank(alice);

        // Approve
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);

        // First withdrawal
        uint256 dai1 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            withdrawAmount,
            1,
            _deadline(),
            false,
            ""
        );

        // Second withdrawal
        uint256 dai2 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            withdrawAmount,
            1,
            _deadline(),
            false,
            ""
        );

        // Third withdrawal
        uint256 dai3 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            withdrawAmount,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify total DAI received
        assertEq(daiBalAfter - daiBalBefore, dai1 + dai2 + dai3, "Total DAI mismatch");

        // Shares should yield roughly similar DAI for equal amounts
        assertApproxEqRel(dai1, dai2, 0.1e18, "Withdrawal consistency issue");
    }

    function test_vaultWithdrawal_exactIn_fullWithdrawal() public {
        vm.startPrank(alice);

        // Approve
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        // Withdraw all shares
        uint256 daiReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            shareBalBefore,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify all shares were spent
        assertEq(shareBalAfter, 0, "Should have no shares left");

        // Verify DAI was received
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "DAI balance mismatch");
        assertGt(daiReceived, 0, "Should receive DAI");
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactOut Withdrawal Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_vaultWithdrawal_exactOut_sharesToDai() public {
        // ExactOut withdrawal: specify exact DAI to receive, burn variable shares

        vm.startPrank(alice);

        // Approve
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactDaiWanted = 10e18;
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        // Execute withdrawal: vault shares -> exact DAI
        uint256 sharesSpent = seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            exactDaiWanted,
            shareBalance, // max shares to spend
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify shares were spent
        assertEq(shareBalBefore - shareBalAfter, sharesSpent, "Shares spent mismatch");
        assertGt(sharesSpent, 0, "Should spend shares");

        // Verify exact DAI was received
        assertEq(daiBalAfter - daiBalBefore, exactDaiWanted, "Should receive exact DAI wanted");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_vaultWithdrawal_routerNoRetention() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));

        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 routerSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));
        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));

        // Router should not retain any tokens
        assertEq(routerSharesAfter, routerSharesBefore, "Router should not retain shares");
        assertEq(routerDaiAfter, routerDaiBefore, "Router should not retain DAI");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_vaultWithdrawal_exactIn(uint256 withdrawPct) public {
        // Bound withdrawal percentage (1-99% of shares)
        withdrawPct = bound(withdrawPct, 1, 99);
        uint256 sharesToWithdraw = shareBalance * withdrawPct / 100;

        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        uint256 daiReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify shares were spent
        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Shares mismatch");

        // Verify DAI was received
        assertGt(daiReceived, 0, "Should receive DAI");
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "DAI balance mismatch");
    }
}
