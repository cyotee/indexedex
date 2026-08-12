// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_LP_AddProportional
 * @notice Reusable behavior contract asserting spec section 6.4 post-state for a proportional
 *         add-liquidity operation.
 *
 * @dev After an addLiquidityProportional call minting exactly `bptOut` BPT:
 *      (a) BPT total supply increases by exactly bptOut.
 *      (b) virtualTTA scales by tPost / tPre  (i.e. vtPost = vtPre * tPost / tPre).
 *      (c) hookSharesDelta scales by tPost / tPre (signed proportional scaling).
 *
 *      The Balancer V3 Vault requires proportional contributions of both TTA and shares because
 *      the pool has nonzero reserves of each after initialization. The LP must supply both tokens.
 *      onBeforeAddLiquidity is a no-op for PROPORTIONAL kind; onAfterAddLiquidity performs the
 *      proportional scaling of virtualTTA and hookSharesDelta.
 *
 *      Integer-division rounding means the post-state value may differ by up to 1 wei from
 *      the idealized formula; a tolerance of 1e9 is used to absorb multi-hop rounding in the
 *      Balancer V3 Vault mock.
 */
abstract contract Behavior_StandardExchangeBufferPool_LP_AddProportional is Test {

    /* ---------------------------------------------------------------------- */
    /*                         Abstract Hook                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Implementors return the live test fixture so behavior functions
    ///         can access all public state (bv3Vault, bufferPool, tta, shares, …).
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool);

    /* ---------------------------------------------------------------------- */
    /*                         Behavior Assertions                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Execute an addLiquidityProportional (LP supplies both TTA and shares proportionally)
     *         and assert all spec 6.4 invariants.
     *
     * @param bptOut Exact BPT amount to mint.
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - This function mints TTA and acquires SE vault shares for alice as needed before the add.
     *   - alice's tokens have permit2 approvals for the Balancer V3 RouterMock (set in setUp).
     */
    function behavior_lpAdd_proportional_sharesOnlyContribution(uint256 bptOut) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        // Ensure alice has enough TTA and shares for the proportional contribution.
        // Using 10x the pool seed size to comfortably cover any proportional amounts.
        tb.mintTTA(tb.getAlice(), type(uint128).max);
        tb.mintShares(tb.getAlice(), 100e18); // 100 DAI → sufficient shares for proportional add

        // ------------------------------------------------------------------
        // Pre-state snapshot
        // ------------------------------------------------------------------
        uint256 vtPre  = p.virtualTTA();
        int256  hdPre  = p.hookSharesDelta();
        uint256 tPre   = IERC20(tb.bufferPool()).totalSupply();

        // ------------------------------------------------------------------
        // Execute addLiquidityProportional with generous maxAmounts for both tokens.
        // ------------------------------------------------------------------
        tb.addLiquidityProportional(tb.getAlice(), bptOut, type(uint128).max, type(uint128).max);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------
        uint256 tPost = IERC20(tb.bufferPool()).totalSupply();

        // (a) BPT minted exactly bptOut.
        assertEq(tPost, tPre + bptOut, "lpAdd: BPT minted");

        // (b) virtualTTA scaled by tPost/tPre.
        //     vtPost = vtPre + (bptOut * vtPre) / tPre = vtPre * tPost / tPre
        uint256 expectedVt = vtPre + (bptOut * vtPre) / tPre;
        assertApproxEqAbs(
            p.virtualTTA(),
            expectedVt,
            1e9,
            "lpAdd: virtualTTA scales by tPost/tPre"
        );

        // (c) hookSharesDelta scaled by tPost/tPre (signed).
        //     hdPost = hdPre + (bptOut * hdPre) / tPre = hdPre * tPost / tPre
        int256 expectedHd = hdPre + (int256(bptOut) * hdPre) / int256(tPre);
        assertApproxEqAbs(
            p.hookSharesDelta(),
            expectedHd,
            1e9,
            "lpAdd: hookSharesDelta scales proportionally"
        );
    }
}
