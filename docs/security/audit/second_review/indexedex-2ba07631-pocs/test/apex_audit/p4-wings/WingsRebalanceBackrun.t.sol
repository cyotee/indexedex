// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {WingsInvariantTest} from "./WingsInvariant.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";

/// @notice Minimization of the first invariant-(4) break: rebalance at the fair price + adversary back-run.
import {Vm} from "forge-std/Vm.sol";

contract WingsRebalanceBackrunTest is WingsInvariantTest {
    using StateLibrary for IPoolManager;

    function _mark(uint8 vi) internal view returns (uint256) { (uint256 a0, uint256 a1,) = handler.inventory(vi); return a0 + a1; }
    function _liq(uint8 vi) internal view returns (uint256) { return (vi == 0 ? wings0 : wings1).liquidationValue().value; }
    function _pos(uint8 vi) internal view {
        for (uint8 i; i < 3; ++i) _slot(vi, i);
        (uint256 l0, uint256 l1) = (vi == 0 ? wings0 : wings1).localReserves();
        console2.log("   local0/local1", l0, l1);
    }
    function _slot(uint8 vi, uint8 i) internal view {
        (int24 lo, int24 up, uint128 l,) = (vi == 0 ? wings0 : wings1).position(i);
        console2.log("   slot/liq", i, l);
        console2.log("   lo/up", vm.toString(lo), vm.toString(up));
    }

    struct RS { int256 p; uint256 acc; uint256 m; uint256 v; uint256 ok; }
    function _rs(uint8 vi) internal view returns (RS memory r) {
        r.p = handler.advPnL(); r.acc = handler.advAcceptedLoss(); r.m = _mark(vi); r.v = _liq(vi); r.ok = handler.advRebalanceOk();
    }
    function _round(uint8 vi, uint256 i) internal returns (int256 dPnl, uint256 dMark) {
        RS memory b = _rs(vi);
        handler.a_rebalanceBackrun(vi);
        RS memory a = _rs(vi);
        dPnl = a.p - b.p;
        dMark = b.m > a.m ? b.m - a.m : 0;
        console2.log("round", i, "rebalanced", a.ok - b.ok);
        console2.log("  adv profit"); console2.logInt(dPnl);
        console2.log("  vault accepted liq-loss", a.acc - b.acc);
        console2.log("  vault fair mark before/after", b.m, a.m);
        console2.log("  vault liq value before/after", b.v, a.v);
    }

    function test_minimized_depositThenBackrun() public {
        _pos(0);
        handler.h_deposit(0, 0, 386); // bound -> 1e9 + small
        int256 tot;
        for (uint256 i; i < 6; ++i) { (int256 d,) = _round(0, i); tot += d; }
        _pos(0);
        console2.log("TOTAL adversary profit over 6 rounds"); console2.logInt(tot);
        console2.log("TOTAL vault accepted liq-loss", handler.advAcceptedLoss());
        console2.log("TOTAL designed loss cap (1% of progress)", handler.advRebalanceCap());
        console2.log("violations", handler.violations());
        // classification: extraction stays inside the vault's designed rebalance loss budget -> not a new bug
        assertLe(tot, int256(handler.advRebalanceCap()), "profit exceeds designed cap");
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_noDeposit_backrun() public {
        int256 tot;
        for (uint256 i; i < 4; ++i) { (int256 d,) = _round(0, i); tot += d; }
        console2.log("TOTAL (no deposit)"); console2.logInt(tot);
    }

    function test_backrun_wings1() public {
        handler.h_deposit(0, 1, 386);
        int256 tot;
        for (uint256 i; i < 4; ++i) { (int256 d,) = _round(1, i); tot += d; }
        console2.log("TOTAL wings1"); console2.logInt(tot);
    }

    /// repeated honest flow: deposits keep arriving, adversary back-runs every rebalance
    function test_backrun_perDeposit() public {
        int256 tot; uint256 dep;
        for (uint256 i; i < 6; ++i) {
            handler.h_deposit(i, 0, 1e16); dep += 1e16;
            (int256 d,) = _round(0, i); tot += d;
        }
        console2.log("deposited", dep);
        console2.log("TOTAL profit"); console2.logInt(tot);
        console2.log("accepted", handler.advAcceptedLoss());
        console2.log("designed cap", handler.advRebalanceCap());
    }

    /// Minimized fuzz break #2 (fair-mark loss > designed cap) -- shrunk sequence replayed verbatim.
    function test_minimized_fairLossExceedsCap() public {
        handler.h_routerPushedDeposit(3995, 19262, 45317445843634458232029953611313429631259842000772740294060856619953699391273);
        handler.h_deposit(64, 5491473367361187986832609241631837230097710544299144715359218046187896884396, 77);
        _pos(0);
        (int256 d, uint256 dMark) = _round(0, 0);
        console2.log("fair mark loss", dMark, "designed cap", handler.advRebalanceCap());
        console2.log("liq accepted loss", handler.advAcceptedLoss());
        console2.log("adv profit"); console2.logInt(d);
        console2.log("first violation", handler.firstViolation(), handler.violationA(), handler.violationB());
        _pos(0);
    }

    /// sweep: deposit size relative to vault -> fair loss / cap ratio and back-run profit / cap
    function test_sweep_fairLossVsCap() public {
        uint256[5] memory deps = [uint256(1e16), 3e16, 1e17, 2e17, 4e17];
        for (uint256 k; k < deps.length; ++k) {
            uint256 snap = vm.snapshotState();
            handler.h_deposit(1, 0, deps[k] - 1); // in range -> exact
            uint256 cap0 = handler.advRebalanceCap();
            (int256 d, uint256 dMark) = _round(0, k);
            uint256 cap = handler.advRebalanceCap() - cap0;
            console2.log("deposit", deps[k]);
            console2.log("  fair loss / cap / ratio x100", dMark, cap, cap == 0 ? 0 : dMark * 100 / cap);
            console2.log("  backrun profit / cap x100"); console2.logInt(cap == 0 ? int256(0) : d * 100 / int256(cap));
            vm.revertToState(snap);
        }
    }

    // ---------------------------------------------------------------------------------------------------
    // Self-triggered: unprivileged attacker deposits at the fair price, calls the permissionless rebalance,
    // back-runs the vault's own swap back to p0, then redeems. Everything at clean states, no front-run.
    // ---------------------------------------------------------------------------------------------------
    struct SR { int256 pnl; uint256 anchorBefore; uint256 anchorAfter; bool dumped; bool ok; }

    function _logs() internal returns (Vm.Log[] memory) { return vm.getRecordedLogs(); }
    function _val(address a) internal view returns (int256) { return int256(token0.balanceOf(a) + token1.balanceOf(a)); }

    function _anchorFair() internal view returns (uint256) {
        (uint256 a0, uint256 a1,) = handler.inventory(0);
        return (a0 + a1) * IERC20(address(wings0)).balanceOf(handler.anchor()) / IERC20(address(wings0)).totalSupply();
    }

    function _selfTriggered(uint256 dep) internal returns (SR memory r) {
        address mallory = makeAddr("mallory");
        Actor bot = new Actor(pool, address(this));
        token0.mint(address(bot), 1e24); token1.mint(address(bot), 1e24);
        token0.mint(mallory, dep);
        int256 v0 = _val(mallory) + _val(address(bot));
        r.anchorBefore = _anchorFair();
        vm.startPrank(mallory);
        token0.approve(address(wings0), type(uint256).max);uint256 sh = IStandardExchangeIn(address(wings0)).exchangeIn(token0, dep, IERC20(address(wings0)), 0, mallory, false, block.timestamp);
        try Rebalance(address(wings0)).rebalance(0, block.timestamp) returns (uint256) { r.ok = true; } catch {}
        vm.stopPrank();
        (uint160 p,,,) = pool.getSlot0(key.toId());
        if (p != handler.P0()) bot.swapTo(key, p > handler.P0(), 1e24, handler.P0());
        vm.recordLogs();
        vm.prank(mallory);IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), sh, token0, 0, mallory, false, block.timestamp);
        Vm.Log[] memory logs = _logs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics.length > 2
                && logs[i].topics[0] == keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)")
                && address(uint160(uint256(logs[i].topics[2]))) == address(wings0)) r.dumped = true;
        }
        (p,,,) = pool.getSlot0(key.toId());
        if (p != handler.P0()) bot.swapTo(key, p > handler.P0(), 1e24, handler.P0());
        r.pnl = _val(mallory) + _val(address(bot)) - v0;
        r.anchorAfter = _anchorFair();
    }

    function test_selfTriggered_sweep() public {
        uint256[5] memory deps = [uint256(2e16), 5e16, 1e17, 2e17, 4e17];
        for (uint256 k; k < deps.length; ++k) {
            uint256 snap = vm.snapshotState();
            SR memory r = _selfTriggered(deps[k]);
            console2.log("deposit", deps[k], "rebalanced", r.ok);
            console2.log("  redeem dumped (known forced-dump path)", r.dumped);
            console2.log("  attacker net PnL @p0"); console2.logInt(r.pnl);
            console2.log("  anchor (honest holder) fair value before/after", r.anchorBefore, r.anchorAfter);
            vm.revertToState(snap);
        }
    }

    // ---------------------------------------------------------------------------------------------------
    // Minimized medium-run break: narrow JIT + tiny push before rebalance amplifies the vault's loss.
    // ---------------------------------------------------------------------------------------------------
    function _replayPre() internal { handler.h_depositExactShares(1520, 40, 9443); }

    function _jitCase(string memory tag, uint256 range, uint256 l, uint256 amt) internal {
        uint256 snap = vm.snapshotState();
        _replayPre();
        RS memory b = _rs(0);
        uint256 m1b = _mark(1);
        uint256 cap0 = handler.advRebalanceCap();
        vm.recordLogs();
        handler.a_jitSwapRebalanceRestore(0, range, l, true, amt);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        RS memory a = _rs(0);
        console2.log(tag);
        console2.log("  adv profit"); console2.logInt(a.p - b.p);
        console2.log("  designed cap this action", handler.advRebalanceCap() - cap0);
        console2.log("  wings0 fair mark before/after", b.m, a.m);
        console2.log("  wings1 fair mark before/after", m1b, _mark(1));
        console2.log("  wings0 liq before/after", b.v, a.v);
        console2.log("  violations", handler.violations());
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics.length > 2
                && logs[i].topics[0] == keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)")) {
                (int128 d0, int128 d1, uint160 sp,, int24 tick,) = abi.decode(logs[i].data, (int128, int128, uint160, uint128, int24, uint24));
                address sender = address(uint160(uint256(logs[i].topics[2])));
                console2.log("   swap by", sender == address(wings0) ? "VAULT0" : sender == address(handler.adv()) ? "ADV" : "other");
                console2.log("     d0/d1"); console2.logInt(d0); console2.logInt(d1);
                console2.log("     tick", vm.toString(tick), sp);
            }
        }
        vm.revertToState(snap);
    }

    function test_jitAmplify_minimized() public {
        // decoded fuzz args: range 1460175109 -> kind 1 (narrow +-600 ticks), L = bound(2270264389,1e15,1e19), push 1e13+35563
        _jitCase("A fuzz case: narrow JIT + tiny push + rebalance", 1460175109, 2270264389, 35563);
        _jitCase("B same, no push (amt%4==0)", 1460175109, 2270264389, 35564);
        _jitCase("C full-range JIT (kind 0) + tiny push", 1460175108 - 1, 2270264389, 35563);
        uint256 snap = vm.snapshotState();
        _replayPre();
        int256 p0 = handler.advPnL();
        handler.a_rebalanceBackrun(0);
        console2.log("D clean rebalance back-run (R1 baseline) profit"); console2.logInt(handler.advPnL() - p0);
        vm.revertToState(snap);
        snap = vm.snapshotState();
        _replayPre();
        p0 = handler.advPnL();
        handler.a_swapRebalanceRestore(0, true, 35563, 1);
        console2.log("E tiny push + rebalance, no JIT, profit"); console2.logInt(handler.advPnL() - p0);
        console2.log("  violations", handler.violations());
        vm.revertToState(snap);
    }

    // ---------------------------------------------------------------------------------------------------
    // Deep-run (256x100) break replay: JIT-only (no push) rebalance, excess over max(cap, clean baseline).
    // ---------------------------------------------------------------------------------------------------
    function _deepPrefix() internal {
        handler.h_depositExactShares(1980, 10, 1005);
        handler.h_syDeposit(20000000000000000, 9247644692000063, 15794);
        handler.a_swapRebalanceRestore(659918, false, 641, 0);
        handler.h_syDeposit(4849, 14879, type(uint256).max);
        handler.a_swapRebalanceRestore(3575, true, 40, 62);
        handler.a_jitSwapRebalanceRestore(931322574615478515625, 4698, 72456190474149520785912282443759948082302381293772514510797792967538791201983, true, 1e21);
    }

    function _jitOnly(string memory tag, uint256 l) internal {
        uint256 snap = vm.snapshotState();
        _deepPrefix();
        uint256 v0 = handler.violations();
        int256 p0 = handler.advPnL();
        uint256 c0 = handler.advRebalanceCap();
        handler.a_jitSwapRebalanceRestore(115792089237316195423570985008687907853269984665640564039457583999854662690825, 464588464371208956048505, l, true, 13757748);
        console2.log(tag, l);
        console2.log("  adv profit"); console2.logInt(handler.advPnL() - p0);
        console2.log("  cap", handler.advRebalanceCap() - c0, "new violations", handler.violations() - v0);
        if (handler.violations() > v0) console2.log("  ", handler.firstViolation(), handler.violationA(), handler.violationB());
        vm.revertToState(snap);
    }

    function test_deepBreak_jitOnly_scaling() public {
        _jitOnly("fuzz L (bounded from 2370475139)", 2370475139);
        _jitOnly("L=1e17", 1e17 - 1e15 + 0); // bound keeps in-range values
        _jitOnly("L=1e18", 1e18);
        _jitOnly("L=1e19", 1e19);
        uint256 snap = vm.snapshotState();
        _deepPrefix();
        int256 p0 = handler.advPnL();
        vm.recordLogs();
        handler.a_rebalanceBackrun(1);
        console2.log("clean baseline (vault1) profit"); console2.logInt(handler.advPnL() - p0);
        _swaps();
        vm.revertToState(snap);
        snap = vm.snapshotState();
        _deepPrefix();
        p0 = handler.advPnL();
        vm.recordLogs();
        handler.a_jitSwapRebalanceRestore(115792089237316195423570985008687907853269984665640564039457583999854662690825, 464588464371208956048505, 2370475139, true, 13757748);
        console2.log("JIT case profit"); console2.logInt(handler.advPnL() - p0);
        _swaps();
        vm.revertToState(snap);
    }
    function _swaps() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics.length > 2
                && logs[i].topics[0] == keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)")) {
                (int128 d0, int128 d1,,, int24 tick,) = abi.decode(logs[i].data, (int128, int128, uint160, uint128, int24, uint24));
                address sender = address(uint160(uint256(logs[i].topics[2])));
                console2.log("   swap by", sender == address(wings1) ? "VAULT1" : sender == address(wings0) ? "VAULT0" : sender == address(handler.adv()) ? "ADV" : "other", vm.toString(tick));
                console2.logInt(d0); console2.logInt(d1);
            }
        }
    }
}
