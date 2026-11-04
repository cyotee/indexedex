// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {FSInvHandler} from "./FSInvHandler.sol";
import {FSInvSuite} from "./FSInvBase.sol";

interface IFSVaultView { function deployedReserve() external view returns (uint256, uint256); }

/// Hookless V4 FullSpread vault, shallow pool (vault ~45% of active liquidity), 20% sleeve.
contract FSInvHooklessTest is Acceptance, FSInvSuite {
    uint256 constant CAP = 1e27;

    function _extLiquidity() internal pure virtual returns (uint128) { return 1_000e18; }
    function _feeTier() internal pure virtual returns (uint24) { return 3_000; }
    function _vaultAddr() internal view override returns (address) { return address(vault); }
    function _metricsPath() internal view virtual override returns (string memory) { return "cache_audit/p4fs_hookless.csv"; }

    function setUp() public virtual override {
        HBase.setUp();
        IERC20 a = IERC20(address(new ERC20PermitMintableStub("Pair A", "A", 18, address(this), 1e32)));
        IERC20 b = IERC20(address(new ERC20PermitMintableStub("Pair B", "B", 18, address(this), 1e32)));
        bool ordered = address(a) < address(b);
        token0 = ordered ? a : b; token1 = ordered ? b : a;
        unit0 = 1e18; unit1 = 1e18;
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), _feeTier(), _tickSpacing(), IHooks(address(0)));
        poolManager.initialize(poolKey, uint160(1 << 96));
        _seedPool(_extLiquidity());
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        _bootstrap();
        (int24 lo, int24 hi, bytes32 salt) = _findPosition(vm.getRecordedLogs(), address(poolManager), address(vault));
        // capBps: 0.30% LP fee + 0.50% composition impact bound + slack
        handler = new FSInvHandler(poolManager, poolKey, address(vault), token0, token1, lo, hi, salt, 100, address(this));
        token0.approve(address(handler), type(uint256).max);
        token1.approve(address(handler), type(uint256).max);
        handler.setup_fund(CAP);
        for (uint256 i; i < 4; ++i) handler.setup_seedShares(i, 400e18);
        _wireHandler();
        _resetMetrics();
    }

    // ---------------- sanity: the invariant catches known bugs when un-quarantined ----------------
    function _invariantFails() internal returns (bool caught) {
        try this.invariant_all() {} catch { caught = true; }
    }

    /// fs-blocked-entry-spot-mint (k=4, single-sided blocked deposit)
    function test_sanity_catchesKnownBlockedEntry() public {
        assertFalse(_invariantFails(), "clean state must pass");
        handler.known_movedBlockedEntry(2000, 800e18, 0);
        handler.summary();
        assertGt(handler.actorGainViolations(), 0, "known blocked-entry bug not detected by I1");
        assertTrue(_invariantFails(), "invariant_all must fail");
    }

    /// fs-blocked-entry-spot-mint (exact-out mint variant)
    function test_sanity_catchesKnownBlockedMint() public {
        handler.known_movedBlockedEntry(2000, IERC20(address(vault)).totalSupply() * 30 / 100, 1);
        handler.summary();
        assertGt(handler.actorGainViolations(), 0, "known blocked-mint bug not detected");
        assertTrue(_invariantFails(), "invariant_all must fail");
    }

    /// fs-blocked-exit-sleeve-amgm (r = 1.3, blocked zap-out)
    function test_sanity_catchesKnownBlockedExit() public {
        handler.known_movedBlockedExit(1300, 5_000);
        handler.summary();
        assertGt(handler.actorGainViolations() + handler.navViolations(), 0, "known blocked-exit bug not detected");
        assertTrue(_invariantFails(), "invariant_all must fail");
    }

    /// control: the same harness path with no price move must NOT trip (no false positive)
    function test_sanity_controlNoMove() public {
        handler.known_movedBlockedEntry(1000, 800e18, 0);
        handler.known_movedBlockedExit(1000, 5_000);
        handler.summary();
        assertFalse(_invariantFails(), "control must pass");
    }

    /// smoke: every fuzzed selector once with mid-range inputs (non-vacuity of each path)
    function test_smoke_allSelectors() public {
        handler.h_depositSingle(0, true, 50e18);
        handler.h_depositSingle(1, false, 50e18);
        handler.h_depositDual(2, 100e18, 0);
        handler.h_redeemSingle(0, true, 2_000);
        handler.h_exitDual(1, 2_000);
        handler.h_swapIn(2, true, 10e18);
        handler.h_swapOut(0, false, false, 1e17);
        handler.h_swapOut(1, false, true, 5e16);
        handler.h_swapOut(0, true, true, 1e15);
        handler.h_syDeposit(1, true, 10e18);
        handler.h_syRedeem(1, false, 1_000);
        handler.b_deposit(2, true, 20e18);
        handler.b_redeem(0, false, 1_000);
        handler.b_mint(1, true, 100);
        handler.b_exitDual(2, 1_000);
        handler.b_depositDual(0, 50e18);
        handler.keeper_rebalance();
        handler.warp(3600);
        handler.market_noise(1050);
        handler.a_donate(true, 5e18);
        handler.a_poolDonate(1e18, 1e18);
        handler.a_pretransferDeposit(true, 10e18, 1e18);
        handler.a_pretransferRedeem(false, 1_000);
        handler.a_donate(false, 1e18);
        handler.a_sweepSwapOut(false, 1e17, 500);
        handler.a_sweepSwapOut(true, 5e16, 1_000);
        handler.a_movedIdleOp(1200, 0, true, 20e18);
        handler.a_movedIdleOp(800, 2, false, 2_000);
        handler.a_movedIdleOp(1300, 5, true, 0);
        handler.summary();
        this.invariant_all();
    }
    // ---------------- repro of fuzzer counterexamples ----------------
    function _logState(string memory tag, address a) internal view {
        (uint256 b0, uint256 b1) = handler.backing();
        (uint256 d0, uint256 d1) = IFSVaultView(address(vault)).deployedReserve();
        console2.log(tag);
        console2.log("  free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        console2.log("  deployed0/deployed1", d0, d1);
        console2.log("  backing0/backing1", b0, b1);
        console2.log("  NAV / S", handler.nav(), IERC20(address(vault)).totalSupply());
        console2.log("  actor t0/t1/shares", token0.balanceOf(a), token1.balanceOf(a), IERC20(address(vault)).balanceOf(a));
        console2.log("  actor value", handler.valueOf(a));
    }

    function test_repro_blockedDualExitAtP0() public {
        address a = handler.actorAt(0);
        uint256 s = IERC20(address(vault)).balanceOf(a) * 4819 / 10_000;
        (bool f, uint256 a0, uint256 a1, uint256 t) = handler.dualAmounts(s);
        console2.log("s target / t / found", s, t, f ? 1 : 0);
        console2.log("a0/a1", a0, a1);
        _logState("BEFORE", a);
        uint256 v0 = handler.valueOf(a);
        handler.b_exitDual(0, 4819);
        _logState("AFTER", a);
        console2.log("actor delta");
        console2.logInt(int256(handler.valueOf(a)) - int256(v0));
        handler.summary();
    }

    function test_repro_idleRedeemGain() public {
        handler.b_exitDual(12180, 4819);
        handler.a_poolDonate(1143537364040952959589643157903850811047540831521, 7626);
        handler.a_pretransferDeposit(false, 1050000000000000000, 54242578526);
        handler.b_mint(13882, false, 3334);
        handler.b_depositDual(20000000000000000, 19040);
        address a = handler.actorAt(1);
        _logState("BEFORE idle redeem", a);
        (uint256 e0, uint256 e1) = handler.earned();
        console2.log("  earned0/earned1", e0, e1);
        uint256 v0 = handler.valueOf(a);
        handler.h_redeemSingle(5, true, 18727);
        _logState("AFTER idle redeem (+actor restore)", a);
        console2.log("redeemer delta");
        console2.logInt(int256(handler.valueOf(a)) - int256(v0));
        handler.summary();
    }

    function test_probe_exactOutSwap() public {
        uint256[6] memory amts = [uint256(1e12), 1e15, 1e16, 1e17, 1e18, 5e18];
        for (uint256 d; d < 2; ++d) {
            for (uint256 i; i < amts.length; ++i) {
                (IERC20 a, IERC20 b) = d == 0 ? (token0, token1) : (token1, token0);
                uint256 snap = vm.snapshotState();
                uint256 pv;
                try IStandardExchangeProxy(address(vault)).previewExchangeOut(a, b, amts[i]) returns (uint256 x) { pv = x; } catch {}
                try IStandardExchangeProxy(address(vault)).exchangeOut(a, type(uint128).max, b, amts[i], address(this), false, block.timestamp) returns (uint256 used) {
                    console2.log("OK dir/amt/used", d, amts[i], used);
                    console2.log("   preview", pv);
                } catch (bytes memory e) {
                    console2.log("REVERT dir/amt", d, amts[i]);
                    console2.logBytes(e);
                }
                vm.revertToState(snap);
            }
        }// compare: exact-in direct swap works
        uint256 out = IStandardExchangeProxy(address(vault)).exchangeIn(token0, 1e18, token1, 0, address(this), false, block.timestamp);
        console2.log("exact-in 1e18 t0->t1 out", out);
    }

    /// NEW-variant probe: no price move. Blocked zap-out to token0 at the fair price drains free token0
    /// (book becomes token0-scarce), then a blocked single-sided token0 deposit is priced by sqrt(xy)
    /// growth of the imbalanced book. Measures the attacker's net over the round trip at P0.
    function test_variant_blockedRoundTripAtP0() public {
        address a = handler.actorAt(3);
        uint16[4] memory fr = [uint16(2_500), 5_000, 7_500, 10_000];
        for (uint256 i; i < fr.length; ++i) {
            uint256 snap = vm.snapshotState();
            uint256 v0 = handler.valueOf(a);
            uint256 t0b = token0.balanceOf(a);
            handler.b_redeem(3, true, fr[i]);
            uint256 got = token0.balanceOf(a) - t0b;
            int256 afterRedeem = int256(handler.valueOf(a)) - int256(v0);
            handler.b_deposit(3, true, got);
            int256 net = int256(handler.valueOf(a)) - int256(v0);
            console2.log("frac bps / token0 out-in", fr[i], got);
            console2.log("  delta after blocked redeem / after blocked re-deposit (net):");
            console2.logInt(afterRedeem);
            console2.logInt(net);
            vm.revertToState(snap);
        }
    }

    /// NEW-variant PoC: repeated blocked round trips at the fair price (no price move, no TWAP deviation).
    function test_variant_loopAtP0() public {
        address a = handler.actorAt(3);
        handler.h_depositDual(3, type(uint256).max, 0); // fair idle dual deposit, bound -> nav/5
        uint256 v0 = handler.valueOf(a);
        uint256 lp0 = handler.valueOf(address(this));
        uint256 h0 = handler.valueOf(handler.actorAt(0)) + handler.valueOf(handler.actorAt(1)) + handler.valueOf(handler.actorAt(2));
        console2.log("attacker shares / supply", IERC20(address(vault)).balanceOf(a), IERC20(address(vault)).totalSupply());
        for (uint256 i; i < 10; ++i) {
            uint256 t0b = token0.balanceOf(a);
            // size the zap-out to ~80% of the free token0 sleeve
            uint256 sh = token0.balanceOf(address(vault)) * 8 / 10 * IERC20(address(vault)).totalSupply() / handler.nav();
            uint256 fr = sh * 10_000 / IERC20(address(vault)).balanceOf(a);
            handler.b_redeem(3, true, fr > 10_000 ? 10_000 : fr);
            uint256 got = token0.balanceOf(a) - t0b;
            if (got == 0) break;
            handler.b_deposit(3, true, got);
            console2.log("round", i);
            console2.logInt(int256(handler.valueOf(a)) - int256(v0));
        }
        int256 atk = int256(handler.valueOf(a)) - int256(v0);
        int256 lp = int256(handler.valueOf(address(this))) - int256(lp0);
        int256 hon = int256(handler.valueOf(handler.actorAt(0)) + handler.valueOf(handler.actorAt(1)) + handler.valueOf(handler.actorAt(2))) - int256(h0);
        // realize: idle dual exit of everything at the fair price
        uint256 vr = handler.valueOf(a);
        handler.h_exitDual(3, 10_000);
        console2.log("ATTACKER NET (valued at P0) / realized-exit delta");
        console2.logInt(atk);
        console2.logInt(int256(handler.valueOf(a)) - int256(vr));
        console2.log("bootstrap LP delta / honest actors delta");
        console2.logInt(lp);
        console2.logInt(hon);
        console2.log("NAV", handler.nav());
        assertGt(atk, 0, "round trips profitable at P0");
    }

    /// NEW-variant probe (forced dump): an honest in-session single-sided token0 deposit leaves the sleeve
    /// token0-heavy; attacker pushes token0 cheap (own unlock), calls the permissionless rebalance, which sells
    /// token0 at the displaced spot (25 bps impact bound is relative to the displaced price), then restores.
    function test_variant_forcedDump() public {
        handler.b_deposit(0, true, type(uint256).max); // honest integrator, bound -> nav/10 token0
        handler.setQuarantineJit(false);
        address a = handler.actorAt(3);
        uint16[7] memory ms = [uint16(998), 995, 990, 980, 950, 900, 800];
        console2.log("fee tier", uint256(_feeTier()));
        console2.log("free0/free1", token0.balanceOf(address(vault)), token1.balanceOf(address(vault)));
        for (uint256 i; i < ms.length; ++i) {
            uint256 snap = vm.snapshotState();
            uint256 v0 = handler.valueOf(a);
            uint256 l0 = handler.valueOf(address(this));
            uint256 n0 = handler.nav();
            uint256 S0 = IERC20(address(vault)).totalSupply();
            handler.a_movedIdleOp(ms[i], 5, true, 0);
            console2.log("sqrtP multiplier (permille)", ms[i]);
            console2.log("  attacker delta / LP0 delta / NAV-per-share delta x1e18");
            console2.logInt(int256(handler.valueOf(a)) - int256(v0));
            console2.logInt(int256(handler.valueOf(address(this))) - int256(l0));
            console2.logInt(int256(handler.nav() * 1e18 / IERC20(address(vault)).totalSupply()) - int256(n0 * 1e18 / S0));
            vm.revertToState(snap);
        }
    }

    function test_repro_500redeem() public {
        handler.a_movedIdleOp(100, 5, false, 478901809);
        handler.a_pretransferDeposit(true, 39, 20000000000000000);
        address a = handler.actorAt(0);
        _logState("BEFORE idle redeem", a);
        handler.setDebug(true);
        uint256 v0 = handler.valueOf(a);
        handler.h_redeemSingle(50000000000000000000, false, 998);
        _logState("AFTER", a);
        console2.log("redeemer delta");
        console2.logInt(int256(handler.valueOf(a)) - int256(v0));
    }


    // ---------------- AUDIT: strict-campaign counterexample (BSE at P0, no price move) ----------------
    function test_repro_bseP0_strict() public {
        address a = handler.actorAt(0);
        for (uint256 k; k < 2; ++k) {
            uint256 snap = vm.snapshotState();
            address a2 = handler.actorAt(2);
            uint256 a2v = handler.valueOf(a2);
            // shrunk prefix: actor 2 blocked single-sided token1 deposit (amt 998 is below the bound min -> wraps to ~nav/10)
            if (k == 1) handler.b_deposit(13882, false, 998);
            console2.log("  prefix actor2 delta @P0 (prefix deposit)");
            console2.logInt(int256(handler.valueOf(a2)) - int256(a2v));
            uint256 v0 = token0.balanceOf(a) + token1.balanceOf(a);
            uint256 sh0 = IERC20(address(vault)).balanceOf(a);
            uint256 fair0 = handler.valueOf(a) - v0; // fair value of pre-existing shares
            uint256 lp0v = handler.valueOf(address(this));
            handler.b_deposit(8e20, true, 9910); // actor 0: blocked single-sided token0 deposit at P0, bound -> nav/10
            console2.log(k == 0 ? "== blocked t0 deposit alone" : "== after a blocked ~nav/10 token1 deposit by actor 2");
            console2.log("  token0 paid", v0 - (token0.balanceOf(a) + token1.balanceOf(a)));
            console2.log("  shares minted", IERC20(address(vault)).balanceOf(a) - sh0);
            console2.log("  mark gain @P0 (I1 dv)");
            console2.logInt(int256(handler.valueOf(a)) - int256(v0 + fair0));
            // realize: idle dual exit of ALL shares, compare to (tokens before + fair value of old shares)
            uint256 before = token0.balanceOf(a) + token1.balanceOf(a);
            handler.h_exitDual(0, 10_000);
            int256 realized = int256(token0.balanceOf(a) + token1.balanceOf(a)) - int256(before);
            console2.log("  REALIZED NET (exit proceeds - token0 paid - fair value of old shares)");
            console2.logInt(realized - int256(v0 - before) - int256(fair0));
            console2.log("  bootstrap LP value delta");
            console2.logInt(int256(handler.valueOf(address(this))) - int256(lp0v));
            console2.log("  shares left", IERC20(address(vault)).balanceOf(a));
            console2.log("  actor2 total delta @P0 (if the same entity did both legs, add to REALIZED NET)");
            console2.logInt(int256(handler.valueOf(a2)) - int256(a2v));
            vm.revertToState(snap);
        }
    }

    /// Q-campaign counterexample (hookless 0.30%): single-sided pretransfer redeem after blocked mint + keeper rebalance
    function _qPrefix() internal {
        handler.setQuarantineBseP0(true);
        handler.setQuarantineDump(true);
        handler.b_exitDual(2065252904272510825712423928955245806766048883286981491469, 14721522656849545935616201372532653233149530638604);
        handler.a_poolDonate(1080770189213751749439456490231854101881024323088, 30254818290321471820);
        handler.h_swapIn(2, false, 243584);
        handler.b_redeem(5750, false, 3626755438);
        handler.h_depositDual(13882, 30, 14535);
        handler.b_mint(813096946, false, 7500);
        handler.keeper_rebalance();
    }

    function test_repro_qPretransferRedeem() public {
        _qPrefix();
        address a = handler.actorAt(3);
        _logState("BEFORE", a);
        uint256 snap = vm.snapshotState();
        for (uint256 k; k < 3; ++k) {
            uint256 v0 = handler.valueOf(a);
            uint256 l0 = handler.valueOf(address(this));
            if (k == 0) { handler.setDebug(true); handler.a_pretransferRedeem(true, 1e27); handler.setDebug(false); }
            else if (k == 1) handler.h_redeemSingle(3, true, 1e27); // same shares, plain idle redeem
            else handler.h_exitDual(3, 1e27);                      // same shares, pro-rata dual exit (reference)
            console2.log(k == 0 ? "== pretransfer redeem -> t0" : (k == 1 ? "== plain idle redeem -> t0" : "== idle dual exit"));
            _logState("  AFTER", a);
            console2.log("  attacker delta @P0 (incl. own restore) / LP0 delta");
            console2.logInt(int256(handler.valueOf(a)) - int256(v0));
            console2.logInt(int256(handler.valueOf(address(this))) - int256(l0));
            vm.revertToState(snap);
        }
    }

    /// Q-campaign counterexample (0.05% tier): blocked dual deposit then idle SY single-sided redeem
    function test_repro_q500SyRedeem() public {
        handler.b_depositDual(1003, 32957);
        address a = handler.actorAt(995 % 4);
        _logState("BEFORE", a);
        uint256 v0 = handler.valueOf(a);
        uint256 l0 = handler.valueOf(address(this));
        uint256 nps0 = handler.nav() * 1e18 / IERC20(address(vault)).totalSupply();
        handler.setDebug(true);
        handler.h_syRedeem(995, true, 8390);
        handler.setDebug(false);
        _logState("AFTER", a);
        console2.log("redeemer delta (incl. own restore) / LP0 delta / NAV-per-share delta x1e18");
        console2.logInt(int256(handler.valueOf(a)) - int256(v0));
        console2.logInt(int256(handler.valueOf(address(this))) - int256(l0));
        console2.logInt(int256(handler.nav() * 1e18 / IERC20(address(vault)).totalSupply()) - int256(nps0));
    }

    function test_repro_donateThenBlockedDeposit() public {
        address a = handler.actorAt(1);
        handler.a_donate(true, type(uint256).max); // bound -> nav/20+1 of token0
        _logState("AFTER DONATE", a);
        uint256 v0 = handler.valueOf(a);
        handler.b_deposit(1, false, 30254818290321471820);
        _logState("AFTER BLOCKED DEPOSIT token1", a);
        console2.log("depositor delta");
        console2.logInt(int256(handler.valueOf(a)) - int256(v0));
        handler.summary();
    }
}


