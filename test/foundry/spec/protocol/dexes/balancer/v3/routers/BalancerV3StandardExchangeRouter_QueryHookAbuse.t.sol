// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    BalancerV3VaultGuardModifiers
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultGuardModifiers.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title MaliciousStrategyVault
 * @notice Mock contract that simulates a malicious strategy vault trying to
 *         call querySwapSingleTokenExactInHook via a callback. This tests the
 *         reentrancy guard scenario from US-IDXEX-037.6.
 */
contract MaliciousStrategyVault {
    address public router;
    bytes public hookCalldata;
    bool public callAttempted;

    constructor(address _router, bytes memory _hookCalldata) {
        router = _router;
        hookCalldata = _hookCalldata;
    }

    /// @notice Called by tests to attempt the reentrancy attack.
    function attackViaCallback() external returns (bool success, bytes memory returnData) {
        callAttempted = true;
        (success, returnData) = router.call(hookCalldata);
    }
}

/**
 * @title BalancerV3StandardExchangeRouter_QueryHookAbuse_Test
 * @notice Regression tests for IDXEX-033: query hook access control.
 * @dev Covers US-IDXEX-037.6:
 *      - querySwapSingleTokenExactInHook direct call reverts
 *      - Reentrancy via malicious strategy vault is blocked
 *      - Query via vault.quote() still works
 *
 * Extends the existing ExactInQueryHookAbuse tests by explicitly testing
 * the attack vector where a malicious contract (simulating a strategy vault
 * callback) attempts to invoke the query hook.
 */
