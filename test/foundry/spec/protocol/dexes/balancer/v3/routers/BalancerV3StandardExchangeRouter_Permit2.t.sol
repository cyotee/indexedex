// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_Permit2_Test
 * @notice Tests documenting the Permit2-only token pull requirement.
 * @dev Covers US-IDXEX-037.2:
 *      - ERC20 transferFrom is NOT used (Permit2 only)
 *      - Without Permit2 approval, token pull fails
 *      - With Permit2 approval, token pull succeeds
 *
 * The router uses Permit2.transferFrom() exclusively for pulling tokens from
 * the user. Standard ERC20.transferFrom() is never called on the input token
 * by the router. This means users must:
 *   1. Approve the token on Permit2 (ERC20.approve(permit2, amount))
 *   2. Approve the router on Permit2 (permit2.approve(token, router, amount, expiry))
 */
contract BalancerV3StandardExchangeRouter_Permit2_Test is TestBase_BalancerV3StandardExchangeRouter {
    /* ---------------------------------------------------------------------- */
    /*           Test: Swap succeeds with full Permit2 approval chain         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice With proper Permit2 approvals (ERC20 -> Permit2, Permit2 -> Router),
     *         the swap completes successfully.
     */
    function test_permit2_fullApprovalChain_swapSucceeds() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to bob (a fresh user)
        address bob = makeAddr("bob");
        if (address(token0) == address(dai)) {
            dai.mint(bob, amountIn);
        } else {
            usdc.mint(bob, amountIn);
        }

        vm.startPrank(bob);

        // Step 1: Approve Permit2 to spend token (ERC20 level)
        token0.approve(address(permit2), type(uint256).max);

        // Step 2: Approve router on Permit2
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);

        // Step 3: Swap should succeed
        uint256 amountOut = seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, _deadline(), false, ""
        );

        vm.stopPrank();

        assertGt(amountOut, 0, "Swap with Permit2 approval should succeed");
    }

    /* ---------------------------------------------------------------------- */
    /*          Test: Swap fails without Permit2 approval on router           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice If the user has approved Permit2 for the token (ERC20.approve)
     *         but has NOT approved the router ON Permit2 (permit2.approve),
     *         the swap must revert.
     */
    function test_permit2_noRouterApproval_swapReverts() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to carol (a fresh user with no pre-existing approvals)
        address carol = makeAddr("carol");
        if (address(token0) == address(dai)) {
            dai.mint(carol, amountIn);
        } else {
            usdc.mint(carol, amountIn);
        }

        vm.startPrank(carol);

        // Step 1: Approve Permit2 to spend token (ERC20 level)
        token0.approve(address(permit2), type(uint256).max);

        // Step 2: Do NOT approve router on Permit2
        // (intentionally skip permit2.approve)

        // Step 3: Swap should revert because Permit2 hasn't authorized the router
        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, _deadline(), false, ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*          Test: Swap fails without ERC20 approval on Permit2            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice If the user has approved the router on Permit2 but has NOT
     *         approved Permit2 at the ERC20 level, the swap must revert.
     */
    function test_permit2_noERC20Approval_swapReverts() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to dave (a fresh user with no pre-existing approvals)
        address dave = makeAddr("dave");
        if (address(token0) == address(dai)) {
            dai.mint(dave, amountIn);
        } else {
            usdc.mint(dave, amountIn);
        }

        vm.startPrank(dave);

        // Step 1: Do NOT approve Permit2 at ERC20 level
        // (intentionally skip token0.approve(address(permit2), ...))

        // Step 2: Approve router on Permit2 (this alone is insufficient)
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);

        // Step 3: Swap should revert because Permit2 can't pull from user
        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, _deadline(), false, ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*          Test: ERC20 approve on router is insufficient                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Even if the user directly approves the router via ERC20.approve,
     *         the swap must still fail unless Permit2 approvals are in place.
     *         The router exclusively uses Permit2.transferFrom, never
     *         ERC20.transferFrom for pulling user tokens.
     */
    function test_permit2_directERC20ApproveOnRouter_insufficient() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Mint tokens to eve (a fresh user)
        address eve = makeAddr("eve");
        if (address(token0) == address(dai)) {
            dai.mint(eve, amountIn);
        } else {
            usdc.mint(eve, amountIn);
        }

        vm.startPrank(eve);

        // Only do direct ERC20 approve on the router - NOT Permit2
        token0.approve(address(seRouter), type(uint256).max);

        // Swap should revert because router doesn't use ERC20.transferFrom
        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0, _deadline(), false, ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*          Test: Permit2 approval with exact-out swap                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Exact-out swaps also require Permit2 approval chain.
     *         The router uses Permit2.transferFrom for the computed input amount.
     */
    function test_permit2_exactOut_fullApproval_succeeds() public {
        uint256 amountOut = TEST_AMOUNT / 2;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Query expected input
        uint256 expectedIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut);

        // Mint tokens to frank (with buffer)
        address frank = makeAddr("frank");
        if (address(token0) == address(dai)) {
            dai.mint(frank, expectedIn * 2);
        } else {
            usdc.mint(frank, expectedIn * 2);
        }

        vm.startPrank(frank);

        // Full Permit2 approval chain
        token0.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 actualIn = seRouter.swapSingleTokenExactOut(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountOut, type(uint256).max, _deadline(), false, ""
        );

        vm.stopPrank();

        assertEq(actualIn, expectedIn, "Exact-out with Permit2 approval should match query");
    }
}
