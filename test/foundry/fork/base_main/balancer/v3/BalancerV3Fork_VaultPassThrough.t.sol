// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

/**
 * @title BalancerV3Fork_VaultPassThrough_Test
 * @notice Fork tests for the Vault Pass-Through Swap route on Base mainnet.
 * @dev Mirrors `BalancerV3StandardExchangeRouter_VaultPassThrough.t.sol`.
 */
contract BalancerV3Fork_VaultPassThrough_Test is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant SWAP_AMOUNT = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                        ExactIn Pass-Through Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultPassThrough_exactIn_daiToUsdc() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        uint256 usdcReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "Fork: DAI not spent correctly");
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "Fork: USDC not received correctly");
        assertGt(usdcReceived, 0, "Fork: Should receive USDC");
    }

    function test_fork_vaultPassThrough_exactIn_usdcToDai() public {
        usdc.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        uint256 daiReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(usdc)),
            daiUsdcVault,
            IERC20(address(dai)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        assertEq(usdcBalBefore - usdcBalAfter, SWAP_AMOUNT, "Fork: USDC not spent correctly");
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "Fork: DAI not received correctly");
        assertGt(daiReceived, 0, "Fork: Should receive DAI");
    }

    function test_fork_vaultPassThrough_exactIn_queryVsExec() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.prank(address(0), address(0));
        uint256 expectedUsdc = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 actualUsdc = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        assertApproxEqAbs(actualUsdc, expectedUsdc, 1, "Fork: Query vs exec mismatch");
    }

    function test_fork_vaultPassThrough_exactIn_slippage_reverts() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.prank(address(0), address(0));
        uint256 expectedUsdc = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 unreasonableMin = expectedUsdc * 2;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            unreasonableMin,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    function test_fork_vaultPassThrough_exactIn_multipleSwaps() public {
        dai.mint(alice, SWAP_AMOUNT * 3);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);

        uint256 usdc1 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        uint256 usdc2 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        uint256 usdc3 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);

        assertEq(usdcBalAfter - usdcBalBefore, usdc1 + usdc2 + usdc3, "Fork: Total USDC mismatch");
        assertGt(usdc1, usdc3, "Fork: First swap should be better than third");
    }

    function test_fork_vaultPassThrough_noVaultSharesCreated() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 aliceSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 routerSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 aliceSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);
        uint256 routerSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        assertEq(aliceSharesAfter, aliceSharesBefore, "Fork: Alice should not receive shares");
        assertEq(routerSharesAfter, routerSharesBefore, "Fork: Router should not retain shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactOut Pass-Through Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultPassThrough_exactOut_daiToUsdc() public {
        dai.mint(alice, SWAP_AMOUNT * 2);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactUsdcWanted = 50e18;
        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        uint256 daiSpent = seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            exactUsdcWanted,
            SWAP_AMOUNT * 2,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, daiSpent, "Fork: DAI spent mismatch");
        assertGt(daiSpent, 0, "Fork: Should spend DAI");
        assertGe(usdcBalAfter - usdcBalBefore, exactUsdcWanted, "Fork: Should receive at least exact USDC");
    }

    function test_fork_vaultPassThrough_exactOut_queryVsExec() public {
        dai.mint(alice, SWAP_AMOUNT * 2);

        uint256 exactUsdcWanted = 50e18;

        vm.prank(address(0), address(0));
        uint256 expectedDaiIn = seRouter.querySwapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            exactUsdcWanted,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 actualDaiIn = seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            exactUsdcWanted,
            SWAP_AMOUNT * 2,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        assertApproxEqAbs(actualDaiIn, expectedDaiIn, 1, "Fork: Query vs exec mismatch");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultPassThrough_routerNoRetention() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));

        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));
        uint256 routerUsdcAfter = usdc.balanceOf(address(seRouter));

        assertEq(routerDaiAfter, routerDaiBefore, "Fork: Router should not retain DAI");
        assertEq(routerUsdcAfter, routerUsdcBefore, "Fork: Router should not retain USDC");
    }

    function test_fork_vaultPassThrough_deadline_reverts() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            SWAP_AMOUNT,
            1,
            expiredDeadline,
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Vault Pass-Through WETH Unwrap Tests                 */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultPassThrough_exactIn_daiToWeth_noUnwrap() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 wethBalBefore = weth.balanceOf(alice);

        uint256 wethReceived = seRouter.swapSingleTokenExactIn(
            address(daiWethVault),
            IERC20(address(dai)),
            daiWethVault,
            IERC20(address(weth)),
            daiWethVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            false, // wethIsEth = false, do NOT unwrap
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 wethBalAfter = weth.balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "Fork: DAI not spent correctly");
        assertEq(wethBalAfter - wethBalBefore, wethReceived, "Fork: WETH not received correctly");
        assertGt(wethReceived, 0, "Fork: Should receive WETH");
    }

    function test_fork_vaultPassThrough_exactIn_daiToWeth_withUnwrap() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);

        uint256 ethReceived = seRouter.swapSingleTokenExactIn(
            address(daiWethVault),
            IERC20(address(dai)),
            daiWethVault,
            IERC20(address(weth)),
            daiWethVault,
            SWAP_AMOUNT,
            1,
            _deadline(),
            true, // wethIsEth = true, unwrap to ETH
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "Fork: DAI not spent correctly");
        assertGt(ethReceived, 0, "Fork: Should receive ETH");
    }

    function test_fork_vaultPassThrough_exactIn_daiToWeth_withUnwrap_slippage_reverts() public {
        dai.mint(alice, SWAP_AMOUNT);

        vm.prank(address(0), address(0));
        uint256 expectedEth = seRouter.querySwapSingleTokenExactIn(
            address(daiWethVault),
            IERC20(address(dai)),
            daiWethVault,
            IERC20(address(weth)),
            daiWethVault,
            SWAP_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 unreasonableMin = expectedEth * 2;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiWethVault),
            IERC20(address(dai)),
            daiWethVault,
            IERC20(address(weth)),
            daiWethVault,
            SWAP_AMOUNT,
            unreasonableMin,
            _deadline(),
            true, // wethIsEth = true, unwrap to ETH
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_vaultPassThrough_exactIn(uint256 swapAmount) public {
        swapAmount = bound(swapAmount, 1e18, 500e18);

        dai.mint(alice, swapAmount);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        uint256 usdcReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(usdc)),
            daiUsdcVault,
            swapAmount,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, swapAmount, "Fork: DAI balance mismatch");
        assertGt(usdcReceived, 0, "Fork: Should receive USDC");
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "Fork: USDC balance mismatch");
    }
}