contract BalancerV3StandardExchangeRouter_QueryHookAbuse_Test is TestBase_BalancerV3StandardExchangeRouter {
    /* ---------------------------------------------------------------------- */
    /*       Test A: Direct external call blocked (EOA)                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calling querySwapSingleTokenExactInHook directly from an EOA
     *         MUST revert with NotBalancerV3Vault.
     */
    function test_queryHookAbuse_directCallFromEOA_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory params =
            BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                sender: alice,
                kind: SwapKind.EXACT_IN,
                pool: daiUsdcPool,
                tokenIn: token0,
                tokenInVault: _noVault(),
                tokenOut: token1,
                tokenOutVault: _noVault(),
                amountGiven: TEST_AMOUNT,
                limit: 0,
                deadline: type(uint256).max,
                wethIsEth: false,
                userData: ""
            });

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BalancerV3VaultGuardModifiers.NotBalancerV3Vault.selector, alice));
        seRouter.querySwapSingleTokenExactInHook(params);
    }

    /**
     * @notice Calling the exact-in query hook directly from a contract MUST also revert.
     */
    function test_queryHookAbuse_directCallFromContract_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory params =
            BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                sender: address(this),
                kind: SwapKind.EXACT_IN,
                pool: daiUsdcPool,
                tokenIn: token0,
                tokenInVault: _noVault(),
                tokenOut: token1,
                tokenOutVault: _noVault(),
                amountGiven: TEST_AMOUNT,
                limit: 0,
                deadline: type(uint256).max,
                wethIsEth: false,
                userData: ""
            });

        vm.expectRevert(
            abi.encodeWithSelector(BalancerV3VaultGuardModifiers.NotBalancerV3Vault.selector, address(this))
        );
        seRouter.querySwapSingleTokenExactInHook(params);
    }

    /**
     * @notice The hook selector must stay exposed on the diamond while remaining access-gated.
     */
    function test_queryHookAbuse_selectorExposedButGated() public {
        bytes4 hookSelector = IBalancerV3StandardExchangeRouterExactInSwapQuery.querySwapSingleTokenExactInHook.selector;
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        bytes memory callData = abi.encodeWithSelector(
            hookSelector,
            BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                sender: alice,
                kind: SwapKind.EXACT_IN,
                pool: daiUsdcPool,
                tokenIn: token0,
                tokenInVault: _noVault(),
                tokenOut: token1,
                tokenOutVault: _noVault(),
                amountGiven: TEST_AMOUNT,
                limit: 0,
                deadline: type(uint256).max,
                wethIsEth: false,
                userData: ""
            })
        );

        vm.prank(alice);
        (bool success, bytes memory returnData) = address(seRouter).call(callData);
        assertFalse(success, "Hook call should revert");
        assertEq(
            bytes4(returnData),
            BalancerV3VaultGuardModifiers.NotBalancerV3Vault.selector,
            "Revert must be NotBalancerV3Vault, not function-not-found"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*       Test B: Reentrancy via malicious contract blocked                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice A malicious contract simulating a strategy vault callback
     *         that attempts to call querySwapSingleTokenExactInHook MUST be
     *         blocked by onlyBalancerV3Vault. This is the key reentrancy
     *         attack vector that IDXEX-033 fixed.
     */
    function test_queryHookAbuse_maliciousContractCallback_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        // Build the hook calldata that the malicious contract will try to call
        bytes memory hookCalldata = abi.encodeCall(
            IBalancerV3StandardExchangeRouterExactInSwapQuery.querySwapSingleTokenExactInHook,
            (BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                    sender: alice,
                    kind: SwapKind.EXACT_IN,
                    pool: daiUsdcPool,
                    tokenIn: token0,
                    tokenInVault: _noVault(),
                    tokenOut: token1,
                    tokenOutVault: _noVault(),
                    amountGiven: TEST_AMOUNT,
                    limit: 0,
                    deadline: type(uint256).max,
                    wethIsEth: false,
                    userData: ""
                }))
        );

        // Deploy a malicious contract that will attempt the callback attack
        MaliciousStrategyVault attacker = new MaliciousStrategyVault(address(seRouter), hookCalldata);

        // The attack: contract calls the hook directly
        (bool success, bytes memory returnData) = attacker.attackViaCallback();

        // Must fail — not the Balancer Vault
        assertFalse(success, "Malicious callback should fail");
        assertTrue(attacker.callAttempted(), "Attack should have been attempted");

        // Verify it failed with NotBalancerV3Vault
        bytes4 errorSelector = bytes4(returnData);
        assertEq(
            errorSelector,
            BalancerV3VaultGuardModifiers.NotBalancerV3Vault.selector,
            "Should revert with NotBalancerV3Vault"
        );
    }

    /**
     * @notice Verify exact-out query hook is also protected from malicious callbacks.
     */
    function test_queryHookAbuse_exactOut_maliciousContractCallback_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        bytes memory hookCalldata = abi.encodeCall(
            IBalancerV3StandardExchangeRouterExactOutSwapQuery.querySwapSingleTokenExactOutHook,
            (BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                    sender: alice,
                    kind: SwapKind.EXACT_OUT,
                    pool: daiUsdcPool,
                    tokenIn: token0,
                    tokenInVault: _noVault(),
                    tokenOut: token1,
                    tokenOutVault: _noVault(),
                    amountGiven: TEST_AMOUNT / 2,
                    limit: type(uint256).max,
                    deadline: type(uint256).max,
                    wethIsEth: false,
                    userData: ""
                }))
        );

        MaliciousStrategyVault attacker = new MaliciousStrategyVault(address(seRouter), hookCalldata);
        (bool success,) = attacker.attackViaCallback();

        assertFalse(success, "ExactOut malicious callback should fail");
    }

    /**
     * @notice Calling the exact-out query hook directly from an EOA MUST also revert.
     */
    function test_queryHookAbuse_exactOut_directCallFromEOA_reverts() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory params =
            BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams({
                sender: alice,
                kind: SwapKind.EXACT_OUT,
                pool: daiUsdcPool,
                tokenIn: token0,
                tokenInVault: _noVault(),
                tokenOut: token1,
                tokenOutVault: _noVault(),
                amountGiven: TEST_AMOUNT / 2,
                limit: type(uint256).max,
                deadline: type(uint256).max,
                wethIsEth: false,
                userData: ""
            });

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BalancerV3VaultGuardModifiers.NotBalancerV3Vault.selector, alice));
        seRouter.querySwapSingleTokenExactOutHook(params);
    }

    /* ---------------------------------------------------------------------- */
    /*       Test C: Legitimate query via vault.quote() still works            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice The legitimate query path (querySwapSingleTokenExactIn → vault.quote →
     *         hook) must still function correctly after the access control fix.
     */
    function test_queryHookAbuse_legitimateQuery_stillWorks() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        uint256 amountOut = _queryExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), TEST_AMOUNT);

        assertTrue(amountOut > 0, "Legitimate query should return non-zero output");
    }

    /**
     * @notice The legitimate exact-out query also works.
     */
    function test_queryHookAbuse_legitimateExactOutQuery_stillWorks() public {
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);

        uint256 amountIn = _queryExactOut(daiUsdcPool, token0, _noVault(), token1, _noVault(), TEST_AMOUNT / 2);

        assertTrue(amountIn > 0, "Legitimate exact-out query should return non-zero input");
    }
}
