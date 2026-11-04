// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";

/// h3-spot-pricing-siblings / H3SP-1
/// ComposedStable DETF primary (burn-gate-open) redemption pays a different fraction of the burned
/// protocol LP depending on route:
///   - exactIn  DETF -> rateAsset (WETH)          : pays BOTH reserve BPT legs (stable_ + common_)
///   - exactIn  DETF -> stablePool BPT            : pays ONE leg, rejoins the other into protocol LP
///   - exactOut DETF -> rateAsset (WETH)          : prices/pays ONE leg, rejoins the other
/// With the 50/25/25 reserve weights the one-leg routes forfeit ~half of the burner's backing to
/// remaining holders. Honest-user loss, no attacker needed.
contract ComposedExactOutOneLeg_Test is TestBase_ComposedFundedRoutes {
    function setUp() public override {
        super.setUp();
        // Honest deploy config: mint gate closed, primary burn gate open (mint > burn as required).
        _useComposed(_deployComposed(1e30, 1e29));
        _live();
    }

    function test_exactOut_vs_exactIn_primaryBurn() public {
        assertTrue(composedInfo.isBurningAllowed(), "primary burn open");
        uint256 raw_ = _buyRaw(alice, 100e18);
        uint256 d_ = raw_ / 4;
        uint256 snap_ = vm.snapshotState();

        // (A) exactIn burn d_ DETF -> WETH
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, d_);(uint256 wIn_,) = composedIn.exchangeIn(IERC20(composedDetf), d_, weth, 0, alice, false, block.timestamp);
        vm.stopPrank();
        console2.log("exactIn: DETF burned", d_);
        console2.log("exactIn: WETH out   ", wIn_);

        vm.revertToState(snap_);
        // (B) exactOut the same WETH amount
        uint256 quote_ = composedOut.previewExchangeOut(IERC20(composedDetf), weth, wIn_);
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, raw_);
        uint256 paid_ = composedOut.exchangeOut(IERC20(composedDetf), raw_, weth, wIn_, alice, false, block.timestamp);
        vm.stopPrank();
        console2.log("exactOut: quote DETF ", quote_);
        console2.log("exactOut: DETF paid  ", paid_);
        console2.log("exactOut/exactIn x1e4", paid_ * 1e4 / d_);
        assertGt(paid_, d_ * 17 / 10, "exactOut costs >1.7x DETF for the same WETH");

        vm.revertToState(snap_);
        // (C) exactIn burn d_ DETF -> stable BPT (one leg) vs value of exactIn WETH
        vm.startPrank(alice);
        IERC20(composedDetf).approve(composedDetf, d_);(uint256 bpt_,) = composedIn.exchangeIn(IERC20(composedDetf), d_, IERC20(address(composedStable)), 0, alice, false, block.timestamp);
        vm.stopPrank();(uint256 bptInWeth_,) = stableAdapter.previewExchangeIn(IERC20(address(composedStable)), bpt_, weth);
        console2.log("exactIn->stableBPT: BPT out", bpt_);
        console2.log("  ...valued in WETH        ", bptInWeth_);
        assertLt(bptInWeth_ * 10, wIn_ * 6, "BPT route returns <60% of the WETH route");
    }
}
