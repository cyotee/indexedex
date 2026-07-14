// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Swap_TTAtoShares
 * @notice Reusable behavior contract asserting spec section 6.2 post-state for a TTA→shares
 *         EXACT_IN swap.
 *
 * @dev After a TTA→shares EXACT_IN swap of X TTA, post Task 5's best-effort reconcile
 *      (`_reconcileTTAToShares` deposits the FULL X into the SE Vault via `exchangeIn` — there
 *      is no exact-mint target and therefore no `ttaSurplus` leg):
 *      (a) User's TTA balance decreases by X; user's shares balance increases by Y_shares.
 *      (b) BPT total supply is unchanged (no LP action).
 *      (c) Pool's per-pool actual TTA balance is UNCHANGED (equals ttaBalPre exactly).
 *          The hook drains all X TTA from the Vault, deposits all of it into the SE Vault via
 *          `exchangeIn` (no partial consumption / no surplus leg), and CUSTOM-removes exactly
 *          X TTA from the pool's balance — net zero change, for any amount the SE Vault mints.
 *      (d) virtualTTA increases by exactly X (assumes 18-decimal TTA).
 *      (e) hookSharesDelta increases by Y' = `_bv3SharesDonationRaw(minted)`, the round-trip
 *          -capped raw shares actually donated into the pool (`minted` is whatever `exchangeIn`
 *          affords for X at NAV — no longer tied to the swap's quoted `Y_shares`). Y' is
 *          derived from the change in the pool's actual shares balance plus the shares
 *          delivered to the user: Y' = (shrBalPost - shrBalPre) + Y_shares.
 *      (f) Pool's actual shares balance changes by Y' - Y_shares (may be negative now: since
 *          `minted` is best-effort rather than pinned to `Y_shares`, Y' can be smaller than
 *          Y_shares when the SE Vault's post-shift price yields fewer shares per X than the
 *          buffer pool's CP quote delivered to the user).
 */
abstract contract Behavior_StandardExchangeBufferPool_Swap_TTAtoShares is Test {

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
     * @notice Execute a TTA→shares EXACT_IN swap and assert all spec 6.2 invariants.
     *
     * @param amountIn Exact TTA amount to swap in (raw 18-decimal units).
     *
     * Pre-conditions:
     *   - The pool must be initialized (setUp() complete).
     *   - alice must hold at least `amountIn` TTA (minted below if not).
     *   - alice's TTA has permit2 approval for the Balancer V3 RouterMock (set in setUp).
     */
    function behavior_swap_TTAtoShares_endToEnd(uint256 amountIn) public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        // Ensure alice holds enough TTA for the swap.
        if (tb.tta().balanceOf(tb.getAlice()) < amountIn) {
            tb.mintTTA(tb.getAlice(), amountIn);
        }

        // ------------------------------------------------------------------
        // Pre-state snapshot
        // ------------------------------------------------------------------
        uint256 vtPre     = p.virtualTTA();
        int256  hdPre     = p.hookSharesDelta();
        uint256 ttaBalPre = _swapVaultRawBalance(tb, p.ttaIndex());
        uint256 shrBalPre = _swapVaultRawBalance(tb, p.sharesIndex());
        uint256 bptPre    = IERC20(tb.bufferPool()).totalSupply();
        uint256 userTtaPre = tb.tta().balanceOf(tb.getAlice());
        uint256 userShrPre = tb.shares().balanceOf(tb.getAlice());

        // ------------------------------------------------------------------
        // Execute the swap
        // ------------------------------------------------------------------
        uint256 amountOut = tb.swapTTAforShares(tb.getAlice(), amountIn);

        // ------------------------------------------------------------------
        // Post-state assertions
        // ------------------------------------------------------------------

        // (a) User balances moved as expected.
        assertEq(
            tb.tta().balanceOf(tb.getAlice()),
            userTtaPre - amountIn,
            "swap_TTAtoShares: user paid X TTA"
        );
        assertEq(
            tb.shares().balanceOf(tb.getAlice()),
            userShrPre + amountOut,
            "swap_TTAtoShares: user received Y_shares"
        );

        // (b) BPT total supply unchanged.
        assertEq(
            IERC20(tb.bufferPool()).totalSupply(),
            bptPre,
            "swap_TTAtoShares: BPT supply unchanged"
        );

        // (c) Actual TTA balance is UNCHANGED. The best-effort reconcile drains ALL of
        //     amountIn from the Vault, deposits all of it via `exchangeIn` (no partial
        //     consumption), and CUSTOM-removes exactly amountIn from the pool's balance --
        //     net zero, regardless of how many shares the SE Vault mints for it.
        uint256 ttaBalPost = _swapVaultRawBalance(tb, p.ttaIndex());
        assertEq(
            ttaBalPost,
            ttaBalPre,
            "swap_TTAtoShares: actual TTA balance unchanged (no ttaSurplus leg)"
        );

        // (d) virtualTTA increased by exactly X (18-decimal TTA assumed).
        assertEq(
            p.virtualTTA(),
            vtPre + amountIn,
            "swap_TTAtoShares: virtualTTA += X"
        );

        // (e) hookSharesDelta increased by Y' = _bv3SharesDonationRaw(minted), the round-trip
        //     -capped raw shares actually donated into the pool by the reconcile. `minted` is
        //     whatever `exchangeIn` affords for amountIn at NAV -- no longer pinned to the
        //     swap's quoted amountOut. Pool's actual shares balance after the swap:
        //       shrBalPost = shrBalPre - amountOut + Y'
        //     => Y' = shrBalPost - shrBalPre + amountOut
        //     Computed with signed arithmetic: Y' can now be smaller than amountOut (see (f)),
        //     so the intermediate difference is not guaranteed non-negative.
        uint256 shrBalPost = _swapVaultRawBalance(tb, p.sharesIndex());
        int256 yPrime = int256(shrBalPost) - int256(shrBalPre) + int256(amountOut);
        assertEq(
            p.hookSharesDelta(),
            hdPre + yPrime,
            "swap_TTAtoShares: hookSharesDelta += Y'"
        );

        // (f) Pool's actual shares balance changed by Y' - Y_shares. This may now be negative:
        //     since `minted` is best-effort rather than pinned to Y_shares, Y' can be smaller
        //     than amountOut when the SE Vault's post-shift price yields fewer shares per X
        //     than the buffer pool's CP quote delivered to the user.
        assertEq(
            int256(shrBalPost),
            int256(shrBalPre) + yPrime - int256(amountOut),
            "swap_TTAtoShares: pool shares balance delta = Y' - Y_shares"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                            Internal Helpers                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Queries the Balancer V3 Vault for the raw balance of the token at the given
     *      pool-token index.
     *      Return layout: (tokens[], tokenInfo[], balancesRaw[], lastBalancesLiveScaled18[])
     *      Named _swapVaultRawBalance to avoid the name-collision with the same helper in
     *      Behavior_StandardExchangeBufferPool_Initialization._vaultRawBalance.
     */
    function _swapVaultRawBalance(TestBase_StandardExchangeBufferPool tb, uint256 tokenIndex)
        internal
        view
        returns (uint256)
    {
        (,, uint256[] memory balancesRaw,) = tb.bv3Vault().getPoolTokenInfo(tb.bufferPool());
        return balancesRaw[tokenIndex];
    }
}
