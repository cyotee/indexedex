// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Errors
 * @notice Reusable behavior contract exercising the integration-visible typed error paths of the
 *         Standard Exchange Buffer Pool that are not covered by the unit-test layer.
 *
 * @dev Covers the IPoolLiquidity access-control guard (NotHookCaller) exposed by
 *      onAddLiquidityCustom and onRemoveLiquidityCustom.
 *
 *      The LiquidityTarget checks:
 *          if (router != address(this)) revert NotHookCaller(router);
 *      where `router` is the first ABI parameter and `address(this)` resolves to the pool Diamond's
 *      own address at execution time.  Any caller that supplies a `router` argument other than the
 *      pool address will therefore receive a NotHookCaller revert — regardless of msg.sender.
 *
 *      The two tests below exercise both entry-points with an attacker-controlled router argument
 *      and assert that the typed error is emitted with the correct argument value.
 */
abstract contract Behavior_StandardExchangeBufferPool_Errors is Test {

    /* ---------------------------------------------------------------------- */
    /*                         Abstract Hook                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Implementors return the live test fixture so behavior functions
    ///         can access all public state (bv3Vault, bufferPool, tta, shares, …).
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool);

    /* ---------------------------------------------------------------------- */
    /*                         Behavior Assertions                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calling onAddLiquidityCustom with a router argument that is NOT the pool address
     *         must revert with NotHookCaller(router).
     *
     * @dev Any external address can call the Diamond facet function directly; the guard is on the
     *      first ABI-encoded argument (`router`), not on msg.sender.  We pass the canonical
     *      attacker address (0xDEADBEEF) as `router` to trigger the check.
     */
    function behavior_errors_customAddFromNonHookReverts() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        address pool = tb.bufferPool();
        address attackerRouter = address(0xDEADBEEF);

        // Expect the typed revert with the supplied router address as the argument.
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, attackerRouter)
        );

        // Call onAddLiquidityCustom directly on the pool diamond, passing an attacker-controlled
        // router value.  msg.sender is irrelevant; only the `router` argument is checked.
        IPoolLiquidity(pool).onAddLiquidityCustom(
            attackerRouter,
            new uint256[](2),
            uint256(0),
            new uint256[](2),
            ""
        );
    }

    /**
     * @notice Calling onRemoveLiquidityCustom with a router argument that is NOT the pool address
     *         must revert with NotHookCaller(router).
     */
    function behavior_errors_customRemoveFromNonHookReverts() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        address pool = tb.bufferPool();
        address attackerRouter = address(0xDEADBEEF);

        // Expect the typed revert with the supplied router address as the argument.
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, attackerRouter)
        );

        // Call onRemoveLiquidityCustom directly on the pool diamond.
        IPoolLiquidity(pool).onRemoveLiquidityCustom(
            attackerRouter,
            uint256(0),
            new uint256[](2),
            new uint256[](2),
            ""
        );
    }
}
