// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_LP_RemoveProportional
 * @notice Reusable behavior contract asserting spec section 6.5 post-state for a proportional
 *         remove-liquidity operation.
 *
 * @dev After a removeLiquidityProportional call burning exactly `bptIn` BPT:
 *      (a) BPT total supply decreases by exactly bptIn.
 *      (b) virtualTTA scales by tPost / tPre  (i.e. vtPost = vtPre - vtPre*bptIn/tPre).
 *      (c) hookSharesDelta scales by tPost / tPre (signed proportional scaling).
 *      (d) LP receives back proportional amounts of both tokens (nonzero since both are seeded).
 *
 *      The hook path: onAfterRemoveLiquidity performs the proportional scaling.
 *      The hook clamps virtualTTA at zero to avoid underflow (but won't be reached in normal tests).
 *
 *      Integer-division rounding means the post-state value may differ by up to 1 wei from
 *      the idealized formula; a tolerance of 1e9 is used to absorb multi-hop rounding in the
 *      Balancer V3 Vault mock.
 */
abstract contract Behavior_StandardExchangeBufferPool_LP_RemoveProportional is Test {

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
     * @notice Execute a removeLiquidityProportional and assert all spec 6.5 invariants.
     *
     * @param bptIn Exact BPT amount to burn. alice must hold at least this much BPT.
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - alice must hold at least `bptIn` BPT.
     *   - alice's BPT has permit2 approvals for the Balancer V3 RouterMock (set in setUp).
     */
    function behavior_lpRemove_proportional(uint256 bptIn) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        require(
            IERC20(tb.bufferPool()).balanceOf(tb.getAlice()) >= bptIn,
            "behavior_lpRemove: alice needs more BPT"
        );

        // ------------------------------------------------------------------
        // Pre-state snapshot
        // ------------------------------------------------------------------
        uint256 vtPre = p.virtualTTA();
        int256  hdPre = p.hookSharesDelta();
        uint256 tPre  = IERC20(tb.bufferPool()).totalSupply();

        // ------------------------------------------------------------------
        // Execute removeLiquidityProportional
        // ------------------------------------------------------------------
        uint256[] memory amountsOut = tb.removeLiquidityProportional(tb.getAlice(), bptIn, 0, 0);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------
        uint256 tPost = IERC20(tb.bufferPool()).totalSupply();

        // (a) BPT burned exactly bptIn.
        assertEq(tPost, tPre - bptIn, "lpRemove: BPT burned");

        // (b) virtualTTA scaled down by tPost/tPre.
        _assertVirtualTTAScaledDown(p, vtPre, bptIn, tPre);

        // (c) hookSharesDelta scaled down by tPost/tPre (signed).
        _assertHookSharesDeltaScaledDown(p, hdPre, bptIn, tPre);

        // (d) LP received back both tokens (pool has both TTA and shares seeded at init).
        assertGt(amountsOut[p.ttaIndex()],    0, "lpRemove: LP received TTA");
        assertGt(amountsOut[p.sharesIndex()], 0, "lpRemove: LP received shares");
    }

    function _assertVirtualTTAScaledDown(
        IStandardExchangeBufferPool p,
        uint256 vtPre,
        uint256 bptIn,
        uint256 tPre
    ) internal view {
        uint256 vtSub    = (bptIn * vtPre) / tPre;
        uint256 expected = vtSub >= vtPre ? 0 : vtPre - vtSub;
        assertApproxEqAbs(p.virtualTTA(), expected, 1e9, "lpRemove: virtualTTA scales down");
    }

    function _assertHookSharesDeltaScaledDown(
        IStandardExchangeBufferPool p,
        int256 hdPre,
        uint256 bptIn,
        uint256 tPre
    ) internal view {
        int256 hSub    = (int256(bptIn) * hdPre) / int256(tPre);
        int256 expected = hdPre - hSub;
        assertApproxEqAbs(p.hookSharesDelta(), expected, 1e9, "lpRemove: hookSharesDelta scales down");
    }
}
