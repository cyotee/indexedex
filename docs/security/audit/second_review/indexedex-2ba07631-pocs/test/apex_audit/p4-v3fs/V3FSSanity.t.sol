// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {V3FSFixture} from "./V3FSInvariant.t.sol";

/// @notice (a) Sanity: the no-free-value invariant DOES catch the known blocked-mode CP bug when un-quarantined.
///         (b) Deterministic non-vacuity walk over every campaign selector, with per-selector success counts.
contract V3FSSanityTest is V3FSFixture {
    function test_sanity_invariantHoldsAtGenesis() public view {
        _checkAll();
        (bool ok, int256 profit, uint256 allowance) = h.checkNoFreeValue();
        console2.log("genesis attacker profit", profit);
        console2.log("genesis allowance", allowance);
        assertTrue(ok);
    }

    /// Un-quarantined known finding v3fs-blocked-mode-callback-cp (vault ~50% of pool L, sqrt push 2x, 97% of free1).
    function test_sanity_knownBlockedCP_breaksNoFreeValue() public {
        h.a_blockedCP(10_000, 97);
        assertEq(h.oks(30), 1, "blocked-CP leg executed in blocked mode");
        (bool ok, int256 profit, uint256 allowance) = h.checkNoFreeValue();
        console2.log("blocked-CP attacker profit (wei)", profit);
        console2.log("allowance (fees + tol)", allowance);
        console2.log("passive drops / CP-rate drops", h.passiveDrops(), h.rateDrops());
        assertFalse(ok, "INV-1 must catch the known blocked-CP drain");
        assertGt(h.passiveDrops(), 0, "INV-4b must also catch it (victim loses)");
    }

    /// Weaker push (vault still large): still caught.
    function test_sanity_knownBlockedCP_smallPush() public {
        h.a_blockedCP(3_000, 90);
        (bool ok, int256 profit,) = h.checkNoFreeValue();
        console2.log("blocked-CP (sqrt x1.3) attacker profit (wei)", profit);
        assertFalse(ok, "INV-1 catches the smaller push too");
    }

    function _r(uint256 i, uint256 k) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(i, k)));
    }

    /// Deterministic round-robin walk; every targeted selector is exercised ~12 times with random args.
    /// Quarantined idle-sandwich spot mint (sub 2) is caught by the per-step passive ghost INV-4c as well as INV-1.
    function test_sanity_idleSpotMint_caughtByINV4c() public {
        h.a_sandwich(18, false, 8752, 183, 3727);
        console2.log("unexplained passive loss (op, max)", uint256(h.upOp()), h.upMax());
        assertGt(h.unexplainedPassiveLoss(), h.tolerance(), "INV-4c catches the quarantined idle spot mint");
    }

    function test_nonvacuity_walk() public {
        h.setSandwichMask(0xf8); // same quarantine as the campaign (sandwich subs 0/1/2 = known spot-mint class)
        for (uint256 i; i < 288; ++i) {
            uint256 a = _r(i, 1);
            uint256 b = _r(i, 2);
            uint256 c = _r(i, 3);
            bool pre = _r(i, 4) % 2 == 0;
            uint256 sel = i % 24;
            if (sel == 0) h.h_dualDeposit(a, b);
            else if (sel == 1) h.h_dualExit(a, b);
            else if (sel == 2) h.h_zapOutExactIn(a, b, c);
            else if (sel == 3) h.h_zapOutExactOut(a, b, c);
            else if (sel == 4) h.h_swapExactIn(a, b, c);
            else if (sel == 5) h.h_swapExactOut(a, b, c);
            else if (sel == 6) h.h_keeperRebalance(a);
            else if (sel == 7) h.warp(a);
            else if (sel == 8) h.a_singleDeposit(a, b, pre, c);
            else if (sel == 9) h.a_dualDeposit(a, b, pre);
            else if (sel == 10) h.a_mintExactOut(a, b, pre, c);
            else if (sel == 11) h.a_zapOutExactIn(a, b, pre, c);
            else if (sel == 12) h.a_zapOutExactOut(a, b, pre, c);
            else if (sel == 13) h.a_dualExit(a, pre, c);
            else if (sel == 14) h.a_swapExactIn(a, b, pre);
            else if (sel == 15) h.a_swapExactOut(a, b, pre, c);
            else if (sel == 16) h.a_donate(a, b);
            else if (sel == 17) h.a_claimCredit(a);
            else if (sel == 18) h.a_syDeposit(a, b);
            else if (sel == 19) h.a_syRedeem(a, b);
            else if (sel == 20) h.a_syRedeemInternal(a, b);
            else if (sel == 21) h.a_rebalance();
            else if (sel == 22) h.a_sandwich(a, pre, b, c, _r(i, 5));
            else h.a_importAttempt();
        }
        (uint256 calls, uint256 oks) = h.totals();
        console2.log("walk calls / ok", calls, oks);
        console2.log(h.summary());
        (bool ok, int256 profit, uint256 allowance) = h.checkNoFreeValue();
        console2.log("walk attacker profit", profit);
        console2.log("walk allowance", allowance);
        console2.log("previewMismatch / deliveryMismatch", h.previewMismatch(), h.deliveryMismatch());
        console2.log("rsync / rateDrops / passiveDrops", h.rsyncViolations(), h.rateDrops(), h.passiveDrops());
        assertGe(oks * 100, calls * 60, "most calls succeed");
        _checkAll();
        ok;
    }
}
