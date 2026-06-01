// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Swap_SharesToTTA
 * @notice Reusable behavior contract asserting spec section 6.3 post-state for a shares→TTA
 *         EXACT_IN swap.
 *
 * @dev After a shares→TTA EXACT_IN swap of X_shares:
 *      (a) User's shares balance decreases by X_shares; user's TTA balance increases by Y_TTA.
 *      (b) BPT total supply is unchanged (no LP action).
 *      (c) Pool's per-pool actual TTA balance returns to its pre-swap value.
 *          The hook's onBeforeSwap pre-seats Y_TTA into the pool by redeeming S shares from
 *          the SE Vault, then the swap drains Y_TTA back out to the user.
 *          Net result: actual TTA balance is unchanged from pre-swap.
 *      (d) virtualTTA decreases by exactly Y_TTA (the TTA amount received by the user).
 *      (e) hookSharesDelta decreases by S (the shares the hook redeemed from the SE Vault).
 *          S is recovered from the net change in actual shares balance:
 *            shrBalPost - shrBalPre = X_shares (user's input) - S (hook drained)
 *            => S = X_shares - (shrBalPost - shrBalPre)
 *
 * Critical invariant (spec 6.3 step 5):
 *   With the hookSharesDelta offset, Y_TTA_final == Y_TTA exactly — the pool reads the same
 *   derived_y post-pre-seat as pre-pre-seat.  No residual-redeposit pass is needed.
 */
abstract contract Behavior_StandardExchangeBufferPool_Swap_SharesToTTA is Test {

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
     * @notice Execute a shares→TTA EXACT_IN swap and assert all spec 6.3 invariants.
     *
     * @param amountIn Exact shares amount to swap in (raw units, same decimals as the SE vault share token).
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - alice must hold at least `amountIn` shares.
     *   - alice's shares have permit2 approval for the Balancer V3 RouterMock (set in setUp).
     *   - The SE Vault must hold enough TTA reserves to fulfill the hook's pre-seat redemption.
     */
    function behavior_swap_sharesToTTA_endToEnd(uint256 amountIn) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        // Ensure alice holds enough shares.  After _initPool alice has given all her shares
        // to the pool, so we first do a TTA→shares swap to acquire shares for this test.
        if (tb.shares().balanceOf(tb.getAlice()) < amountIn) {
            // Estimate TTA needed: 2x the amountIn as a conservative upper bound so the
            // resulting shares are at least amountIn (the CP pool may give slightly fewer).
            uint256 ttaNeeded = amountIn * 2;
            tb.mintTTA(tb.getAlice(), ttaNeeded);
            tb.swapTTAforShares(tb.getAlice(), ttaNeeded);
        }

        // ------------------------------------------------------------------
        // Pre-state snapshot  (taken AFTER the share-acquisition swap so the
        // delta measurements only capture the test swap itself)
        // ------------------------------------------------------------------
        uint256 vtPre      = p.virtualTTA();
        int256  hdPre      = p.hookSharesDelta();
        uint256 ttaBalPre  = _sharesToTTAVaultRawBalance(tb, p.ttaIndex());
        uint256 shrBalPre  = _sharesToTTAVaultRawBalance(tb, p.sharesIndex());
        uint256 bptPre     = IERC20(tb.bufferPool()).totalSupply();
        uint256 userTtaPre = tb.tta().balanceOf(tb.getAlice());
        uint256 userShrPre = tb.shares().balanceOf(tb.getAlice());

        // Sanity: alice must have enough shares now
        require(userShrPre >= amountIn, "behavior_swap_sharesToTTA_endToEnd: alice has insufficient shares after setup swap");

        // ------------------------------------------------------------------
        // Execute the swap
        // ------------------------------------------------------------------
        uint256 amountOut = tb.swapSharesForTTA(tb.getAlice(), amountIn);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------

        // (a) User balances moved as expected.
        assertEq(
            tb.shares().balanceOf(tb.getAlice()),
            userShrPre - amountIn,
            "swap_sharesToTTA: user paid X shares"
        );
        assertEq(
            tb.tta().balanceOf(tb.getAlice()),
            userTtaPre + amountOut,
            "swap_sharesToTTA: user received Y TTA"
        );

        // (b) BPT total supply unchanged.
        assertEq(
            IERC20(tb.bufferPool()).totalSupply(),
            bptPre,
            "swap_sharesToTTA: BPT supply unchanged"
        );

        // (c) Actual TTA balance returns to pre-swap baseline.
        //     The hook pre-seats Y_TTA by redeeming S shares from the SE Vault, temporarily
        //     increasing the pool's TTA balance.  The swap then drains that TTA to the user,
        //     netting back to the pre-swap value.
        assertEq(
            _sharesToTTAVaultRawBalance(tb, p.ttaIndex()),
            ttaBalPre,
            "swap_sharesToTTA: actual TTA returns to baseline"
        );

        // (d) virtualTTA decreased by exactly Y_TTA (amountOut, 18-decimal TTA).
        assertEq(
            p.virtualTTA(),
            vtPre - amountOut,
            "swap_sharesToTTA: virtualTTA -= Y_TTA"
        );

        // (e) hookSharesDelta decreased by S (shares redeemed by the hook during pre-seat).
        //     Net actual shares balance change:
        //       shrBalPost = shrBalPre + amountIn (user deposited) - S (hook drained)
        //       => S = amountIn - (shrBalPost - shrBalPre)
        //     Using signed arithmetic to handle the edge case where S > amountIn
        //     (i.e., hook redeemed more shares than the user provided, which would make
        //      shrBalPost < shrBalPre).
        uint256 shrBalPost = _sharesToTTAVaultRawBalance(tb, p.sharesIndex());
        int256 shrNetDelta = int256(shrBalPost) - int256(shrBalPre); // positive if S < amountIn
        int256 S = int256(amountIn) - shrNetDelta;                  // S = amountIn - netDelta
        assertGe(S, 0, "swap_sharesToTTA: S must be non-negative");
        assertEq(
            p.hookSharesDelta(),
            hdPre - S,
            "swap_sharesToTTA: hookSharesDelta -= S"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                            Internal Helpers                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Queries the Balancer V3 Vault for the raw balance of the token at the given
     *      pool-token index.
     *      Return layout: (tokens[], tokenInfo[], balancesRaw[], lastBalancesLiveScaled18[])
     *      Named _sharesToTTAVaultRawBalance to avoid name-collision with helpers in other
     *      behavior files.
     */
    function _sharesToTTAVaultRawBalance(TestBase_StandardExchangeBufferPool tb, uint256 tokenIndex)
        internal
        view
        returns (uint256)
    {
        (,, uint256[] memory balancesRaw,) = tb.bv3Vault().getPoolTokenInfo(tb.bufferPool());
        return balancesRaw[tokenIndex];
    }
}
