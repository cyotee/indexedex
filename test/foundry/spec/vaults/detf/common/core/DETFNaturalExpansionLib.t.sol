// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";

/// @notice Pure unit tests for DETFNaturalExpansionLib (Stage 05 natural expansion foundation).
/// @dev No diamond / CraneTest - exercises the production library entry points only.
///      Vectors T5.1–T5.10 from `05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`.
///      All mint expectations come from `computeExpansionMint` / `resolveExpansionParams`
///      (no parallel formula reimplementation).
contract DETFNaturalExpansionLibTest is Test {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant T0 = 1_700_000_000;

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------

    /// @dev Rich Policy live input: synthetic well above peg + mint threshold, 1 day later.
    function _richBase()
        internal
        pure
        returns (DETFNaturalExpansionLib.AccrualInput memory in_)
    {
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.isMintAllowed = true;
        in_.syntheticPrice = 1.10e18; // 10% premium
        in_.totalDetfSupply = 1_000_000e18;
        in_.lastExpansionTimestamp = T0;
        in_.nowTimestamp = T0 + 1 days;
        in_.closureRatePerSecond = DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND;
        in_.catchUpMaxSeconds = DETFNaturalExpansionLib.DEFAULT_CATCH_UP_MAX_SECONDS;
        in_.catchUpCapBps = DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS;
    }

    //--------------------------------------------------------------------------
    // Constants / resolve (T5.9 / T5.10)
    //--------------------------------------------------------------------------

    function test_defaults_matchPlan() public pure {
        assertEq(DETFNaturalExpansionLib.ONE, 1e18);
        assertEq(
            DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND,
            uint256(1e17) / uint256(365 days),
            "default rate = 10% of premium per year"
        );
        assertEq(DETFNaturalExpansionLib.DEFAULT_CATCH_UP_MAX_SECONDS, 1 days);
        assertEq(DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS, 50);
        assertEq(DETFNaturalExpansionLib.DEFAULT_EXPANSION_DUST, 1);
        assertTrue(DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND > 0);
    }

    function test_T5_9_resolveZeros_toDefaults() public pure {
        // T5.9: resolve(0,0,0) → documented defaults.
        (uint256 rate_, uint256 seconds_, uint256 bps_) =
            DETFNaturalExpansionLib.resolveExpansionParams(0, 0, 0);
        assertEq(rate_, DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND);
        assertEq(seconds_, DETFNaturalExpansionLib.DEFAULT_CATCH_UP_MAX_SECONDS);
        assertEq(bps_, DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS);
    }

    function test_T5_10_resolve_zeroMeansDefault_notOff_explicitRateKept() public pure {
        // T5.10: arg 0 → default rate (not off). Explicit non-zero retained (even 1 wei).
        (uint256 rateFromZero_,,) = DETFNaturalExpansionLib.resolveExpansionParams(0, 0, 0);
        assertEq(rateFromZero_, DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND);
        assertTrue(rateFromZero_ > 0, "0-arg resolves to non-zero default rate");

        uint256 explicitTiny_ = 1;
        (uint256 rateTiny_, uint256 sec_, uint256 bps_) =
            DETFNaturalExpansionLib.resolveExpansionParams(explicitTiny_, 3600, 25);
        assertEq(rateTiny_, explicitTiny_, "explicit rate 1 wei retained");
        assertEq(sec_, 3600);
        assertEq(bps_, 25);

        uint256 customRate_ = DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND * 2;
        (uint256 rateCustom_,,) = DETFNaturalExpansionLib.resolveExpansionParams(customRate_, 0, 0);
        assertEq(rateCustom_, customRate_, "non-zero rate retained when non-zero");
    }

    //--------------------------------------------------------------------------
    // Gates (T5.1–T5.5, T5.8)
    //--------------------------------------------------------------------------

    function test_T5_1_notLive_mintZero() public pure {
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.isLive = false;
        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.1: !isLive => mint 0");
        assertEq(newTs_, in_.lastExpansionTimestamp, "gate fail does not advance ts");
    }

    function test_T5_2_openMode_mintZero() public pure {
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.isPolicyMode = false; // Open
        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.2: Open (!isPolicyMode) => mint 0");
        assertEq(newTs_, in_.lastExpansionTimestamp);
    }

    function test_T5_3_notMintAllowed_mintZero() public pure {
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.isMintAllowed = false;
        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.3: !isMintAllowed => mint 0");
    }

    function test_T5_4_deadband_mintZero() public pure {
        // T5.4: synthetic at deadband / not strictly above mint threshold ⇒ caller sets
        // isMintAllowed=false (family reuses Policy strict >). Lib trusts the flag.
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.syntheticPrice = 1.05e18;
        in_.isMintAllowed = false;
        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.4: deadband (not mint-allowed) => mint 0");
    }

    function test_T5_5_dtZero_mintZero() public pure {
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.nowTimestamp = in_.lastExpansionTimestamp; // dt = 0
        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.5: dt == 0 => mint 0");
        assertEq(newTs_, in_.lastExpansionTimestamp);
    }

    function test_T5_8_zeroSupply_mintZero() public pure {
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.totalDetfSupply = 0;
        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "T5.8: totalSupply == 0 => mint 0");
        assertEq(newTs_, in_.lastExpansionTimestamp);
    }

    //--------------------------------------------------------------------------
    // Accrual path (T5.6 / T5.7)
    //--------------------------------------------------------------------------

    function test_T5_6_richSmallDt_mintPositiveDeterministic() public pure {
        // T5.6: rich synthetic, small dt → mint > 0 and deterministic for fixed inputs.
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.nowTimestamp = T0 + 1 hours;

        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertTrue(mint_ > 0, "T5.6: rich + small dt => mint > 0");
        assertEq(newTs_, in_.nowTimestamp, "successful path advances to now");

        // Determinism: identical AccrualInput ⇒ identical production output.
        (uint256 mint2_, uint256 newTs2_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint2_, mint_, "deterministic mint for fixed AccrualInput");
        assertEq(newTs2_, newTs_);

        // Double window (same rate/supply/synthetic) yields strictly more mint when
        // catch-up seconds allow and bps does not fully bind both (prove time growth).
        DETFNaturalExpansionLib.AccrualInput memory in2x_ = in_;
        in2x_.nowTimestamp = T0 + 2 hours;
        (uint256 mint2h_,) = DETFNaturalExpansionLib.computeExpansionMint(in2x_);
        assertTrue(mint2h_ > mint_, "2h accrual > 1h accrual under same rich inputs");
    }

    function test_T5_6_explicitTinyRate_stillExpandsSlowly() public pure {
        // T5.10 companion: explicit rate 1 wei is kept by resolve and still expands when
        // scale clears dust (Open is the off switch, not rate-0-after-resolve).
        (uint256 rate_, uint256 seconds_, uint256 bps_) =
            DETFNaturalExpansionLib.resolveExpansionParams(1, 365 days, 10_000);
        assertEq(rate_, 1);

        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.closureRatePerSecond = rate_;
        in_.catchUpMaxSeconds = seconds_;
        in_.catchUpCapBps = bps_;
        in_.nowTimestamp = T0 + 365 days;
        in_.totalDetfSupply = type(uint128).max;

        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        // Production path only: either dust-zero or positive; must not revert.
        // With huge supply + full year, expect positive (proves tiny rate is not treated as off).
        assertTrue(mint_ > 0, "explicit rate 1 wei still expands at large scale");
    }

    function test_T5_7_hugeDt_cappedByMaxSecondsAndBps() public pure {
        // T5.7: huge idle window stays within catch-up max seconds + bps cap.
        DETFNaturalExpansionLib.AccrualInput memory inHuge_ = _richBase();
        inHuge_.nowTimestamp = T0 + 100 days; // >> 1 day default catch-up max

        (uint256 mintHuge_, uint256 newTs_) =
            DETFNaturalExpansionLib.computeExpansionMint(inHuge_);
        assertTrue(mintHuge_ > 0, "T5.7: huge dt still mints (capped window)");
        assertEq(newTs_, inHuge_.nowTimestamp);

        // Same production path with now = last + catchUpMaxSeconds must equal huge-dt mint
        // (proves seconds cap without reimplementing the formula).
        DETFNaturalExpansionLib.AccrualInput memory inCapped_ = inHuge_;
        inCapped_.nowTimestamp = T0 + DETFNaturalExpansionLib.DEFAULT_CATCH_UP_MAX_SECONDS;
        (uint256 mintCapped_,) = DETFNaturalExpansionLib.computeExpansionMint(inCapped_);
        assertEq(mintHuge_, mintCapped_, "T5.7: 100d equals 1d when catchUpMaxSeconds=1 day");

        // Mint ≤ supply-relative bps cap (uses Math only as the cap expression, not the mint formula).
        uint256 bpsCap_ = Math.mulDiv(
            inHuge_.totalDetfSupply, inHuge_.catchUpCapBps, 10_000
        );
        assertTrue(mintHuge_ <= bpsCap_, "T5.7: mint <= catchUpCapBps of supply");

        // Shorter-than-cap window yields less or equal mint (monotone in dt under same gates).
        DETFNaturalExpansionLib.AccrualInput memory inShort_ = inHuge_;
        inShort_.nowTimestamp = T0 + 1 hours;
        (uint256 mintShort_,) = DETFNaturalExpansionLib.computeExpansionMint(inShort_);
        assertTrue(mintShort_ > 0 && mintShort_ <= mintHuge_, "1h mint in (0, capped-huge]");
    }

    function test_bpsCap_bindsWhenRateAndDtWouldExceed() public pure {
        // Force bps to bind: high premium, aggressive rate, default 50 bps.
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.syntheticPrice = 2e18; // 100% premium
        in_.closureRatePerSecond = uint256(1e17) / uint256(1 days); // 10% of premium / day
        in_.catchUpCapBps = 50;
        in_.nowTimestamp = T0 + 1 days;

        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        uint256 bpsCap_ = Math.mulDiv(in_.totalDetfSupply, 50, 10_000);
        assertEq(mint_, bpsCap_, "bps cap binds on aggressive rate");

        // Raising bps allows more mint (proves bps was the binding constraint).
        in_.catchUpCapBps = 100;
        (uint256 mintHigherBps_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertTrue(mintHigherBps_ > mint_, "higher bps raises cap");
        assertEq(mintHigherBps_, Math.mulDiv(in_.totalDetfSupply, 100, 10_000));
    }

    function test_premiumZero_mintZero() public pure {
        // Synthetic at peg: premium 0 even if caller wrongly sets isMintAllowed.
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.syntheticPrice = ONE;
        in_.isMintAllowed = true;
        (uint256 mint_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0);
        assertEq(newTs_, in_.nowTimestamp);
    }

    function test_dust_floorsToZero() public pure {
        // Tiny rate + tiny supply + short dt → computed mint ≤ dust → 0 from production.
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.totalDetfSupply = 100;
        in_.closureRatePerSecond = 1;
        in_.nowTimestamp = T0 + 1;
        in_.catchUpCapBps = 10_000;

        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "dust path returns 0");
    }

    function test_unresolvedZeroRate_mintZero() public pure {
        // Family that forgets resolve and stores rate 0: no mint (Open is the intended off switch;
        // zero rate after resolve never happens because 0 → default).
        DETFNaturalExpansionLib.AccrualInput memory in_ = _richBase();
        in_.closureRatePerSecond = 0;
        (uint256 mint_,) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        assertEq(mint_, 0, "unresolved rate 0 => mint 0");
    }
}
