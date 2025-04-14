// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BalancerV3Fork} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork.sol";

/**
 * @title BalancerV3Fork_DirectSwap_Test
 * @notice Fork tests for Balancer V3 direct swaps on Base mainnet.
 * @dev Mirrors tests from BalancerV3StandardExchangeRouter_DirectSwap.t.sol
 *      but runs against live Base mainnet Balancer V3 infrastructure.
 *
 *      Key validations:
 *      - Query matches execution on live Balancer V3 Vault
 *      - Balance changes are correct
 *      - Slippage protection works
 *      - No ABI/selector mismatches with mainnet contracts
 */
contract BalancerV3Fork_DirectSwap_Test is TestBase_BalancerV3Fork {
    /* ---------------------------------------------------------------------- */
    /*                       ExactIn: Execution vs Query                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_directSwap_exactIn_tokenToToken() public {
        uint256 amountIn = TEST_AMOUNT;

        // Get pool tokens in sorted order
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to user
        _mintAndApprove(address(token0), alice, amountIn);

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);
        assertTrue(expectedOut > 0, "Fork: Query should return non-zero output");

        // Execute swap
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Verify execution matches query
        assertEq(actualOut, expectedOut, "Fork: Execution should match query");
    }

    function test_fork_directSwap_exactIn_execVsQuery_daiToUsdc() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint DAI to alice
        dai.mint(alice, amountIn);

        // Approve via permit2
        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        // Get pool tokens to determine order
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        IERC20 tokenIn = address(token0) == address(dai) ? token0 : token1;
        IERC20 tokenOut = address(token0) == address(dai) ? token1 : token0;

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, tokenIn, _noVault(), tokenOut, _noVault(), amountIn);

        // Execute swap
        uint256 balanceBefore = tokenOut.balanceOf(alice);
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, tokenIn, _noVault(), tokenOut, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Verify
        assertEq(actualOut, expectedOut, "Fork: Execution should match query");
        assertEq(tokenOut.balanceOf(alice) - balanceBefore, actualOut, "Fork: Balance should increase by actualOut");
    }

    function test_fork_directSwap_exactIn_execVsQuery_usdcToDai() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint USDC to alice
        usdc.mint(alice, amountIn);

        // Approve via permit2
        vm.startPrank(alice);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);
        vm.stopPrank();

        // Get pool tokens to determine order
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        IERC20 tokenIn = address(token0) == address(usdc) ? token0 : token1;
        IERC20 tokenOut = address(token0) == address(usdc) ? token1 : token0;

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, tokenIn, _noVault(), tokenOut, _noVault(), amountIn);

        // Execute swap
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, tokenIn, _noVault(), tokenOut, _noVault(), amountIn, 0);
        vm.stopPrank();

        assertEq(actualOut, expectedOut, "Fork: Execution should match query");
    }

    /* ---------------------------------------------------------------------- */
    /*                     ExactIn: Balance Change Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_fork_directSwap_exactIn_balanceChanges() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);

        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Verify balance changes
        assertEq(token0.balanceOf(alice), aliceToken0Before - amountIn, "Fork: Token0 should decrease by amountIn");
        assertEq(token1.balanceOf(alice), aliceToken1Before + actualOut, "Fork: Token1 should increase by actualOut");
        assertEq(actualOut, expectedOut, "Fork: Output should match expected");
    }

    /* ---------------------------------------------------------------------- */
    /*                     ExactIn: Slippage Protection                       */
    /* ---------------------------------------------------------------------- */

    function test_fork_directSwap_exactIn_slippage_exactMinimum() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);

        // Execute with exact minimum - should succeed
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            amountIn,
            expectedOut // exact minimum
        );
        vm.stopPrank();

        assertEq(actualOut, expectedOut, "Fork: Should succeed with exact minimum");
    }

    function test_fork_directSwap_exactIn_slippage_reverts() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);

        // Execute with minAmountOut too high - should revert
        vm.startPrank(alice);
        vm.expectRevert();
        _swapExactIn(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            amountIn,
            expectedOut + 1 // too high
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactOut: Execution vs Query                     */
    /* ---------------------------------------------------------------------- */

    function test_fork_directSwap_exactOut_tokenToToken() public {
        uint256 amountOut = TEST_AMOUNT / 2; // Request half to ensure we have enough reserve

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);
        assertTrue(expectedIn > 0, "Fork: Query should return non-zero input");

        // Mint enough tokens (add buffer for fees)
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        // Execute swap
        vm.startPrank(alice);
        uint256 actualIn =
            _swapExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut, type(uint256).max);
        vm.stopPrank();

        // Verify execution matches query
        assertEq(actualIn, expectedIn, "Fork: Execution should match query");
    }

    function test_fork_directSwap_exactOut_execVsQuery() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);

        // Mint tokens
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        uint256 token1Before = token1.balanceOf(alice);

        // Execute swap
        vm.startPrank(alice);
        uint256 actualIn =
            _swapExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut, type(uint256).max);
        vm.stopPrank();

        assertEq(actualIn, expectedIn, "Fork: Execution should match query");
        assertEq(token1.balanceOf(alice) - token1Before, amountOut, "Fork: Should receive exact amount out");
    }

    /* ---------------------------------------------------------------------- */
    /*                    ExactOut: Slippage Protection                       */
    /* ---------------------------------------------------------------------- */

    function test_fork_directSwap_exactOut_slippage_exactMaximum() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);

        // Mint exact amount needed
        _mintAndApprove(address(token0), alice, expectedIn);

        // Execute with exact maximum - should succeed
        vm.startPrank(alice);
        uint256 actualIn = _swapExactOut(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            amountOut,
            expectedIn // exact maximum
        );
        vm.stopPrank();

        assertEq(actualIn, expectedIn, "Fork: Should succeed with exact maximum");
    }

    function test_fork_directSwap_exactOut_slippage_reverts() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);

        // Mint tokens
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        // Execute with maxAmountIn too low - should revert
        vm.startPrank(alice);
        vm.expectRevert();
        _swapExactOut(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            amountOut,
            expectedIn - 1 // too low
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                           Fuzz Tests                                   */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_directSwap_exactIn(uint256 amountIn) public {
        // Bound to reasonable range (1 token to 1% of pool reserves)
        amountIn = bound(amountIn, 1e18, POOL_INIT_AMOUNT / 100);

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        // Query
        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);

        // Execute
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        assertEq(actualOut, expectedOut, "Fork fuzz: execution should match query");
    }

    function testFuzz_fork_directSwap_exactOut(uint256 amountOut) public {
        // Bound to reasonable range (1 token to 1% of pool reserves)
        amountOut = bound(amountOut, 1e18, POOL_INIT_AMOUNT / 100);

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);

        // Mint enough tokens
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        // Execute
        vm.startPrank(alice);
        uint256 actualIn =
            _swapExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut, type(uint256).max);
        vm.stopPrank();

        assertEq(actualIn, expectedIn, "Fork fuzz: execution should match query");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Fork-Specific Integration Tests                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that router interacts correctly with mainnet vault.
     * @dev Validates no ABI mismatches or selector issues.
     */
    function test_fork_mainnetVaultIntegration() public {
        // This test validates that our router can correctly call mainnet vault
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        // Execute swap - this goes through mainnet Balancer V3 Vault
        vm.startPrank(alice);
        uint256 amountOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Verify successful execution with mainnet infrastructure
        assertGt(amountOut, 0, "Fork: Should receive tokens from mainnet vault swap");
        assertEq(token0.balanceOf(alice), 0, "Fork: All input tokens consumed");
    }

    /**
     * @notice Test router does not retain tokens.
     */
    function test_fork_routerNoRetention() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        uint256 routerToken0Before = token0.balanceOf(address(seRouter));
        uint256 routerToken1Before = token1.balanceOf(address(seRouter));

        vm.startPrank(alice);
        _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Router should not retain any tokens
        assertEq(token0.balanceOf(address(seRouter)), routerToken0Before, "Fork: Router should not retain token0");
        assertEq(token1.balanceOf(address(seRouter)), routerToken1Before, "Fork: Router should not retain token1");
    }
}
