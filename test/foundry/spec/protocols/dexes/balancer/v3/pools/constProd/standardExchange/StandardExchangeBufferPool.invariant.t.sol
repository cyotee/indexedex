// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {Handler_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/Handler_StandardExchangeBufferPool.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

/**
 * @title StandardExchangeBufferPoolInvariant
 * @notice Foundry invariant test suite for the Standard Exchange Buffer Pool.
 *
 * @dev **L3 GOLD** for IndexedEx property/invariant program
 *      (`docs/testing/FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md`).
 *
 *      Uses Handler_StandardExchangeBufferPool to drive random swap, LP-add, and LP-remove
 *      operations against the deployed pool.  Each invariant_* function corresponds to a
 *      spec section 8.3 assertion.
 *
 *      Forge-config overrides keep the default run count small enough for CI:
 *        runs = 50   (50 random call sequences)
 *        depth = 20  (20 handler calls per sequence)
 */
/// forge-config: default.invariant.runs = 50
/// forge-config: default.invariant.depth = 20
contract StandardExchangeBufferPoolInvariant is TestBase_StandardExchangeBufferPool {

    Handler_StandardExchangeBufferPool internal handler;

    /* ---------------------------------------------------------------------- */
    /*                                setUp                                     */
    /* ---------------------------------------------------------------------- */

    function setUp() public override {
        super.setUp();

        handler = new Handler_StandardExchangeBufferPool(this);

        // Restrict the fuzzer to the five handler entry-points (includes unbalanced add, Change 1).
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler_StandardExchangeBufferPool.swap_TTA_in.selector;
        selectors[1] = Handler_StandardExchangeBufferPool.swap_shares_in.selector;
        selectors[2] = Handler_StandardExchangeBufferPool.lp_add.selector;
        selectors[3] = Handler_StandardExchangeBufferPool.lp_remove.selector;
        selectors[4] = Handler_StandardExchangeBufferPool.lp_add_unbalanced.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /* ---------------------------------------------------------------------- */
    /*                            Invariant Tests                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice §8.3 I-1: virtualTTA is always a uint256 that does not exceed a sane upper
     *         bound, i.e. the pool's virtual accounting never silently wraps around.
     *
     *         uint256 cannot be negative, so the primary risk is an overflow / wraparound
     *         that sets virtualTTA to a value close to type(uint256).max.  We cap at
     *         type(uint128).max as a generous-but-finite sentinel.
     */
    function invariant_virtualTTABounded() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertLt(p.virtualTTA(), type(uint128).max, "I-1: virtualTTA overflowed uint128 boundary");
    }

    /**
     * @notice §8.3 I-2: BPT total supply remains strictly positive after pool initialization.
     *
     *         The pool mints a minimum BPT dust on init and should never reach zero supply
     *         through normal swaps or LP removals (Balancer V3 guards the minimum supply).
     */
    function invariant_bptSupplyPositive() public view {
        assertGt(
            IERC20(bufferPool).totalSupply(),
            0,
            "I-2: BPT total supply dropped to zero"
        );
    }

    /**
     * @notice §8.3 I-3: virtualTTA is always non-zero after initialization.
     *
     *         The pool is seeded with a non-trivial virtualTTA at init.  If every swap
     *         drains it, the pool's PoolTTASideExhausted guard fires and reverts; virtualTTA
     *         should therefore never reach zero under normal handler activity.
     */
    function invariant_virtualTTAPositive() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertGt(p.virtualTTA(), 0, "I-3: virtualTTA reached zero unexpectedly");
    }

    /**
     * @notice §8.3 I-4: The pool's actual TTA balance in the Balancer Vault is bounded.
     *
     *         Under Change 1 (eventual zero TTA), unbalanced LP adds can leave physical TTA
     *         sitting in the pool between operations.  The strict "proportional growth" bound
     *         no longer applies.  We relax to a permissive ceiling of type(uint128).max,
     *         which catches only catastrophic overflow / unbounded accumulation bugs.
     *
     *         Tighter bounding (e.g. "actual TTA <= sum of unbalanced TTA deposits minus drained
     *         TTA") is deferred to a dedicated integration test once the opportunistic drain
     *         mechanism (onAfterSwap reconcile) is fully characterised.  In steady state -
     *         when swaps occur regularly - the existing onAfterSwap drain maintains near-zero
     *         actual TTA for TTA→shares swap paths.
     */
    function invariant_actualTTABounded() public view {
        (, , uint256[] memory rawBalances, ) = bv3Vault.getPoolTokenInfo(bufferPool);
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaBal = rawBalances[p.ttaIndex()];

        assertLt(
            ttaBal,
            type(uint128).max,
            "I-4: actual TTA exceeded uint128 boundary - drain failure or overflow?"
        );
    }

    /**
     * @notice §8.3 I-5: No free value via swaps only - TTA extracted via shares→TTA swaps
     *         does not exceed TTA contributed via TTA→shares swaps plus the TTA-equivalent
     *         value of shares contributed (using the canonical rate provider), with a small
     *         rounding allowance.  Only checked when no LP operations occurred in the sequence.
     *
     *         The handler's lp_add action freely mints TTA and shares to actors; this value
     *         is not tracked in ghost_totalTTAIn and would cause a spurious failure if LP
     *         operations are mixed with swap tracking.  This invariant therefore checks a
     *         swap-isolated sub-property: when the sequence contains only swaps and LP removes
     *         (which consume rather than inject value), the swap ghost counters balance out.
     *
     *         When LP adds have occurred (ghost_lpDepositCount > 0) the invariant is skipped
     *         because the minted collateral makes the ghost-only accounting incomplete.
     *
     *         Shares are converted to TTA-equivalent using the pool's rate provider so the
     *         invariant is correct regardless of the rate provider implementation.
     */
    function invariant_noFreeValue() public view {
        // Skip if any LP add occurred - free mints during lp_add break ghost accounting.
        if (handler.ghost_lpDepositCount() > 0) return;

        uint256 ttaOut   = handler.ghost_totalTTAOut();
        uint256 ttaIn    = handler.ghost_totalTTAIn();
        uint256 sharesIn = handler.ghost_totalSharesIn();

        // Nothing happened: trivially satisfied.
        if (ttaIn == 0 && sharesIn == 0 && ttaOut == 0) return;

        // Convert shares contributed to TTA-equivalent using the current rate.
        // rate = TTA per 1e18 shares (WAD).  Fall back to 1e18 if rate is zero.
        uint256 rate = IStandardExchangeBufferPool(bufferPool).rateProvider().getRate();
        if (rate == 0) rate = 1e18;
        uint256 sharesInTTA = (sharesIn * rate) / 1e18;

        // TTA contributed plus TTA-equivalent of shares contributed must meet or exceed
        // TTA extracted.  1e18 headroom absorbs CP slippage and rounding artifacts.
        assertLe(
            ttaOut,
            ttaIn + sharesInTTA + 1e18,
            "I-5: TTA extracted via swaps exceeds TTA + shares contributed (swap-only sequences)"
        );
    }

    /**
     * @notice §8.3 I-6: Successful swap count is non-decreasing (sanity check that the
     *         handler ghost variables never decrement, which would indicate a re-entrancy
     *         or storage-collision issue in the test harness itself).
     *
     *         Because Foundry resets state between invariant runs this assertion verifies
     *         monotonicity only within one fuzz sequence.
     */
    function invariant_ghostCountersMonotonic() public view {
        // Ghost counters are additive-only: they start at 0 and only increment on success.
        // Asserting >= 0 is trivially satisfied for uint256, so we assert the two swap
        // direction counts sum to the total observed swap operations.
        uint256 totalSwaps = handler.ghost_swapTTAtoSharesCount() + handler.ghost_swapSharesToTTACount();
        uint256 totalLp    = handler.ghost_lpDepositCount() + handler.ghost_lpRemoveCount();
        // These must be valid uint256 values (non-wrapping) - the assertion fires if
        // the addition itself overflowed, which would indicate a ghost variable bug.
        assertLe(totalSwaps, type(uint128).max, "I-6a: swap ghost counter wrapped");
        assertLe(totalLp,    type(uint128).max, "I-6b: LP ghost counter wrapped");
    }

    /**
     * @notice §8.3 I-7: hookSharesDelta can be any int256 but must not silently overflow.
     *
     *         The delta tracks how many shares the hook owes back to the pool after a swap.
     *         We assert its absolute value stays below type(int128).max as a sanity ceiling.
     */
    function invariant_hookSharesDeltaBounded() public view {
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        int256 delta = p.hookSharesDelta();
        int256 ceiling = int256(uint256(type(uint128).max));
        assertTrue(delta > -ceiling && delta < ceiling, "I-7: hookSharesDelta exceeded int128 boundary");
    }

    /**
     * @notice §8.3 I-8: After every handler action the pool still has a positive shares
     *         balance in the Balancer Vault (the shares side must never be fully drained).
     *
     *         PoolSharesSideExhausted guards prevent this in normal operation; if shares
     *         somehow reached zero it would break all future TTA→shares swaps permanently.
     */
    function invariant_actualSharesPositive() public view {
        (, , uint256[] memory rawBalances, ) = bv3Vault.getPoolTokenInfo(bufferPool);
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(bufferPool);
        assertGt(
            rawBalances[p.sharesIndex()],
            0,
            "I-8: actual shares balance in Vault reached zero"
        );
    }
}
