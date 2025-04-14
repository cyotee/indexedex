// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_VaultPassThrough_Test
 * @notice Tests for the Vault Pass-Through Swap route.
 * @dev Vault Pass-Through: The vault acts as the pool, performing a swap through its internal protocol.
 *      Route: tokenIn -> vault.exchangeIn() (swaps via underlying protocol) -> tokenOut
 *      Conditions: pool == tokenInVault == tokenOutVault, tokenIn != tokenInVault, tokenOut != tokenOutVault
 *
 *      This route allows swapping through a vault without depositing/withdrawing vault shares.
 *      The vault internally swaps the tokens using its underlying AMM (e.g., Aerodrome).
 */
contract BalancerV3StandardExchangeRouter_VaultPassThrough_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant SWAP_AMOUNT = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                        ExactIn Pass-Through Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_vaultPassThrough_exactIn_daiToUsdc() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Execute pass-through swap: DAI -> vault (swap) -> USDC
        // pool = vault, tokenInVault = vault, tokenOutVault = vault
        uint256 usdcReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool = vault (pass-through)
            IERC20(address(dai)), // tokenIn
            daiUsdcVault, // tokenInVault = vault
            IERC20(address(usdc)), // tokenOut
            daiUsdcVault, // tokenOutVault = vault
            SWAP_AMOUNT, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 usdcBalAfter = usdc.balanceOf(alice);

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "DAI not spent correctly");

        // Verify USDC was received
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "USDC not received correctly");
        assertGt(usdcReceived, 0, "Should receive USDC");
    }

    function test_vaultPassThrough_exactIn_usdcToDai() public {
        // Mint USDC to alice
        usdc.mint(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        // Approve USDC for permit2 and router
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);
        uint256 daiBalBefore = dai.balanceOf(alice);

        // Execute pass-through swap: USDC -> vault (swap) -> DAI
        uint256 daiReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool = vault
            IERC20(address(usdc)), // tokenIn
            daiUsdcVault, // tokenInVault = vault
            IERC20(address(dai)), // tokenOut
            daiUsdcVault, // tokenOutVault = vault
            SWAP_AMOUNT, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);
        uint256 daiBalAfter = dai.balanceOf(alice);

        // Verify USDC was spent
        assertEq(usdcBalBefore - usdcBalAfter, SWAP_AMOUNT, "USDC not spent correctly");

        // Verify DAI was received
        assertEq(daiBalAfter - daiBalBefore, daiReceived, "DAI not received correctly");
        assertGt(daiReceived, 0, "Should receive DAI");
    }

    function test_vaultPassThrough_exactIn_queryVsExec() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        // Query expected output
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

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Execute swap
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

        // Query and execution should match closely
        assertApproxEqAbs(actualUsdc, expectedUsdc, 1, "Query vs exec mismatch");
    }

    function test_vaultPassThrough_exactIn_slippage_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT);

        // Query expected output
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

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Try with unreasonably high minAmountOut
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

    function test_vaultPassThrough_exactIn_multipleSwaps() public {
        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT * 3);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // First swap
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

        // Second swap
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

        // Third swap
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

        // Verify total USDC received
        assertEq(usdcBalAfter - usdcBalBefore, usdc1 + usdc2 + usdc3, "Total USDC mismatch");

        // First swap should be slightly better due to less price impact
        assertGt(usdc1, usdc3, "First swap should get better rate than third");
    }

    function test_vaultPassThrough_noVaultSharesCreated() public {
        // Mint DAI to alice
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

        // No vault shares should be created for pass-through swaps
        assertEq(aliceSharesAfter, aliceSharesBefore, "Alice should not receive vault shares");
        assertEq(routerSharesAfter, routerSharesBefore, "Router should not retain vault shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactOut Pass-Through Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_vaultPassThrough_exactOut_daiToUsdc() public {
        // ExactOut pass-through: specify exact USDC to receive, spend variable DAI

        // Mint DAI to alice
        dai.mint(alice, SWAP_AMOUNT * 2);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactUsdcWanted = 50e18;
        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 usdcBalBefore = usdc.balanceOf(alice);

        // Execute swap: DAI -> exact USDC
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

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, daiSpent, "DAI spent mismatch");
        assertGt(daiSpent, 0, "Should spend DAI");

        // Verify at least the exact USDC was received
        assertGe(usdcBalAfter - usdcBalBefore, exactUsdcWanted, "Should receive at least exact USDC wanted");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_vaultPassThrough_routerNoRetention() public {
        // Mint DAI to alice
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

        // Router should not retain any tokens
        assertEq(routerDaiAfter, routerDaiBefore, "Router should not retain DAI");
        assertEq(routerUsdcAfter, routerUsdcBefore, "Router should not retain USDC");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_vaultPassThrough_exactIn(uint256 swapAmount) public {
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 500e18);

        // Mint DAI to alice
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

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, swapAmount, "DAI balance mismatch");

        // Verify USDC was received
        assertGt(usdcReceived, 0, "Should receive USDC");
        assertEq(usdcBalAfter - usdcBalBefore, usdcReceived, "USDC balance mismatch");
    }
}
