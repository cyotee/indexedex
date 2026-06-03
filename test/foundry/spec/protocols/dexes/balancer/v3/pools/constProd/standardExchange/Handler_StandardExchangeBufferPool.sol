// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

/**
 * @title Handler_StandardExchangeBufferPool
 * @notice Foundry invariant handler for the Standard Exchange Buffer Pool.
 *
 * @dev The Foundry invariant fuzzer calls this contract's public functions with random inputs.
 *      Each action is wrapped in try/catch so that out-of-bounds fuzz inputs (which trigger pool
 *      reverts) are silently discarded; only successful operations increment ghost counters.
 *      The invariant test contract (Task 24) reads the ghost variables to correlate successful
 *      operations with the pool state it asserts on.
 *
 * Actor model:
 *   - Two actors (alice, bob) are picked via seed % 2.
 *   - Before each action the handler mints/tops-up the actor's token balance so the
 *     pool bounds — not insufficient balance — are the limiting factor for rejection.
 */
contract Handler_StandardExchangeBufferPool is Test {

    /* ---------------------------------------------------------------------- */
    /*                               References                                */
    /* ---------------------------------------------------------------------- */

    TestBase_StandardExchangeBufferPool public immutable BASE;

    /* ---------------------------------------------------------------------- */
    /*                           Ghost Accumulators                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Cumulative TTA sent into the pool via TTA→shares swaps.
    uint256 public ghost_totalTTAIn;
    /// @notice Cumulative shares received from TTA→shares swaps.
    uint256 public ghost_totalSharesOut;
    /// @notice Cumulative shares sent into the pool via shares→TTA swaps.
    uint256 public ghost_totalSharesIn;
    /// @notice Cumulative TTA received from shares→TTA swaps.
    uint256 public ghost_totalTTAOut;
    /// @notice Number of successful LP add operations (proportional).
    uint256 public ghost_lpDepositCount;
    /// @notice Number of successful LP add operations (unbalanced, Change 1).
    uint256 public ghost_lpUnbalancedDepositCount;
    /// @notice Number of successful LP remove operations.
    uint256 public ghost_lpRemoveCount;
    /// @notice Number of successful TTA→shares swaps.
    uint256 public ghost_swapTTAtoSharesCount;
    /// @notice Number of successful shares→TTA swaps.
    uint256 public ghost_swapSharesToTTACount;

    /* ---------------------------------------------------------------------- */
    /*                               Actors                                    */
    /* ---------------------------------------------------------------------- */

    address internal immutable _alice;
    address internal immutable _bob;

    /* ---------------------------------------------------------------------- */
    /*                             Constructor                                 */
    /* ---------------------------------------------------------------------- */

    constructor(TestBase_StandardExchangeBufferPool base_) {
        BASE = base_;
        _alice = base_.getAlice();
        _bob   = base_.getBob();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Internal Helpers                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Returns one of the two actors deterministically from an arbitrary seed.
    function _pickActor(uint256 seed) internal view returns (address) {
        return (seed % 2 == 0) ? _alice : _bob;
    }

    /* ---------------------------------------------------------------------- */
    /*                           User-Facing Actions                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Fuzz action: swap TTA (DAI) into the pool and receive shares.
     * @dev Mints enough TTA to the actor if needed so the pool bounds — not a zero
     *      balance — drive rejection.  Bounded to [1e15, 100e18] to stay within
     *      realistic pool liquidity.
     */
    function swap_TTA_in(uint256 amount, uint256 actorSeed) public {
        address actor = _pickActor(actorSeed);

        // Ensure the actor has a sufficient TTA balance.
        uint256 actorBal = BASE.tta().balanceOf(actor);
        uint256 cap = 100e18;
        if (actorBal < 1e15) {
            BASE.mintTTA(actor, cap);
            actorBal = BASE.tta().balanceOf(actor);
        }

        amount = bound(amount, 1e15, actorBal > cap ? cap : actorBal);

        try BASE.swapTTAforShares(actor, amount) returns (uint256 out) {
            ghost_totalTTAIn     += amount;
            ghost_totalSharesOut += out;
            ghost_swapTTAtoSharesCount++;
        } catch {
            // Pool bounds or fee constraints rejected the swap — not an invariant violation.
        }
    }

    /**
     * @notice Fuzz action: swap shares into the pool and receive TTA.
     * @dev Mints shares to the actor via the full Aerodrome→SE-vault path if needed.
     *      Bounded to [1e15, 100e18].
     */
    function swap_shares_in(uint256 amount, uint256 actorSeed) public {
        address actor = _pickActor(actorSeed);

        uint256 actorBal = BASE.shares().balanceOf(actor);
        uint256 cap = 100e18;
        if (actorBal < 1e15) {
            BASE.mintShares(actor, cap);
            actorBal = BASE.shares().balanceOf(actor);
        }

        amount = bound(amount, 1e15, actorBal > cap ? cap : actorBal);

        try BASE.swapSharesForTTA(actor, amount) returns (uint256 out) {
            ghost_totalSharesIn += amount;
            ghost_totalTTAOut   += out;
            ghost_swapSharesToTTACount++;
        } catch {
            // Ignore reversions from pool math / fee bounds.
        }
    }

    /**
     * @notice Fuzz action: add proportional liquidity to the pool.
     * @dev Ensures the actor has enough of both tokens before attempting the add.
     *      bptOut is bounded to at most half the current BPT supply to avoid
     *      exhausting the pool.
     */
    function lp_add(uint256 bptOut, uint256 actorSeed) public {
        address actor = _pickActor(actorSeed);
        address pool  = BASE.bufferPool();

        uint256 supply = IERC20(pool).totalSupply();
        if (supply == 0) return;

        bptOut = bound(bptOut, 1e12, supply / 2);

        // Top-up both token balances so the actor can contribute.
        BASE.mintTTA(actor, type(uint128).max);
        BASE.mintShares(actor, 100e18);

        try BASE.addLiquidityProportional(actor, bptOut, type(uint128).max, type(uint128).max) {
            ghost_lpDepositCount++;
        } catch {
            // Ignore: ratio bounds or hook constraints may reject.
        }
    }

    /**
     * @notice Fuzz action: add liquidity unbalanced — shares only (Change 1).
     * @dev Contributes only shares, exercising the new UNBALANCED code path in onAfterAddLiquidity.
     *      Shares-only unbalanced adds increase derived_y (the pool's BPT-visible invariant side),
     *      so they produce a positive bptAmountOut. TTA-only unbalanced adds cannot produce BPT
     *      because computeInvariant reads virtualTTA from storage (not from balancesLiveScaled18),
     *      so the invariant appears unchanged to the Vault's computeAddLiquidityUnbalanced.
     *      Bounded to [1e15, 20e18] to stay within realistic pool depth.
     */
    function lp_add_unbalanced(uint256 sharesAmount, uint256 actorSeed) public {
        address actor = _pickActor(actorSeed);

        // Ensure the actor has sufficient shares.
        uint256 cap = 20e18;
        sharesAmount = bound(sharesAmount, 1e15, cap);
        BASE.mintShares(actor, cap); // mint enough to guarantee sharesAmount is covered

        try BASE.addLiquidityUnbalanced(actor, 0, sharesAmount) returns (uint256) {
            ghost_lpUnbalancedDepositCount++;
            // Count as a deposit for the noFreeValue invariant skip logic.
            ghost_lpDepositCount++;
        } catch {
            // Pool math or invariant ratio bounds may reject — not an invariant violation.
        }
    }

    /**
     * @notice Fuzz action: remove proportional liquidity from the pool.
     * @dev Only proceeds if the actor holds BPT.  bptIn is bounded to the actor's
     *      entire BPT balance so the pool is never left with a negative supply.
     */
    function lp_remove(uint256 bptIn, uint256 actorSeed) public {
        address actor = _pickActor(actorSeed);
        address pool  = BASE.bufferPool();

        uint256 actorBpt = IERC20(pool).balanceOf(actor);
        if (actorBpt == 0) return;

        bptIn = bound(bptIn, 1, actorBpt);

        try BASE.removeLiquidityProportional(actor, bptIn, 0, 0) {
            ghost_lpRemoveCount++;
        } catch {
            // Ignore: minimum-supply or dust-amount guards may reject.
        }
    }
}
