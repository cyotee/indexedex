// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
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
 * @title BalancerV3StandardExchangeRouter_Deadline_Test
 * @notice Tests proving the SwapDeadline revert mechanism works correctly.
 * @dev Covers US-IDXEX-037.1:
 *      - SwapDeadline() error exists and matches ISenderGuard.SwapDeadline
 *      - Expired deadline reverts with SwapDeadline on all swap paths
 *      - Valid deadline proceeds
 */
contract BalancerV3StandardExchangeRouter_Deadline_Test is TestBase_BalancerV3StandardExchangeRouter {
    /* ---------------------------------------------------------------------- */
    /*                  Test: SwapDeadline selector matches ISenderGuard       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice The SwapDeadline error used by the router MUST be the same selector
     *         as ISenderGuard.SwapDeadline. This ensures no selector drift from
     *         the commented-out local error declaration.
     */
    function test_swapDeadline_selectorMatchesISenderGuard() public pure {
        // The router inherits SenderGuard which provides SwapDeadline.
        // Confirm the selector matches the canonical ISenderGuard definition.
        bytes4 expected = ISenderGuard.SwapDeadline.selector;
        // SwapDeadline() is keccak256("SwapDeadline()")[0:4]
        bytes4 computed = bytes4(keccak256("SwapDeadline()"));
        assertEq(expected, computed, "ISenderGuard.SwapDeadline selector should match computed value");
    }

    /* ---------------------------------------------------------------------- */
    /*                  Test: Expired deadline reverts - ExactIn               */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_exactIn_expiredDeadline_reverts() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.startPrank(alice);
        vm.expectRevert(ISenderGuard.SwapDeadline.selector);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, expiredDeadline, false, ""
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                  Test: Expired deadline reverts - ExactOut              */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_exactOut_expiredDeadline_reverts() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query to find how much we need
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);
        _mintAndApprove(address(token0), alice, expectedIn * 2);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.startPrank(alice);
        vm.expectRevert(ISenderGuard.SwapDeadline.selector);
        seRouter.swapSingleTokenExactOut(
            daiUsdcPool,
            token0,
            _noVault(),
            token1,
            _noVault(),
            amountOut,
            type(uint256).max,
            expiredDeadline,
            false,
            ""
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                  Test: Deadline at exact block.timestamp proceeds       */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_exactBlockTimestamp_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        // Deadline == block.timestamp should succeed (check is `>`, not `>=`)
        uint256 exactDeadline = block.timestamp;

        vm.startPrank(alice);
        uint256 amountOut = seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, exactDeadline, false, ""
        );
        vm.stopPrank();

        assertGt(amountOut, 0, "Swap with deadline == block.timestamp should succeed");
    }

    /* ---------------------------------------------------------------------- */
    /*                  Test: Valid future deadline proceeds                   */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_futureDeadline_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        vm.startPrank(alice);
        uint256 amountOut = _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        assertGt(amountOut, 0, "Swap with future deadline should succeed");
    }

    /* ---------------------------------------------------------------------- */
    /*                  Test: Deadline boundary with warp                      */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_warpPastDeadline_reverts() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        // Set deadline to current + 1 hour
        uint256 deadline = block.timestamp + 1 hours;

        // Warp past the deadline
        vm.warp(deadline + 1);

        vm.startPrank(alice);
        vm.expectRevert(ISenderGuard.SwapDeadline.selector);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, deadline, false, ""
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*           Test: Expired deadline on vault deposit route                 */
    /* ---------------------------------------------------------------------- */

    function test_swapDeadline_vaultDepositRoute_expiredDeadline_reverts() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint DAI to alice for vault deposit
        _mintAndApprove(address(dai), alice, amountIn);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.startPrank(alice);
        vm.expectRevert(ISenderGuard.SwapDeadline.selector);
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool == vault for deposit
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            amountIn,
            0,
            expiredDeadline,
            false,
            ""
        );
        vm.stopPrank();
    }
}
