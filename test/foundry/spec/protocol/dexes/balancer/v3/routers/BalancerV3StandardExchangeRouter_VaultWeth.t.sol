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
 * @title BalancerV3StandardExchangeRouter_VaultWeth_Test
 * @notice Basic WETH wrapping tests for vault routes.
 * @dev These tests verify basic WETH wrapping works via the pure swap route.
 *      Complex vault routes with WETH require specific token registrations not available in current infrastructure.
 */
contract BalancerV3StandardExchangeRouter_VaultWeth_Test is TestBase_BalancerV3StandardExchangeRouter {
    uint256 internal constant SWAP_AMOUNT = 1e18;

    /* ---------------------------------------------------------------------- */
    /*                    Basic WETH Wrap Test                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Test basic WETH wrap (ETH -> WETH)
    function test_basicWethWrap() public {
        deal(alice, SWAP_AMOUNT);

        vm.startPrank(alice);

        uint256 ethBalBefore = alice.balance;
        uint256 wethBalBefore = weth.balanceOf(alice);

        // WETH wrap via pure swap route (pool = WETH sentinel)
        seRouter.swapSingleTokenExactIn{value: SWAP_AMOUNT}(
            address(weth),                              // pool = WETH sentinel
            IERC20(address(weth)),                    // tokenIn = WETH
            IStandardExchangeProxy(address(0)),         // tokenInVault = 0
            IERC20(address(weth)),                    // tokenOut = WETH
            IStandardExchangeProxy(address(0)),         // tokenOutVault = 0
            SWAP_AMOUNT,                               // exactAmountIn
            1,                                         // minAmountOut
            _deadline(),
            true,                                      // wethIsEth = true (wrap)
            ""
        );

        vm.stopPrank();

        uint256 ethBalAfter = alice.balance;
        uint256 wethBalAfter = weth.balanceOf(alice);

        assertEq(ethBalBefore - ethBalAfter, SWAP_AMOUNT, "ETH should be spent");
        assertEq(wethBalAfter - wethBalBefore, SWAP_AMOUNT, "WETH should be received");
    }

    /// @notice Test basic WETH unwrap (WETH -> ETH)
    function test_basicWethUnwrap() public {
        // First wrap some WETH
        deal(alice, SWAP_AMOUNT);
        vm.startPrank(alice);
        weth.deposit{value: SWAP_AMOUNT}();
        vm.stopPrank();

        vm.startPrank(alice);

        uint256 wethBalBefore = weth.balanceOf(alice);
        uint256 ethBalBefore = alice.balance;

        weth.approve(address(seRouter), SWAP_AMOUNT);

        // WETH unwrap via pure swap route (pool = WETH sentinel)
        seRouter.swapSingleTokenExactIn(
            address(weth),                              // pool = WETH sentinel
            IERC20(address(weth)),                    // tokenIn = WETH
            IStandardExchangeProxy(address(0)),         // tokenInVault = 0
            IERC20(address(weth)),                    // tokenOut = WETH
            IStandardExchangeProxy(address(0)),         // tokenOutVault = 0
            SWAP_AMOUNT,                               // exactAmountIn
            1,                                         // minAmountOut
            _deadline(),
            true,                                      // wethIsEth = true (unwrap)
            ""
        );

        vm.stopPrank();

        uint256 wethBalAfter = weth.balanceOf(alice);
        uint256 ethBalAfter = alice.balance;

        assertEq(wethBalBefore - wethBalAfter, SWAP_AMOUNT, "WETH should be spent");
        assertEq(ethBalAfter - ethBalBefore, SWAP_AMOUNT, "ETH should be received");
    }
}
