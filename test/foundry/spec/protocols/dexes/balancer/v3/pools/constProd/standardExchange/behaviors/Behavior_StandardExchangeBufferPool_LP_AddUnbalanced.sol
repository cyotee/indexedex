// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_LP_AddUnbalanced
 * @notice Reusable behavior contract asserting spec post-state for an unbalanced add-liquidity
 *         operation (Change 1 of the refactor plan - eventual zero TTA).
 *
 * @dev After an addLiquidityUnbalanced call contributing `ttaIn` TTA and `sharesIn` shares:
 *
 *      (a) BPT total supply increased by some positive amount (bptOut > 0) when
 *          the shares contribution is non-zero.
 *      (b) virtualTTA increased by exactly `ttaIn` (amountsInScaled18[ttaIdx]).
 *          For STANDARD-type TTA tokens there is no rate, so scaled18 == raw for 18-decimal tokens.
 *      (c) hookSharesDelta is UNCHANGED.  The shares side contribution grows actualShares
 *          (credited by the Vault), which in turn grows derived_y = (actualShares - hookSharesDelta).
 *          No explicit delta adjustment is needed.
 *
 *      Math verification (paper trace for UNBALANCED add of (X_tta, Y_shares) into pre-state
 *      (virtualTTA = vt, actualShares = s, hookSharesDelta = h, rate = r)):
 *
 *        post-add:
 *          virtualTTA    = vt + X_tta                     ← virtualTTA grows by TTA contribution
 *          actualShares  = s  + Y_shares                  ← Vault credits the shares deposit
 *          hookSharesDelta = h                             ← unchanged
 *          derived_y     = (s + Y_shares - h) * r
 *                        = old_derived_y + Y_shares * r
 *                        = old_derived_y + amountsInScaled18[sharesIdx]   ← grows by shares contribution
 *
 *        CP product post-add:
 *          virtualTTA_post * derived_y_post
 *          = (vt + X_tta) * (old_derived_y + Y_shares * r)
 *          > vt * old_derived_y      [strictly greater - consistent with new liquidity deposited]
 *
 *      DESIGN CONSTRAINT: The pool's `computeInvariant` uses virtualTTA from storage, not from the
 *      Vault-supplied `balancesLiveScaled18[ttaIdx]`.  This means a pure TTA-only UNBALANCED add
 *      produces no invariant change visible to `computeAddLiquidityUnbalanced` (because the pool's
 *      CP math ignores the physical TTA balance for the BPT-minting computation).  The Balancer Vault
 *      would then compute bptAmountOut = 0 (or revert on underflow), rendering a TTA-only unbalanced
 *      add non-viable.  This behavior library therefore covers only the mixed-token and shares-only
 *      unbalanced add paths, which correctly increase derived_y (the shares side) and thus the invariant.
 *
 *      The actual TTA deposited physically sits in the pool between operations (eventual-zero-TTA
 *      semantics). It will be drained to the Standard Exchange Vault by the next TTA→shares swap
 *      reconcile or explicit sweep.
 *
 *      Integer-division rounding means virtualTTA may differ by at most 1 wei; a tolerance of
 *      1e9 is used for cross-path rounding in the Balancer V3 Vault mock.
 */
