// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

/**
 * @title BalancerV3Fork_VaultWithdrawal_Test
 * @notice Fork tests for the Strategy Vault Withdrawal route on Base mainnet.
 * @dev Mirrors `BalancerV3StandardExchangeRouter_VaultWithdrawal.t.sol`.
 */
contract BalancerV3Fork_VaultWithdrawal_Test is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant DEPOSIT_AMOUNT = 100e18;
    uint256 internal shareBalance;

    function setUp() public override {
        super.setUp();
        // Pre-deposit to get some vault shares for alice.
        shareBalance = _depositToVault(alice, DEPOSIT_AMOUNT);
    }

    /* ---------------------------------------------------------------------- */
    /*                        ExactIn Withdrawal Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultWithdrawal_exactIn_sharesToDai() public {
        uint256 sharesToWithdraw = shareBalance / 2;

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

        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Fork: Shares not spent correctly");
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "Fork: DAI not received correctly");
        assertGt(daiReceived, 0, "Fork: Should receive DAI");
    }

    function test_fork_vaultWithdrawal_exactIn_sharesToUsdc() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        uint256 usdcReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(usdc)),
            daiUsdcVault,
            sharesToWithdraw,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Fork: Shares not spent correctly");
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "Fork: USDC not received correctly");
        assertGt(usdcReceived, 0, "Fork: Should receive USDC");
    }

    function test_fork_vaultWithdrawal_exactIn_queryVsExec() public {
        uint256 sharesToWithdraw = shareBalance / 2;

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

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

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

        assertApproxEqAbs(actualDai, expectedDai, 1, "Fork: Query vs exec mismatch");
    }

    function test_fork_vaultWithdrawal_exactIn_slippage_reverts() public {
        uint256 sharesToWithdraw = shareBalance / 2;

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

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

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

    function test_fork_vaultWithdrawal_exactIn_multipleWithdrawals() public {
        uint256 withdrawAmount = shareBalance / 4;

        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);

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

        assertEq(daiBalAfter - daiBalBefore, dai1 + dai2 + dai3, "Fork: Total DAI mismatch");
        assertApproxEqRel(dai1, dai2, 0.1e18, "Fork: Withdrawal consistency issue");
    }

    function test_fork_vaultWithdrawal_exactIn_fullWithdrawal() public {
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
            shareBalBefore,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        assertEq(shareBalAfter, 0, "Fork: Should have no shares left");
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "Fork: DAI balance mismatch");
        assertGt(daiReceived, 0, "Fork: Should receive DAI");
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactOut Withdrawal Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultWithdrawal_exactOut_sharesToDai() public {
        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactDaiWanted = 10e18;
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        uint256 sharesSpent = seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            exactDaiWanted,
            shareBalance,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        assertEq(shareBalBefore - shareBalAfter, sharesSpent, "Fork: Shares spent mismatch");
        assertGt(sharesSpent, 0, "Fork: Should spend shares");
        assertEq(daiBalAfter - daiBalBefore, exactDaiWanted, "Fork: Should receive exact DAI");
    }

    function test_fork_vaultWithdrawal_exactOut_limitExceeded_reverts() public {
        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactDaiWanted = 10e18;
        uint256 unreasonableMax = 1; // Very low max - should revert

        vm.expectRevert();
        seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            exactDaiWanted,
            unreasonableMax,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultWithdrawal_routerNoRetention() public {
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

        assertEq(routerSharesAfter, routerSharesBefore, "Fork: Router should not retain shares");
        assertEq(routerDaiAfter, routerDaiBefore, "Fork: Router should not retain DAI");
    }

    function test_fork_vaultWithdrawal_deadline_reverts() public {
        uint256 sharesToWithdraw = shareBalance / 2;

        vm.startPrank(alice);

        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            sharesToWithdraw,
            1,
            expiredDeadline,
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_vaultWithdrawal_exactIn(uint256 withdrawPct) public {
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

        assertEq(shareBalBefore - shareBalAfter, sharesToWithdraw, "Fork: Shares mismatch");
        assertGt(daiReceived, 0, "Fork: Should receive DAI");
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "Fork: DAI balance mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    function _depositToVault(address user, uint256 lpAmount) internal returns (uint256 shares) {
        // Mint DAI/USDC to user and add liquidity on Aerodrome to mint LP tokens.
        dai.mint(user, lpAmount);
        usdc.mint(user, lpAmount);

        vm.startPrank(user);

        dai.approve(address(aerodromeRouter), lpAmount);
        usdc.approve(address(aerodromeRouter), lpAmount);

        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(usdc), false, lpAmount, lpAmount, 1, 1, user, block.timestamp + 1 hours
        );

        // Deposit LP tokens into the strategy vault.
        IERC20(address(aeroDaiUsdcPool)).approve(address(daiUsdcVault), liquidity);
        shares = daiUsdcVault.deposit(liquidity, user);

        vm.stopPrank();
    }
}
