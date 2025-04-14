// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_DirectSwap_Test
 * @notice Tests for Direct Balancer Swap route (no vaults involved).
 * @dev Route conditions: tokenInVault = address(0), tokenOutVault = address(0), pool = Balancer pool
 *      Swaps tokens directly through a Balancer V3 pool.
 */
contract BalancerV3StandardExchangeRouter_DirectSwap_Test is TestBase_BalancerV3StandardExchangeRouter {
    bytes32 internal constant SWAP_HOOK_PARAMS_DEBUG_SIG =
        keccak256("SwapHookParamsDebug(address,uint8,address,address,address,address,address,uint256,uint256,bool)");
    bytes32 internal constant WETH_SENTINEL_DEBUG_SIG =
        keccak256("WethSentinelDebug(address,uint8,uint256,uint256,bool,bool)");

    function _findWethSentinelDebug(Vm.Log[] memory entries)
        internal
        pure
        returns (bool found, bool wrap, bool unwrap)
    {
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            if (entry.topics.length == 0 || entry.topics[0] != WETH_SENTINEL_DEBUG_SIG) continue;
            (uint8 kind, uint256 amountGiven, uint256 limit, bool isWrap, bool isUnwrap) =
                abi.decode(entry.data, (uint8, uint256, uint256, bool, bool));
            // suppress unused warnings
            kind;
            amountGiven;
            limit;
            found = true;
            wrap = isWrap;
            unwrap = isUnwrap;
            return (found, wrap, unwrap);
        }
        return (false, false, false);
    }

    /* ---------------------------------------------------------------------- */
    /*                       ExactIn: Execution vs Query                      */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_exactIn_tokenToToken() public {
        uint256 amountIn = TEST_AMOUNT;

        // Get pool tokens in sorted order
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to user
        _mintAndApprove(address(token0), alice, amountIn);

        // Query expected output
        uint256 expectedOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn);
        assertTrue(expectedOut > 0, "Query should return non-zero output");

        // Execute swap
        vm.startPrank(alice);
        uint256 actualOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Verify execution matches query
        assertEq(actualOut, expectedOut, "Execution should match query");
    }

    function test_directSwap_exactIn_execVsQuery_daiToUsdc() public {
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
        assertEq(actualOut, expectedOut, "Execution should match query");
        assertEq(tokenOut.balanceOf(alice) - balanceBefore, actualOut, "Balance should increase by actualOut");
    }

    function test_directSwap_exactIn_execVsQuery_usdcToDai() public {
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

        assertEq(actualOut, expectedOut, "Execution should match query");
    }

    /* ---------------------------------------------------------------------- */
    /*                     ExactIn: Balance Change Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_exactIn_balanceChanges() public {
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
        assertEq(token0.balanceOf(alice), aliceToken0Before - amountIn, "Token0 should decrease by amountIn");
        assertEq(token1.balanceOf(alice), aliceToken1Before + actualOut, "Token1 should increase by actualOut");
        assertEq(actualOut, expectedOut, "Output should match expected");
    }

    /* ---------------------------------------------------------------------- */
    /*                     ExactIn: Slippage Protection                       */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_exactIn_slippage_exactMinimum() public {
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

        assertEq(actualOut, expectedOut, "Should succeed with exact minimum");
    }

    function test_directSwap_exactIn_slippage_reverts() public {
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

    function test_directSwap_exactOut_tokenToToken() public {
        uint256 amountOut = TEST_AMOUNT / 2; // Request half to ensure we have enough reserve

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);
        assertTrue(expectedIn > 0, "Query should return non-zero input");

        // Mint enough tokens (add buffer for fees)
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        // Execute swap
        vm.startPrank(alice);
        uint256 actualIn =
            _swapExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut, type(uint256).max);
        vm.stopPrank();

        // Verify execution matches query
        assertEq(actualIn, expectedIn, "Execution should match query");
    }

    function test_directSwap_exactOut_execVsQuery() public {
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

        assertEq(actualIn, expectedIn, "Execution should match query");
        assertEq(token1.balanceOf(alice) - token1Before, amountOut, "Should receive exact amount out");
    }

    /* ---------------------------------------------------------------------- */
    /*                    ExactOut: Slippage Protection                       */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_exactOut_slippage_exactMaximum() public {
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

        assertEq(actualIn, expectedIn, "Should succeed with exact maximum");
    }

    function test_directSwap_exactOut_slippage_reverts() public {
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

    function testFuzz_directSwap_exactIn(uint256 amountIn) public {
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

        assertEq(actualOut, expectedOut, "Fuzz: execution should match query");
    }

    function testFuzz_directSwap_exactOut(uint256 amountOut) public {
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

        assertEq(actualIn, expectedIn, "Fuzz: execution should match query");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Router State Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_routerNoRetention() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, amountIn);

        uint256 routerToken0Before = token0.balanceOf(address(seRouter));
        uint256 routerToken1Before = token1.balanceOf(address(seRouter));

        vm.startPrank(alice);
        _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        // Router should not retain any tokens
        assertEq(token0.balanceOf(address(seRouter)), routerToken0Before, "Router should not retain token0");
        assertEq(token1.balanceOf(address(seRouter)), routerToken1Before, "Router should not retain token1");
    }

    /* ---------------------------------------------------------------------- */
    /*                         ETH Wrapping Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_exactIn_ethToDai() public {
        uint256 amountIn = TEST_AMOUNT;

        // Give alice ETH
        deal(alice, amountIn);

        // Query expected output
        uint256 expectedOut =
            _queryExactIn(daiWethPool, IERC20(address(weth)), _noVault(), IERC20(address(dai)), _noVault(), amountIn);
        assertTrue(expectedOut > 0, "Query should return non-zero output");

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        // Execute swap with wethIsEth=true
        vm.startPrank(alice);
        uint256 actualOut = _swapExactInWithEth(
            daiWethPool,
            IERC20(address(weth)),
            _noVault(),
            IERC20(address(dai)),
            _noVault(),
            amountIn,
            0,
            true // wethIsEth
        );
        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        // Verify ETH was spent
        assertEq(ethBalBefore - ethBalAfter, amountIn, "ETH should be spent");
        // Verify DAI was received
        assertEq(daiBalAfter - daiBalBefore, actualOut, "DAI should be received");
        assertEq(actualOut, expectedOut, "Execution should match query");
    }

    function test_directSwap_exactIn_daiToEth() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint DAI to alice
        _mintAndApprove(address(dai), alice, amountIn);

        // Query expected output
        uint256 expectedOut =
            _queryExactIn(daiWethPool, IERC20(address(dai)), _noVault(), IERC20(address(weth)), _noVault(), amountIn);
        assertTrue(expectedOut > 0, "Query should return non-zero output");

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        // Execute swap with wethIsEth=true to receive ETH
        vm.startPrank(alice);
        uint256 actualOut = _swapExactInWithEth(
            daiWethPool,
            IERC20(address(dai)),
            _noVault(),
            IERC20(address(weth)),
            _noVault(),
            amountIn,
            0,
            true // wethIsEth - will unwrap WETH to ETH
        );
        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        // Verify DAI was spent
        assertEq(daiBalBefore - daiBalAfter, amountIn, "DAI should be spent");
        // Verify ETH was received
        assertEq(ethBalAfter - ethBalBefore, actualOut, "ETH should be received");
        assertEq(actualOut, expectedOut, "Execution should match query");
    }

    function test_directSwap_exactIn_wrapEthToWeth_sentinel_execVsQuery() public {
        uint256 amountIn = TEST_AMOUNT;

        // Give alice ETH (used as input when wethIsEth=true and tokenIn==WETH).
        deal(alice, amountIn);

        uint256 ethBalBefore = alice.balance;
        uint256 wethBalBefore = weth.balanceOf(alice);

        // Query: sentinel wrapping is quoted 1:1.
        uint256 expectedOut = _queryExactIn(
            address(weth), IERC20(address(weth)), _noVault(), IERC20(address(weth)), _noVault(), amountIn
        );
        assertEq(expectedOut, amountIn, "Wrap quote should be 1:1");

        // Execute: pool == WETH triggers the router's wrap/unwrap special-case.
        vm.startPrank(alice);
        uint256 actualOut = _swapExactInWithEth(
            address(weth), IERC20(address(weth)), _noVault(), IERC20(address(weth)), _noVault(), amountIn, 0, true
        );
        vm.stopPrank();

        uint256 ethBalAfter = alice.balance;
        uint256 wethBalAfter = weth.balanceOf(alice);

        assertEq(actualOut, amountIn, "Wrap execution should be 1:1");
        assertEq(wethBalAfter - wethBalBefore, amountIn, "Alice should receive WETH");
        assertEq(ethBalBefore - ethBalAfter, amountIn, "Alice should spend ETH");
    }

    function test_directSwap_exactIn_unwrapWethToEth_sentinel_execVsQuery() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint WETH to alice and approve Permit2/Router
        _mintAndApprove(address(weth), alice, amountIn);

        uint256 ethBalBefore = alice.balance;
        uint256 wethBalBefore = weth.balanceOf(alice);

        // Query: sentinel unwrap is quoted 1:1.
        uint256 expectedOut = _queryExactIn(
            address(weth), IERC20(address(weth)), _noVault(), IERC20(address(weth)), _noVault(), amountIn
        );
        assertEq(expectedOut, amountIn, "Unwrap quote should be 1:1");

        // Execute: pool == WETH triggers the router's wrap/unwrap special-case.
        // For unwrap, we send no ETH and pay WETH in.
        vm.recordLogs();
        vm.startPrank(alice);
        uint256 actualOut = seRouter.swapSingleTokenExactIn(
            address(weth),
            IERC20(address(weth)),
            _noVault(),
            IERC20(address(weth)),
            _noVault(),
            amountIn,
            0,
            _deadline(),
            true,
            ""
        );
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (bool found, bool wrap, bool unwrap) = _findWethSentinelDebug(entries);
        assertTrue(found, "WethSentinelDebug not emitted");
        assertTrue(unwrap && !wrap, "Expected unwrap sentinel debug");

        uint256 ethBalAfter = alice.balance;
        uint256 wethBalAfter = weth.balanceOf(alice);

        assertEq(actualOut, amountIn, "Unwrap execution should be 1:1");
        assertEq(wethBalBefore - wethBalAfter, amountIn, "Alice should spend WETH");
        assertEq(ethBalAfter - ethBalBefore, amountIn, "Alice should receive ETH");
    }

    function test_directSwap_exactOut_ethToDai() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        // Query expected input
        uint256 expectedIn =
            _queryExactOut(daiWethPool, IERC20(address(weth)), _noVault(), IERC20(address(dai)), _noVault(), amountOut);
        assertTrue(expectedIn > 0, "Query should return non-zero input");

        // Give alice enough ETH (with buffer)
        uint256 maxEthIn = expectedIn * 2;
        deal(alice, maxEthIn);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        // Execute swap with wethIsEth=true
        vm.startPrank(alice);
        uint256 actualIn = _swapExactOutWithEth(
            daiWethPool,
            IERC20(address(weth)),
            _noVault(),
            IERC20(address(dai)),
            _noVault(),
            amountOut,
            maxEthIn,
            true // wethIsEth
        );
        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        // Verify exact DAI amount received
        assertEq(daiBalAfter - daiBalBefore, amountOut, "Should receive exact DAI amount");
        // Verify ETH spent matches expected
        assertEq(ethBalBefore - ethBalAfter, actualIn, "ETH spent should match");
        assertEq(actualIn, expectedIn, "Execution should match query");
    }

    function test_directSwap_exactOut_daiToEth() public {
        uint256 amountOut = TEST_AMOUNT / 2; // ETH to receive

        // Query expected input
        uint256 expectedIn =
            _queryExactOut(daiWethPool, IERC20(address(dai)), _noVault(), IERC20(address(weth)), _noVault(), amountOut);
        assertTrue(expectedIn > 0, "Query should return non-zero input");

        // Mint enough DAI (with buffer)
        uint256 maxDaiIn = expectedIn * 2;
        _mintAndApprove(address(dai), alice, maxDaiIn);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        // Execute swap with wethIsEth=true to receive ETH
        vm.startPrank(alice);
        uint256 actualIn = _swapExactOutWithEth(
            daiWethPool,
            IERC20(address(dai)),
            _noVault(),
            IERC20(address(weth)),
            _noVault(),
            amountOut,
            maxDaiIn,
            true // wethIsEth
        );
        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        // Verify DAI spent
        assertEq(daiBalBefore - daiBalAfter, actualIn, "DAI spent should match");
        // Verify exact ETH amount received
        assertEq(ethBalAfter - ethBalBefore, amountOut, "Should receive exact ETH amount");
        assertEq(actualIn, expectedIn, "Execution should match query");
    }

    function test_directSwap_exactOut_unwrapWethToEth_sentinel_execVsQuery() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        // Query: sentinel unwrap is quoted 1:1.
        uint256 expectedIn = _queryExactOut(
            address(weth), IERC20(address(weth)), _noVault(), IERC20(address(weth)), _noVault(), amountOut
        );
        assertEq(expectedIn, amountOut, "Unwrap quote should be 1:1");

        // Mint enough WETH to cover maxAmountIn and approve Permit2/Router.
        uint256 maxWethIn = expectedIn;
        _mintAndApprove(address(weth), alice, maxWethIn);

        uint256 ethBalBefore = alice.balance;
        uint256 wethBalBefore = weth.balanceOf(alice);

        // Execute: pool == WETH triggers wrap/unwrap special-case.
        // For unwrap exact-out, we send no ETH and pay WETH in.
        vm.recordLogs();
        vm.startPrank(alice);
        uint256 actualIn = seRouter.swapSingleTokenExactOut(
            address(weth),
            IERC20(address(weth)),
            _noVault(),
            IERC20(address(weth)),
            _noVault(),
            amountOut,
            maxWethIn,
            _deadline(),
            true,
            ""
        );
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        (bool found, bool wrap, bool unwrap) = _findWethSentinelDebug(entries);
        assertTrue(found, "WethSentinelDebug not emitted");
        assertTrue(unwrap && !wrap, "Expected unwrap sentinel debug");

        uint256 ethBalAfter = alice.balance;
        uint256 wethBalAfter = weth.balanceOf(alice);

        assertEq(actualIn, amountOut, "Unwrap execution should be 1:1");
        assertEq(wethBalBefore - wethBalAfter, actualIn, "Alice should spend WETH");
        assertEq(ethBalAfter - ethBalBefore, amountOut, "Alice should receive exact ETH amount");
    }

    function test_directSwap_eth_excessReturned() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        // Query expected input
        uint256 expectedIn =
            _queryExactOut(daiWethPool, IERC20(address(weth)), _noVault(), IERC20(address(dai)), _noVault(), amountOut);

        // Give alice much more ETH than needed
        uint256 excessEth = expectedIn * 3;
        deal(alice, excessEth);

        uint256 ethBalBefore = alice.balance;

        vm.startPrank(alice);
        uint256 actualIn = _swapExactOutWithEth(
            daiWethPool,
            IERC20(address(weth)),
            _noVault(),
            IERC20(address(dai)),
            _noVault(),
            amountOut,
            excessEth, // send more than needed
            true
        );
        vm.stopPrank();

        uint256 ethBalAfter = alice.balance;

        // Should only spend what's needed, excess returned
        assertEq(ethBalBefore - ethBalAfter, actualIn, "Only needed ETH should be spent");
        assertEq(actualIn, expectedIn, "Should match expected input");
    }

    function test_directSwap_eth_routerNoRetention() public {
        uint256 amountIn = TEST_AMOUNT;

        // Give alice ETH
        deal(alice, amountIn);

        uint256 routerEthBefore = address(seRouter).balance;
        uint256 routerWethBefore = weth.balanceOf(address(seRouter));

        vm.startPrank(alice);
        _swapExactInWithEth(
            daiWethPool, IERC20(address(weth)), _noVault(), IERC20(address(dai)), _noVault(), amountIn, 0, true
        );
        vm.stopPrank();

        // Router should not retain any ETH or WETH
        assertEq(address(seRouter).balance, routerEthBefore, "Router should not retain ETH");
        assertEq(weth.balanceOf(address(seRouter)), routerWethBefore, "Router should not retain WETH");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Edge Case Tests                               */
    /* ---------------------------------------------------------------------- */

    function test_directSwap_zeroAmount_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        vm.startPrank(alice);

        // Try to swap zero amount
        vm.expectRevert();
        _swapExactIn(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            0, // zero amount
            0
        );

        vm.stopPrank();
    }

    function test_directSwap_sameToken_reverts() public {
        (IERC20 token0,) = _getPoolTokens(daiUsdcPool);

        _mintAndApprove(address(token0), alice, TEST_AMOUNT);

        vm.startPrank(alice);

        // Try to swap token for itself
        vm.expectRevert();
        _swapExactIn(
            daiUsdcPool,
            token0,
            _noVault(),
            token0, // same token
            _noVault(),
            TEST_AMOUNT,
            0
        );

        vm.stopPrank();
    }
}
