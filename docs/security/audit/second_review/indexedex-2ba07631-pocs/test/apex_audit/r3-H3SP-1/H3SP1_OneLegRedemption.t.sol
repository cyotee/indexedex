// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";

/// r3 / H3SP-1: ComposedStable primary (burn-gate open) redemption via exact-out (and exact-in -> pool BPT)
/// charges the full proportional LP slice but pays only one reserve BPT leg; the other leg is re-joined
/// into protocol LP, i.e. forfeited to the remaining DETF holders. Honest-user loss.
contract H3SP1_OneLegRedemption_Test is TestBase_ComposedFundedRoutes {
    address internal holder2;

    function setUp() public override {
        super.setUp();
        holder2 = makeAddr("h3sp1_holder2");
        _useComposed(_deployComposed(1e30, 1e29));
        _live();
    }

    function _lp() internal view returns (uint256) {
        IERC20 lp_ = IERC20(composedInfo.reservePool());
        return lp_.balanceOf(composedDetf) + lp_.balanceOf(composedInfo.bondNftVault());
    }

    function _sellIn(address who_, uint256 amt_, IERC20 out_) internal returns (uint256 got_) {
        vm.startPrank(who_);
        IERC20(composedDetf).approve(composedDetf, amt_);(got_,) = composedIn.exchangeIn(IERC20(composedDetf), amt_, out_, 0, who_, false, block.timestamp);
        vm.stopPrank();
    }

    function _sellOut(address who_, uint256 max_, IERC20 out_, uint256 want_) internal returns (uint256 paid_) {
        uint256 before_ = out_.balanceOf(who_);
        vm.startPrank(who_);
        IERC20(composedDetf).approve(composedDetf, max_);
        paid_ = composedOut.exchangeOut(IERC20(composedDetf), max_, out_, want_, who_, false, block.timestamp);
        vm.stopPrank();
        assertEq(out_.balanceOf(who_) - before_, want_, "exact-out delivered requested amount");
    }

    struct R { uint256 aliceRaw; uint256 bobRaw; uint256 d; uint256 wIn; uint256 bobA; uint256 quote; uint256 wFair;
        uint256 lp0; uint256 s0; uint256 paid; uint256 lp1; uint256 s1; uint256 bobB; }

    function test_exactOut_forfeitFlowsToRemainingHolders() public {
        R memory r;
        r.aliceRaw = _buyRaw(alice, 100e18);
        r.bobRaw = _buyRaw(holder2, 100e18);
        assertTrue(composedInfo.isBurningAllowed(), "primary burn open");
        console2.log("synthetic price      ", composedInfo.syntheticDetfEthPrice());
        r.d = r.aliceRaw / 4;
        uint256 snap_ = vm.snapshotState();

        // A) baseline: alice exact-in d -> WETH, then holder2 redeems all to WETH
        r.wIn = _sellIn(alice, r.d, weth);
        r.bobA = _sellIn(holder2, r.bobRaw, weth);
        vm.revertToState(snap_);

        // C) fair value of the DETF alice will be charged on exact-out (same pre-state, exact-in route)
        r.quote = composedOut.previewExchangeOut(IERC20(composedDetf), weth, r.wIn);
        r.wFair = _sellIn(alice, r.quote, weth);
        vm.revertToState(snap_);

        // B) alice exact-out wIn WETH, then holder2 redeems all to WETH
        r.lp0 = _lp(); r.s0 = IERC20(composedDetf).totalSupply();
        r.paid = _sellOut(alice, r.aliceRaw, weth, r.wIn);
        r.lp1 = _lp(); r.s1 = IERC20(composedDetf).totalSupply();
        r.bobB = _sellIn(holder2, r.bobRaw, weth);
        _report(r);
    }

    function _report(R memory r) internal {
        uint256 aliceLoss_ = r.wFair - r.wIn;
        uint256 bobGain_ = r.bobB - r.bobA;
        uint256 expectedBobGain_ = aliceLoss_ * r.bobRaw / r.s1;
        console2.log("exactIn  DETF burned       ", r.d);
        console2.log("exactIn  WETH out          ", r.wIn);
        console2.log("exactOut DETF quote        ", r.quote);
        console2.log("exactOut DETF paid         ", r.paid);
        console2.log("exactOut/exactIn x1e4      ", r.paid * 1e4 / r.d);
        console2.log("WETH fair value of paid    ", r.wFair);
        console2.log("alice loss (WETH)          ", aliceLoss_);
        console2.log("alice loss bps of fair     ", aliceLoss_ * 1e4 / r.wFair);
        console2.log("LP/DETF before x1e18       ", r.lp0 * 1e18 / r.s0);
        console2.log("LP/DETF after  x1e18       ", r.lp1 * 1e18 / r.s1);
        console2.log("protocol LP retained       ", r.lp1 - (r.lp0 - r.paid * r.lp0 / r.s0));
        console2.log("holder2 WETH baseline      ", r.bobA);
        console2.log("holder2 WETH after         ", r.bobB);
        console2.log("holder2 gain (WETH)        ", bobGain_);
        console2.log("holder2 expected pro-rata  ", expectedBobGain_);

        assertEq(r.paid, r.quote, "charged the quote");
        assertGt(r.paid, r.d * 17 / 10, "exact-out costs >1.7x DETF for same WETH");
        assertGt(aliceLoss_ * 10, r.wFair * 4, "alice forfeits >40% of fair value of burned DETF");
        assertGt(r.lp1 * 1e18 / r.s1, r.lp0 * 1e18 / r.s0, "LP backing per DETF increased");
        assertGt(bobGain_, 0, "remaining holder gains");
        assertApproxEqRel(bobGain_, expectedBobGain_, 0.25e18, "holder gain ~ pro-rata share of forfeit");
    }

    function test_exactIn_toStableBpt_forfeitFlowsToRemainingHolders() public {
        uint256 aliceRaw_ = _buyRaw(alice, 100e18);
        uint256 bobRaw_ = _buyRaw(holder2, 100e18);
        uint256 d_ = aliceRaw_ / 4;
        uint256 snap_ = vm.snapshotState();

        uint256 wIn_ = _sellIn(alice, d_, weth);
        uint256 bobA_ = _sellIn(holder2, bobRaw_, weth);
        vm.revertToState(snap_);

        uint256 bpt_ = _sellIn(alice, d_, IERC20(address(composedStable)));(uint256 bptWeth_,) = stableAdapter.previewExchangeIn(IERC20(address(composedStable)), bpt_, weth);
        uint256 s1_ = IERC20(composedDetf).totalSupply();
        uint256 bobB_ = _sellIn(holder2, bobRaw_, weth);
        uint256 loss_ = wIn_ - bptWeth_;
        console2.log("exactIn->WETH              ", wIn_);
        console2.log("exactIn->stableBPT valued  ", bptWeth_);
        console2.log("loss bps                   ", loss_ * 1e4 / wIn_);
        console2.log("holder2 gain               ", bobB_ - bobA_);
        console2.log("holder2 expected pro-rata  ", loss_ * bobRaw_ / s1_);
        assertGt(loss_ * 10, wIn_ * 4, ">40% forfeited on BPT route");
        assertApproxEqRel(bobB_ - bobA_, loss_ * bobRaw_ / s1_, 0.25e18, "holder gain ~ pro-rata forfeit");
    }

    function test_exactOut_toStableBpt_vs_exactIn() public {
        uint256 aliceRaw_ = _buyRaw(alice, 100e18);
        _buyRaw(holder2, 100e18);
        uint256 d_ = aliceRaw_ / 4;
        uint256 snap_ = vm.snapshotState();
        uint256 bpt_ = _sellIn(alice, d_, IERC20(address(composedStable)));
        vm.revertToState(snap_);
        uint256 paid_ = _sellOut(alice, aliceRaw_, IERC20(address(composedStable)), bpt_);
        console2.log("exactIn d->BPT  ", d_, bpt_);
        console2.log("exactOut BPT paid", paid_);
        console2.log("ratio x1e4       ", paid_ * 1e4 / d_);
        // both BPT routes are one-leg: they should be priced consistently with each other
        assertApproxEqRel(paid_, d_, 0.02e18, "BPT exact-out ~ BPT exact-in (both one-leg)");
    }
}
