// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_WethUnwrap_Test
 * @notice Tests for WETH wrapping and unwrapping in the Balancer V3 router.
 * @dev Tests the wethIsEth flag for:
 *      - Pure Balancer Swap route (tokenInVault=0, tokenOutVault=0)
 *      - Wrapping ETH to WETH (tokenIn = WETH, wethIsEth=true)
 *      - Unwrapping WETH to ETH (tokenOut = WETH, wethIsEth=true)
 *
 * This test file catches the bug where params.limit was used instead of estimatedAmountIn
 * when tokenOut = WETH, causing TransferFailed because the vault tried to take more
 * tokens than were transferred.
 */
contract BalancerV3StandardExchangeRouter_WethUnwrap_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant SWAP_AMOUNT = 1e18;

    /* ---------------------------------------------------------------------- */
    /*                    ExactOut WETH Unwrap Tests (Bug Fix)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Test pure Balancer swap with WETH unwrap (ExactOut)
    /// @dev This test catches the bug where params.limit was used instead of estimatedAmountIn
    ///      when tokenOut = WETH, causing TransferFailed.
    ///      Route: DAI -> Balancer pool -> WETH -> unwrap to ETH
    function test_pureSwap_exactOut_daiToEth() public {
        dai.mint(alice, SWAP_AMOUNT * 100);
        deal(alice, SWAP_AMOUNT * 100);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        uint256 daiSpent = seRouter.swapSingleTokenExactOut(
            daiWethPool,
            IERC20(address(dai)),
            IStandardExchangeProxy(address(0)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(0)),
            SWAP_AMOUNT,
            SWAP_AMOUNT * 100,
            _deadline(),
            true,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        assertEq(daiBalBefore - daiBalAfter, daiSpent, "DAI spent mismatch");
        assertGt(daiSpent, 0, "Should spend DAI");
        assertGe(ethBalAfter - ethBalBefore, SWAP_AMOUNT, "Should receive at least exact ETH wanted");
    }

    /* ---------------------------------------------------------------------- */
    /*                    ExactIn WETH Unwrap Tests                           */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                    Query vs Execution Parity Tests                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Test that query and execution match for WETH unwrap (ExactOut)
    function test_pureSwap_exactOut_queryVsExec_daiToEth() public {
        dai.mint(alice, SWAP_AMOUNT * 100);
        deal(alice, SWAP_AMOUNT * 100);

        vm.prank(address(0), address(0));
        uint256 expectedDaiIn = seRouter.querySwapSingleTokenExactOut(
            daiWethPool,
            IERC20(address(dai)),
            IStandardExchangeProxy(address(0)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(0)),
            SWAP_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 actualDaiIn = seRouter.swapSingleTokenExactOut(
            daiWethPool,
            IERC20(address(dai)),
            IStandardExchangeProxy(address(0)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(0)),
            SWAP_AMOUNT,
            SWAP_AMOUNT * 100,
            _deadline(),
            true,
            ""
        );

        vm.stopPrank();

        assertApproxEqAbs(actualDaiIn, expectedDaiIn, 1, "Query vs exec mismatch for WETH unwrap");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Slippage Protection Tests                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Test that slippage is enforced for WETH unwrap
    function test_pureSwap_exactOut_slippageReverts_daiToEth() public {
        dai.mint(alice, SWAP_AMOUNT * 100);
        deal(alice, SWAP_AMOUNT * 100);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        vm.expectRevert();
        seRouter.swapSingleTokenExactOut(
            daiWethPool,
            IERC20(address(dai)),
            IStandardExchangeProxy(address(0)),
            IERC20(address(weth)),
            IStandardExchangeProxy(address(0)),
            SWAP_AMOUNT,
            1,
            _deadline(),
            true,
            ""
        );

        vm.stopPrank();
    }
}
