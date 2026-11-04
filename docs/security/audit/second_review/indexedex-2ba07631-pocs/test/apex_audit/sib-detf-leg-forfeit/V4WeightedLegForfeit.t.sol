// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Weighted_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Policy.sol";

/// sib-detf-leg-forfeit / UniswapV4 DETF on a 3-token weighted hook (DETF 40 / pair0 30 / pair1 30),
/// production Policy thresholds (mint 1.05, burn 0.95). Burn gate is opened by real public DETF sells.
/// _burnHeld: lpOut = d * protocolLp / supply, exitProportional, _payBurnOut pays only the tokenOut pair leg;
/// the other pair leg is left on the DETF and swept back into protocol LP (_trySweepDust).
contract SibLegForfeit_V4Weighted_Test is TestBase_UniswapV4Detf_Weighted_Policy {
    address internal holder2;
    address internal victim;

    function setUp() public override {
        TestBase_UniswapV4Detf_Weighted_Policy.setUp();
        holder2 = makeAddr("sib_holder2");
        victim = makeAddr("sib_alice");
    }

    function _mintAs(address d, address who_, IERC20 tok_, uint256 amt_) internal returns (uint256 got_) {
        _fundToken(address(tok_), who_, amt_);
        vm.startPrank(who_);
        tok_.approve(d, amt_);got_ = IStandardExchangeIn(d).exchangeIn(tok_, amt_, IERC20(d), 0, who_, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _burnAs(address d, address who_, uint256 amt_, IERC20 out_) internal returns (uint256 got_) {
        vm.startPrank(who_);
        IERC20(d).approve(d, amt_);got_ = IStandardExchangeIn(d).exchangeIn(IERC20(d), amt_, out_, 0, who_, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _protocolLp(address d) internal view returns (uint256) {
        address hook_ = IUniswapV4Detf(d).hook();
        return IERC20(hook_).balanceOf(d) + IERC20(hook_).balanceOf(IUniswapV4Detf(d).bondNftVault());
    }

    function _i(address hook_, address t_) internal view returns (uint256) {
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) if (toks_[i] == t_) return i;
        revert("idx");
    }

    struct M { uint256 d; uint256 lpOut; uint256 sliceOut; uint256 sliceOther; uint256 otherVal; uint256 recv;
        uint256 lp0; uint256 lp1; uint256 sAfter; uint256 h2Base; uint256 h2After; }

    function _openBurnGate(address d, IERC20 out_) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        _ensureFreeDetf(d, 1e9);
        for (uint256 i_; i_ < 32 && !info_.isBurningAllowed(out_); ++i_) {
            uint256 input_ = IERC20(d).balanceOf(detfUser) / 2;
            uint256 budget_ = IERC20(d).balanceOf(info_.hook()) / 10;
            if (input_ > budget_) input_ = budget_;
            if (input_ == 0) break;
            _policyPublicTrade(info_.hook(), IERC20(d), out_, input_);
        }
    }

    function _run(IERC20 out_, IERC20 other_) internal {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        address hook_ = info_.hook();
        // honest holders buy DETF while the mint gate is open (primary mint)
        _mintAs(d, victim, out_, 10 ether);
        _mintAs(d, holder2, out_, 10 ether);
        // market sell-off by an unrelated actor pushes synthetic below burnThreshold
        _openBurnGate(d, out_);
        assertTrue(info_.isBurningAllowed(out_), "primary burn open for tokenOut");
        console2.log("synthetic / burnThreshold ", info_.syntheticPrice(), info_.burnThreshold());

        M memory m;
        m.d = IERC20(d).balanceOf(victim) / 2;
        uint256 h_ = IERC20(d).balanceOf(holder2);
        uint256 snap_ = vm.snapshotState();
        m.h2Base = _burnAs(d, holder2, h_, out_);
        vm.revertToState(snap_);

        m.lp0 = _protocolLp(d);
        m.lpOut = m.d * m.lp0 / IERC20(d).totalSupply();
        uint256[] memory ex_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(m.lpOut);
        m.sliceOut = ex_[_i(hook_, address(out_))];
        m.sliceOther = ex_[_i(hook_, address(other_))];
        // market value of the forfeited pair leg in tokenOut (swap quote after fees => conservative)
        m.otherVal = IUniswapV4SeBufferHook(hook_).previewSwapExactIn(address(other_), address(out_), m.sliceOther);

        m.recv = _burnAs(d, victim, m.d, out_);
        m.lp1 = _protocolLp(d);
        m.sAfter = IERC20(d).totalSupply();
        m.h2After = _burnAs(d, holder2, h_, out_);

        uint256 lossBps_ = m.otherVal * 1e4 / (m.otherVal + m.sliceOut);
        uint256 lpGain_ = m.lp1 - m.lp0 * m.sAfter / (m.sAfter + m.d);
        console2.log("  alice DETF burned          ", m.d);
        console2.log("  lpOut                      ", m.lpOut);
        console2.log("  slice tokenOut leg         ", m.sliceOut);
        console2.log("  received                   ", m.recv);
        console2.log("  slice forfeited pair leg   ", m.sliceOther);
        console2.log("  forfeited value in tokenOut", m.otherVal);
        console2.log("  fair non-DETF value        ", m.sliceOut + m.otherVal);
        console2.log("  alice loss bps of backing  ", lossBps_);
        console2.log("  remaining-holder LP gain   ", lpGain_);
        console2.log("  LP gain / lpOut bps        ", lpGain_ * 1e4 / m.lpOut);
        console2.log("  pair-other left on DETF    ", other_.balanceOf(d));
        console2.log("  holder2 redeem base/after  ", m.h2Base, m.h2After);

        assertApproxEqRel(m.recv, m.sliceOut, 1e15, "paid only the tokenOut leg of the proportional slice");
        assertGt(lossBps_, 1000, "user forfeits >10% of non-DETF backing");
        assertGt(lpGain_, 0, "forfeit swept into protocol LP");
    }

    function test_v4w_burnToPair0_forfeitsPair1() public { _run(IERC20(address(pair0)), IERC20(address(pair1))); }
    function test_v4w_burnToPair1_forfeitsPair0() public { _run(IERC20(address(pair1)), IERC20(address(pair0))); }
}