abstract contract Behavior_StandardExchangeBufferPool_LP_AddUnbalanced is Test {

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
     * @notice Execute an addLiquidityUnbalanced with shares only and assert all post-state invariants.
     *
     * @param sharesIn Exact shares amount to contribute (shares-only unbalanced add).
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - This function acquires shares for alice before the add.
     *   - alice's tokens have permit2 approvals for the Balancer V3 RouterMock (set in setUp).
     *
     * @dev Shares-only unbalanced adds increase derived_y and thus the pool invariant, so they
     *      produce a positive bptAmountOut. No TTA is contributed, so virtualTTA is unchanged.
     */
    function behavior_lpAdd_unbalanced_sharesOnly(uint256 sharesIn) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        tb.mintShares(tb.getAlice(), sharesIn);

        // ------------------------------------------------------------------
        // Pre-state snapshot
        // ------------------------------------------------------------------
        uint256 vtPre  = p.virtualTTA();
        int256  hdPre  = p.hookSharesDelta();
        uint256 tPre   = IERC20(tb.bufferPool()).totalSupply();

        // ------------------------------------------------------------------
        // Execute addLiquidityUnbalanced with shares only (ttaIn = 0).
        // ------------------------------------------------------------------
        uint256 bptOut = tb.addLiquidityUnbalanced(tb.getAlice(), 0, sharesIn);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------
        uint256 tPost = IERC20(tb.bufferPool()).totalSupply();

        // (a) Some BPT was minted.
        assertGt(bptOut, 0, "lpAdd_unbalanced_sharesOnly: no BPT minted");
        assertEq(tPost, tPre + bptOut, "lpAdd_unbalanced_sharesOnly: total supply mismatch");

        // (b) virtualTTA is unchanged (no TTA contributed).
        assertEq(
            p.virtualTTA(),
            vtPre,
            "lpAdd_unbalanced_sharesOnly: virtualTTA must not change when ttaIn = 0"
        );

        // (c) hookSharesDelta is unchanged.
        assertEq(
            p.hookSharesDelta(),
            hdPre,
            "lpAdd_unbalanced_sharesOnly: hookSharesDelta must not change"
        );
    }

    /**
     * @notice Execute an addLiquidityUnbalanced with both tokens in unequal amounts and assert
     *         all post-state invariants.
     *
     * @param ttaIn     TTA amount to contribute (must be > 0 for virtualTTA growth test).
     * @param sharesIn  Shares amount to contribute (must be > 0 to produce positive bptAmountOut).
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - This function mints TTA and shares to alice as needed before the add.
     *   - alice's tokens have permit2 approvals for the Balancer V3 RouterMock (set in setUp).
     *
     * @dev Mixed-token unbalanced adds: the shares contribution increases derived_y (the BPT-visible
     *      invariant), and the TTA contribution is credited to virtualTTA without affecting the
     *      invariant-based BPT calculation.
     */
    function behavior_lpAdd_unbalanced_bothTokensUnequal(uint256 ttaIn, uint256 sharesIn) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        tb.mintTTA(tb.getAlice(), ttaIn);
        tb.mintShares(tb.getAlice(), sharesIn);

        // ------------------------------------------------------------------
        // Pre-state snapshot
        // ------------------------------------------------------------------
        uint256 vtPre  = p.virtualTTA();
        int256  hdPre  = p.hookSharesDelta();
        uint256 tPre   = IERC20(tb.bufferPool()).totalSupply();

        // ------------------------------------------------------------------
        // Execute addLiquidityUnbalanced with both tokens.
        // ------------------------------------------------------------------
        uint256 bptOut = tb.addLiquidityUnbalanced(tb.getAlice(), ttaIn, sharesIn);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------
        uint256 tPost = IERC20(tb.bufferPool()).totalSupply();

        // (a) BPT minted (driven by shares contribution - see design constraint).
        assertGt(bptOut, 0, "lpAdd_unbalanced_both: no BPT minted");
        assertEq(tPost, tPre + bptOut, "lpAdd_unbalanced_both: total supply mismatch");

        // (b) virtualTTA grew by ttaIn (STANDARD token, scaled18 == raw for 18-decimal TTA).
        assertApproxEqAbs(
            p.virtualTTA(),
            vtPre + ttaIn,
            1e9,
            "lpAdd_unbalanced_both: virtualTTA must grow by ttaIn"
        );

        // (c) hookSharesDelta is unchanged.
        assertEq(
            p.hookSharesDelta(),
            hdPre,
            "lpAdd_unbalanced_both: hookSharesDelta must not change"
        );
    }
}
