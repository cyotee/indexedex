// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

/// @title DETFNaturalExpansionLib
/// @notice Shared pure helpers for Phase 2 natural supply expansion (Stage 05).
/// @dev Product law: `DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` §4 (premium-closure).
///      Stage plan: `05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`.
///
/// # When accrual is non-zero
///
/// All must hold (caller supplies flags from family state + threshold policy):
/// 1. Instance **live**
/// 2. `thresholdMode == Policy` (`isPolicyMode == true`; Open ⇒ always zero mint)
/// 3. Synthetic mint-allowed (`synthetic > mintThreshold` under Policy)
///
/// Additional pure gates: `dt > 0`, `totalDetfSupply > 0`, premium above peg, mint above dust.
///
/// # Premium-closure mint formula (canonical — families must not fork)
///
/// ```text
/// peg = 1e18
/// premium = syntheticPrice > peg ? syntheticPrice - peg : 0
/// dt = min(nowTimestamp - lastExpansionTimestamp, catchUpMaxSeconds)
/// // closed premium fraction over dt (1e18-scaled rate = fraction of premium / second):
/// // closed = premium * closureRatePerSecond * dt / 1e18
/// // dilution lever: mint free DETF so supply growth ≈ closed / syntheticPrice
/// mint = totalDetfSupply * closed / syntheticPrice
///      = totalDetfSupply * premium * closureRatePerSecond * dt / (1e18 * syntheticPrice)
/// maxMint = catchUpCapBps == 0
///           ? type(uint256).max
///           : totalDetfSupply * catchUpCapBps / 10_000
/// mint = min(mint, maxMint)
/// if mint <= DEFAULT_EXPANSION_DUST: mint = 0
/// ```
///
/// Implemented with nested `Math.mulDiv` (no overflow on intermediate products).
///
/// # Deploy-time resolve
///
/// `resolveExpansionParams` maps zero args → plan defaults (same spirit as
/// `DETFThresholdPolicy.resolveThresholds`). Arg `0` for rate does **not** mean off —
/// it means default rate. Open mode and gates disable expansion; explicit rate of 1 wei
/// still expands slowly.
///
/// # Mint-on-update contract (families implement in Stages 06–09)
///
/// ```text
/// _updateExpansionAndRewards():
///   1. mintAmount, newTs = DETFNaturalExpansionLib.computeExpansionMint(...)
///   2. if mintAmount > 0:
///        _mintDetf(address(bondNftVault), mintAmount)  // same sink as seigniorage inventory
///        lastExpansionTimestamp = newTs
///   3. // bond vault: next _updateGlobalRewards sees balance increase → rewardPerShares ↑
///   4. _tryCompoundProtocolRewards()  // protocol share of expansion → BPT (Phase 1)
/// ```
///
/// Open: skip steps 1–2 always. No keeper; no fee-oracle expansion params; no post-deploy setters.
///
/// # Storage fields families add (canonical names)
///
/// - `expansionClosureRatePerSecond` (resolved)
/// - `expansionCatchUpMaxSeconds` (resolved)
/// - `expansionCatchUpCapBps` (resolved)
/// - `lastExpansionTimestamp`
library DETFNaturalExpansionLib {
    /// @notice Abstract peg scale for synthetic price (Policy narrative 1e18).
    uint256 internal constant ONE = 1e18;

    /// @notice Default: close 10% of premium per year → rate per second in 1e18 fixed point.
    /// @dev `uint256(1e17) / (365 days)` (= 0.10e18 / year). Explicit uint cast avoids rational_const.
    uint256 internal constant DEFAULT_CLOSURE_RATE_PER_SECOND = uint256(1e17) / uint256(365 days);

    /// @notice Default catch-up window: cap raw `dt` to one day per update.
    uint256 internal constant DEFAULT_CATCH_UP_MAX_SECONDS = 1 days;

    /// @notice Default supply-relative mint brake: 50 bps (0.50%) of totalSupply per update.
    uint256 internal constant DEFAULT_CATCH_UP_CAP_BPS = 50;

    /// @notice Skip mint when computed amount is at or below this dust (wei DETF).
    uint256 internal constant DEFAULT_EXPANSION_DUST = 1;

    /// @notice Basis-points denominator for catch-up supply cap.
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice Pure inputs for one expansion accrual evaluation.
    /// @dev Families assemble from live storage + synthetic view + resolved deploy params.
    struct AccrualInput {
        bool isLive;
        bool isPolicyMode; // false if Open
        bool isMintAllowed; // synthetic > mintThreshold under Policy; false if not
        uint256 syntheticPrice; // 1e18 peg scale
        uint256 totalDetfSupply;
        uint256 lastExpansionTimestamp;
        uint256 nowTimestamp;
        uint256 closureRatePerSecond; // resolved
        uint256 catchUpMaxSeconds; // resolved
        uint256 catchUpCapBps; // resolved
    }

    //--------------------------------------------------------------------------
    // Resolve
    //--------------------------------------------------------------------------

    /// @notice Map PkgArgs zeros to Stage 05 plan defaults.
    /// @dev `rateArg_ == 0` → `DEFAULT_CLOSURE_RATE_PER_SECOND` (not off). Open mode
    ///      disables expansion at compute time; explicit non-zero rate (even 1 wei) is kept.
    /// @param rateArg_ Deploy-time closure rate per second (1e18); 0 → default.
    /// @param catchUpSecondsArg_ Deploy-time max catch-up seconds; 0 → default 1 day.
    /// @param catchUpCapBpsArg_ Deploy-time supply-relative cap bps; 0 → default 50.
    /// @return rate_ Resolved closure rate per second.
    /// @return catchUpSeconds_ Resolved catch-up max seconds.
    /// @return capBps_ Resolved catch-up cap bps.
    function resolveExpansionParams(
        uint256 rateArg_,
        uint256 catchUpSecondsArg_,
        uint256 catchUpCapBpsArg_
    ) internal pure returns (uint256 rate_, uint256 catchUpSeconds_, uint256 capBps_) {
        rate_ = rateArg_ == 0 ? DEFAULT_CLOSURE_RATE_PER_SECOND : rateArg_;
        catchUpSeconds_ = catchUpSecondsArg_ == 0 ? DEFAULT_CATCH_UP_MAX_SECONDS : catchUpSecondsArg_;
        capBps_ = catchUpCapBpsArg_ == 0 ? DEFAULT_CATCH_UP_CAP_BPS : catchUpCapBpsArg_;
    }

    //--------------------------------------------------------------------------
    // Accrual
    //--------------------------------------------------------------------------

    /// @notice Pure: expansion DETF to mint now (0 if gated off or dust).
    /// @dev Gates first; then premium-closure with catch-up caps. When mint is zero because
    ///      of product gates (`!live` / Open / `!mintAllowed` / `dt==0` / zero supply),
    ///      `newTimestamp_` equals `lastExpansionTimestamp` (clock not advanced by this lib;
    ///      families only write timestamp when they mint). When the formula path runs but
    ///      mint floors to dust or zero premium/rate, `newTimestamp_` is `nowTimestamp` so
    ///      families that always store it do not re-evaluate the same dust window forever.
    /// @param in_ Accrual inputs (resolved rates, flags, timestamps, supply, synthetic).
    /// @return mintAmount_ Free DETF to mint into bond reward vault (0 if none).
    /// @return newTimestamp_ Timestamp to store as `lastExpansionTimestamp` when minting
    ///         (or when family elects to advance after a no-op formula path).
    function computeExpansionMint(AccrualInput memory in_)
        internal
        pure
        returns (uint256 mintAmount_, uint256 newTimestamp_)
    {
        newTimestamp_ = in_.lastExpansionTimestamp;

        // Product gates — Open, inert, and deadband never expand.
        if (!in_.isLive || !in_.isPolicyMode || !in_.isMintAllowed) {
            return (0, newTimestamp_);
        }
        if (in_.totalDetfSupply == 0) {
            return (0, newTimestamp_);
        }
        if (in_.nowTimestamp <= in_.lastExpansionTimestamp) {
            // dt == 0 (or clock skew): no accrual.
            return (0, newTimestamp_);
        }
        if (in_.closureRatePerSecond == 0 || in_.syntheticPrice == 0) {
            // Unresolved zero rate or invalid synthetic: no mint; advance clock so callers
            // do not re-loop a permanent zero-rate window if they store newTimestamp_.
            return (0, in_.nowTimestamp);
        }

        uint256 dt_ = in_.nowTimestamp - in_.lastExpansionTimestamp;
        if (in_.catchUpMaxSeconds > 0 && dt_ > in_.catchUpMaxSeconds) {
            dt_ = in_.catchUpMaxSeconds;
        }

        // Premium above abstract peg (1e18). Below peg ⇒ no premium-closure mint.
        uint256 premium_ = in_.syntheticPrice > ONE ? in_.syntheticPrice - ONE : 0;
        if (premium_ == 0) {
            return (0, in_.nowTimestamp);
        }

        // mint = totalSupply * premium * rate * dt / (ONE * syntheticPrice)
        // Nested mulDiv keeps intermediate products within uint256 safely.
        uint256 mint_ = Math.mulDiv(in_.totalDetfSupply, premium_, in_.syntheticPrice);
        mint_ = Math.mulDiv(mint_, in_.closureRatePerSecond, ONE);
        mint_ = Math.mulDiv(mint_, dt_, 1);

        // Supply-relative catch-up cap (bps). `0` disables the relative cap (absolute cap
        // is not in the Stage 05 resolve API — bps + max-seconds are the plan brakes).
        if (in_.catchUpCapBps > 0) {
            uint256 maxMint_ = Math.mulDiv(in_.totalDetfSupply, in_.catchUpCapBps, BPS_DENOMINATOR);
            if (mint_ > maxMint_) {
                mint_ = maxMint_;
            }
        }

        if (mint_ <= DEFAULT_EXPANSION_DUST) {
            return (0, in_.nowTimestamp);
        }

        return (mint_, in_.nowTimestamp);
    }
}
