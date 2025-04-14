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
 * @title BalancerV3StandardExchangeRouter_VaultDeposit_Test
 * @notice Tests for the Strategy Vault Deposit route.
 * @dev Strategy Vault Deposit: User deposits underlying tokens to a vault via the router.
 *      Route: tokenIn -> vault.exchangeIn() -> vault shares (tokenOut)
 *      Conditions: pool == tokenInVault, tokenIn != tokenInVault, tokenOut == tokenInVault
 */
contract BalancerV3StandardExchangeRouter_VaultDeposit_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant DEPOSIT_AMOUNT = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                          ExactIn Deposit Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_vaultDeposit_exactIn_daiToShares() public {
        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        // Approve DAI for permit2 and router
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Execute deposit: DAI -> vault shares
        // pool = vault, tokenIn = DAI, tokenInVault = vault, tokenOut = vault, tokenOutVault = 0
        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool
            IERC20(address(dai)), // tokenIn
            daiUsdcVault, // tokenInVault
            IERC20(address(daiUsdcVault)), // tokenOut (vault shares)
            _noVault(), // tokenOutVault (none)
            DEPOSIT_AMOUNT, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false, // wethIsEth
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, DEPOSIT_AMOUNT, "DAI not spent correctly");

        // Verify shares were received
        assertEq(shareBalAfter - shareBalBefore, sharesReceived, "Shares not received correctly");
        assertGt(sharesReceived, 0, "Should receive shares");
    }

    function test_vaultDeposit_exactIn_usdcToShares() public {
        // Mint USDC to alice
        usdc.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        // Approve USDC for permit2 and router
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Execute deposit: USDC -> vault shares
        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool
            IERC20(address(usdc)), // tokenIn
            daiUsdcVault, // tokenInVault
            IERC20(address(daiUsdcVault)), // tokenOut (vault shares)
            _noVault(), // tokenOutVault (none)
            DEPOSIT_AMOUNT, // exactAmountIn
            1, // minAmountOut
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);
        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);

        // Verify USDC was spent
        assertEq(usdcBalBefore - usdcBalAfter, DEPOSIT_AMOUNT, "USDC not spent correctly");

        // Verify shares were received
        assertEq(shareBalAfter - shareBalBefore, sharesReceived, "Shares not received correctly");
        assertGt(sharesReceived, 0, "Should receive shares");
    }

    function test_vaultDeposit_exactIn_queryVsExec() public {
        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT);

        // Query expected output
        vm.prank(address(0), address(0));
        uint256 expectedShares = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault), // pool
            IERC20(address(dai)), // tokenIn
            daiUsdcVault, // tokenInVault
            IERC20(address(daiUsdcVault)), // tokenOut
            _noVault(), // tokenOutVault
            DEPOSIT_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Execute deposit
        uint256 actualShares = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        // Query and execution should match closely (within rounding)
        assertApproxEqAbs(actualShares, expectedShares, 1, "Query vs exec mismatch");
    }

    function test_vaultDeposit_exactIn_slippage_reverts() public {
        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT);

        // Query to get expected output
        vm.prank(address(0), address(0));
        uint256 expectedShares = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // Try to execute with unreasonably high minAmountOut
        uint256 unreasonableMin = expectedShares * 2;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            unreasonableMin,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    function test_vaultDeposit_exactIn_multipleDeposits() public {
        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT * 3);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        // First deposit
        uint256 shares1 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        // Second deposit
        uint256 shares2 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        // Third deposit
        uint256 shares3 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        // All deposits should yield similar shares (within slippage)
        uint256 totalShares = IERC20(address(daiUsdcVault)).balanceOf(alice);
        assertEq(totalShares, shares1 + shares2 + shares3, "Total shares mismatch");

        // Shares should be roughly equal for equal deposits (accounting for slippage)
        assertApproxEqRel(shares1, shares2, 0.1e18, "Deposit consistency issue");
    }

    /* ---------------------------------------------------------------------- */
    /*                          ExactOut Deposit Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_vaultDeposit_exactOut_notSupported() public {
        // ExactOut deposit (specifying exact shares to receive) is not supported
        // for the Aerodrome vault because it doesn't implement previewExchangeOut
        // for single-token deposits (ZapIn). The vault reverts with RouteNotSupported.

        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT * 2);

        vm.startPrank(alice);

        // Approve
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactSharesWanted = 1000e18;

        // Expect RouteNotSupported error from the vault's previewExchangeOut
        // The vault doesn't support calculating input for exact output on ZapIn deposits
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(dai), // tokenIn
                address(daiUsdcVault), // tokenOut (vault shares)
                IStandardExchangeOut.previewExchangeOut.selector // function selector
            )
        );
        seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault), // pool
            IERC20(address(dai)), // tokenIn
            daiUsdcVault, // tokenInVault
            IERC20(address(daiUsdcVault)), // tokenOut (vault shares)
            _noVault(), // tokenOutVault
            exactSharesWanted, // exactAmountOut
            DEPOSIT_AMOUNT * 2, // maxAmountIn
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_vaultDeposit_routerNoRetention() public {
        // Mint DAI to alice
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));
        uint256 routerSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        // Router should not retain any tokens
        assertEq(routerDaiAfter, routerDaiBefore, "Router should not retain DAI");
        assertEq(routerSharesAfter, routerSharesBefore, "Router should not retain shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_vaultDeposit_exactIn(uint256 depositAmount) public {
        // Bound deposit amount to reasonable range
        depositAmount = bound(depositAmount, 1e18, 1000e18);

        // Mint DAI to alice
        dai.mint(alice, depositAmount);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            depositAmount,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        // Verify shares were received
        assertGt(sharesReceived, 0, "Should receive shares");
        assertEq(IERC20(address(daiUsdcVault)).balanceOf(alice), sharesReceived, "Share balance mismatch");
    }
}