/// medium campaign
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract FSInvHooklessMediumTest is FSInvHooklessTest {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless_medium.csv"; }
}

/// same vault on a 0.05% fee tier pool (tick spacing 10)
contract FSInvHookless500Test is FSInvHooklessTest {
    function _feeTier() internal pure override returns (uint24) { return 500; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
    function _metricsPath() internal view virtual override returns (string memory) { return "cache_audit/p4fs_hookless500.csv"; }
}

/// medium campaign, 0.05% fee tier
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract FSInvHookless500MediumTest is FSInvHookless500Test {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless500_medium.csv"; }
}

/// deep campaigns (not run in validation)
/// forge-config: audit.invariant.runs = 256
/// forge-config: audit.invariant.depth = 100
contract FSInvHooklessDeepTest is FSInvHooklessTest {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless_deep.csv"; }
}

/// forge-config: audit.invariant.runs = 256
/// forge-config: audit.invariant.depth = 100
contract FSInvHookless500DeepTest is FSInvHookless500Test {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless500_deep.csv"; }
}

/// medium campaign with the three NON-confirmed classes (BSE-at-P0, dump-at-external-spot, self-JIT redeploy) quarantined
/// by opt-in, so the remaining surface keeps being fuzzed past the first such hit. Strict = FSInvHooklessMediumTest.
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract FSInvHooklessQMediumTest is FSInvHooklessTest {
    function setUp() public override {
        super.setUp();
        handler.setQuarantineBseP0(true);
        handler.setQuarantineDump(true);
        handler.setQuarantineSelfJit(true);
    }
    function _metricsPath() internal view virtual override returns (string memory) { return "cache_audit/p4fs_hookless_qmedium.csv"; }
}

/// medium campaign with the three NON-confirmed classes (BSE-at-P0, dump-at-external-spot, self-JIT redeploy) quarantined
/// by opt-in, so the remaining surface keeps being fuzzed past the first such hit. Strict = FSInvHookless500MediumTest.
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract FSInvHookless500QMediumTest is FSInvHookless500Test {
    function setUp() public override {
        super.setUp();
        handler.setQuarantineBseP0(true);
        handler.setQuarantineDump(true);
        handler.setQuarantineSelfJit(true);
    }
    function _metricsPath() internal view virtual override returns (string memory) { return "cache_audit/p4fs_hookless500_qmedium.csv"; }
}

/// deep campaign, same opt-in quarantine as FSInvHooklessQMediumTest (not run in validation)
/// forge-config: audit.invariant.runs = 256
/// forge-config: audit.invariant.depth = 100
contract FSInvHooklessQDeepTest is FSInvHooklessQMediumTest {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless_qdeep.csv"; }
}

/// deep campaign, same opt-in quarantine as FSInvHookless500QMediumTest (not run in validation)
/// forge-config: audit.invariant.runs = 256
/// forge-config: audit.invariant.depth = 100
contract FSInvHookless500QDeepTest is FSInvHookless500QMediumTest {
    function _metricsPath() internal view override returns (string memory) { return "cache_audit/p4fs_hookless500_qdeep.csv"; }
}
