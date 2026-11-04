// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook as TB_Weighted} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TB_CP} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {TestBase_UniswapV4DualSEBCPHook as TB_Dual} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TB_Orbital} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TB_Curve} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TB_Bal} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

import {HookValueHandler} from "./HookValueHandler.sol";

/// @notice p4-hooks invariant suite mixin. Invariants (value level, fair price = 1 per underlying):
///  INV-1 noCycleProfit      every closed cycle (honest round trip or adversarial manipulate/act/restore/unwind,
///                           consolidated back to the start token) has P&L <= rounding tol (+2% of any gift).
///  INV-2 quoteBound         SE swaps: delivered == returned, returned <= preview, returned >= preview - tol;
///                           exact-out: amountIn <= preview, delivered == amountOut, net debit == returned.
///  INV-3 exitPaysPreview    joins/exits (prop, single, unbalanced): result within tol of preview, never 0 when preview > 0.
///  INV-4 valueConservation  per action: value in from outside == actor delta + hook TVL delta (rated/face consistency).
///  INV-5 passiveLpValue     a passive LP's fair value per share never falls more than 5 bp below its seed value.
///  INV-5b passiveLpNoAdvDrop no single adversarial closed cycle lowers passive per-share value by > 1 ppm unless it
///                           minted a protocol fee / paid an SE fee (INV-5 alone can be masked by earlier yield/fees).
///  INV-6 bankRunFair        sequential exit of all holders pays every holder the same value per share; all exits succeed.
///  non-vacuity              >= 60% of handler calls succeed AND cycles / quote / exit / lpAdv checks actually ran
///                           (logged per selector in afterInvariant, with sweep-probe and skipped-preview counters).
abstract contract P4Suite is Test {
    HookValueHandler internal handler;

    function _feeAdmin() internal view virtual returns (address owner_, address oracle_);

    /// QUARANTINE Q-SEFEE: SE dilution (usage) fee set to 1 wei on every buffered leg's SE. With a non-zero SE fee,
    /// joins by others make passive LPs pay the SE dilution fee (P4DualFeeLeak.t.sol), which would trip INV-5.
    function _seFeeOff(address[] memory ses) internal {
        (address o, address fo) = _feeAdmin();
        for (uint256 i; i < ses.length; ++i) {
            if (ses[i] == address(0)) continue;
            vm.prank(o);
            IVaultFeeOracleManager(fo).setUsageFeeOfVault(ses[i], 1);
        }
    }

    /// QUARANTINE hook: families where a_joinUnbalanced trivially re-triggers a finding confirmed by p4 (orbital).
    function _excludeUnbalanced() internal pure virtual returns (bool) {
        return false;
    }

    function _install(HookValueHandler.Config memory c) internal {
        handler = new HookValueHandler(c);
        handler.seed();
        uint256 cnt = (c.allowYield ? 16 : 14) - (_excludeUnbalanced() ? 1 : 0);
        bytes4[] memory sel = new bytes4[](cnt);
        uint256 x;
        sel[x++] = handler.h_joinProp.selector;
        sel[x++] = handler.h_exitProp.selector;
        sel[x++] = handler.h_joinSingle.selector;
        sel[x++] = handler.h_exitSingle.selector;
        sel[x++] = handler.h_swapRT.selector;
        sel[x++] = handler.h_warp.selector;
        sel[x++] = handler.a_roundTrip.selector;
        sel[x++] = handler.a_manipulate.selector;
        sel[x++] = handler.a_unlockSandwich.selector;
        sel[x++] = handler.a_donateThenClaim.selector;
        sel[x++] = handler.a_sweep.selector;
        sel[x++] = handler.a_exactOutRefund.selector;
        sel[x++] = handler.c_bankRun.selector;
        if (!_excludeUnbalanced()) sel[x++] = handler.a_joinUnbalanced.selector;
        if (c.allowYield) {
            sel[x++] = handler.h_yield.selector;
            sel[x++] = handler.a_yieldThenAct.selector;
        }
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sel}));
    }

    function _keysFrom(PoolKey memory base, SimpleMintableERC20[] memory toks) internal pure returns (PoolKey[] memory ks) {
        uint256 n = toks.length;
        ks = new PoolKey[](n * (n - 1) / 2);
        uint256 x;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                (address a, address b) = address(toks[i]) < address(toks[j])
                    ? (address(toks[i]), address(toks[j]))
                    : (address(toks[j]), address(toks[i]));
                ks[x++] = PoolKey(Currency.wrap(a), Currency.wrap(b), base.fee, base.tickSpacing, base.hooks);
            }
        }
    }

    function _ones(uint256 n) internal pure returns (uint256[] memory p) {
        p = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            p[i] = 1e18;
        }
    }

    function invariant_noCycleProfit() public view {
        assertEq(handler.cycleBreaks(), 0, handler.firstCycleBreak());
    }

    function invariant_quoteBound() public view {
        assertEq(handler.quoteBreaks(), 0, handler.firstQuoteBreak());
    }

    function invariant_exitPaysPreview() public view {
        assertEq(handler.exitBreaks(), 0, handler.firstExitBreak());
    }

    function invariant_valueConservation() public view {
        assertEq(handler.consBreaks(), 0, handler.firstConsBreak());
    }

    function invariant_passiveLpValue() public view {
        assertEq(handler.lpBreaks(), 0, handler.firstLpBreak());
    }

    function invariant_passiveLpNoAdvDrop() public view {
        assertEq(handler.lpAdvBreaks(), 0, handler.firstLpAdvBreak());
    }

    function invariant_bankRunFair() public view {
        assertEq(handler.bankRunBreaks(), 0, handler.firstBankRunBreak());
    }

    function afterInvariant() public {
        handler.checkBankRun();
        handler.logStats();
        handler.appendStats(string.concat("p4hooks_stats_", handler.family(), ".csv"));
        (uint256 ok, uint256 tried) = handler.totals();
        assertEq(handler.bankRunBreaks(), 0, handler.firstBankRunBreak());
        // per-run gate only once a run is long enough to be meaningful (medium/deep campaigns: depth >= 20)
        if (tried >= 20) {
            assertGe(ok * 100, tried * 60, "non-vacuity: >= 60% of handler calls succeed");
            assertGt(handler.cycles(), 0, "non-vacuity: no closed cycle evaluated");
            assertGt(handler.quoteChecks(), 0, "non-vacuity: no quote check ran");
            assertGt(handler.exitChecks(), 0, "non-vacuity: no exit check ran");
            assertGt(handler.lpAdvChecks(), 0, "non-vacuity: no adversarial LP check ran");
        }
    }

    function _diagLog(string memory tag) internal view {
        console2.log(tag);
        console2.log("   passivePerShare", handler.passivePerShare());
        console2.log("   hookTVL        ", handler.hookTVL());
        console2.log("   feeTo SE value ", handler.feeToSeValue());
        console2.log("   worstCycle");
        console2.logInt(handler.worstCycle());
    }

    function test_diag_fresh() public {
        _diagLog("fresh");
        handler.a_joinUnbalanced(0, 100e18, 30);
        _diagLog("after joinUnbalanced k=0 100/30 -> exitSingle k");
        handler.a_roundTrip(0, 1, 25_000e18, 0);
        _diagLog("after SE roundTrip 0->1->0 25k");
        handler.a_manipulate(0, 0, 0, 25_000e18, 1_000e18, 2);
        _diagLog("after manipulate kind2 (PM move 25k, SE swap, restore)");
        handler.a_manipulate(0, 0, 1, 25_000e18, 1_000e18, 0);
        _diagLog("after manipulate kind0 (PM move 25k, joinSingle, restore, exit)");
        handler.logStats();
    }

    /// h_exitSingle failure census across share sizes (diag for the ~40% campaign failure rate on some families).
    function test_diag_exitSingleSizes() public {
        uint256[6] memory ss = [uint256(1), 1e3, 1e9, 1e12, 1e15, 1e30];
        for (uint256 z; z < 6; ++z) {
            for (uint256 k; k < 4; ++k) {
                uint256 a0 = handler.successes(3);
                handler.h_exitSingle(z, k, ss[z]);
                console2.log("exitSingle s / k / ok", ss[z], k, handler.successes(3) - a0);
                console2.logBytes4(handler.lastRevert(3));
            }
        }
    }

    /// fixed-seed pass over every action, then report (debug aid + non-vacuity smoke).
    function test_p4_smoke() public {
        for (uint256 r; r < 3; ++r) {
            handler.h_joinProp(r, 10e18 + r);
            handler.h_joinSingle(r, r, 5e18);
            handler.h_swapRT(r, 0, 1, 3e18, r * 5);
            handler.a_roundTrip(r, r + 1, 50e18, r * 7);
            handler.a_manipulate(r, r, r, 1e24, 1e24, r);
            handler.a_manipulate(r, r + 1, r, 1e24, 1e24, r + 3);
            handler.a_unlockSandwich(r, r, r, 1e24, 1e24, r);
            handler.a_donateThenClaim(r, 1e18, r + 1, r);
            handler.a_sweep(r);
            handler.a_exactOutRefund(r, r + 1, 1e18, 50);
            handler.a_joinUnbalanced(r, 1e20, 30);
            handler.h_yield(r, 1e18);
            handler.a_yieldThenAct(r, 1e18, r, r + 1, 1e20, r);
            handler.h_exitSingle(r, r + 1, 1e18);
            handler.h_exitProp(r, 1e30);
            handler.h_warp(1 days);
            handler.c_bankRun();
        }
        handler.checkBankRun();
        handler.logStats();
    }
}

// =====================================================================================================
// Families
// =====================================================================================================

/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract P4_Weighted is TB_Weighted, P4Suite {
    /// Regression for a HARNESS artifact found in the first medium run (not a protocol bug): call 1 could not unwind
    /// token1 back into x (weighted max-in ratio), leaving the pool off-fair; call 2 then harvested a legit arbitrage.
    /// Fixed by chunked unwind + mandatory cycle closure (_consolidate reverts "unclosed"). Cumulative P&L was -351.
    function test_repro_weighted_unlockSandwich() public {
        handler.dumpState("start");
        handler.a_unlockSandwich(25000000000000000000000, type(uint256).max, 10000, 1200000000000000000, 60, 14);
        handler.dumpState("after call1");
        handler.logStats();
        handler.a_unlockSandwich(16775, 1e20, 101361440061826139196945, 151713837080599934888819, 16657, 2233729034);
        handler.dumpState("after call2");
        handler.logStats();
    }

    function test_repro_weighted_unlockSandwich_call2only() public {
        handler.a_unlockSandwich(16775, 1e20, 101361440061826139196945, 151713837080599934888819, 16657, 2233729034);
        handler.dumpState("after call2 only");
        handler.logStats();
    }

    function test_repro_weighted_manipulateNoUnlock() public {
        // same shape outside the unlock: join prop, PM move, exit single, restore (a_manipulate kind 4)
        handler.a_manipulate(16775, 1e20, 101361440061826139196945, 151713837080599934888819, 16657, 4);
        handler.dumpState("after manipulate kind4");
        handler.logStats();
    }

    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function setUp() public override {
        super.setUp();
        _setDexFee(3e15);
        _setUsageFee(1e17);
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.ses = new address[](2);
        c.ses[0] = se0;
        c.vaults = new address[](2);
        c.vaults[0] = address(vault0);
        c.prices = _ones(2);
        c.router = swapRouter;
        c.pm = pm;
        c.keys = _keysFrom(poolKey01, c.tokens);
        c.feeTo = address(feeCollector);
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = "weighted";
        _seFeeOff(c.ses);
        _install(c);
    }
}

/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract P4_CPSingle is TB_CP, P4Suite {
    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function setUp() public override {
        super.setUp();
        _initPool();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, 3e15);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 1e17);
        vm.stopPrank();
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = rawToken;
        c.tokens[1] = pairToken;
        c.ses = new address[](2);
        c.ses[1] = se;
        c.vaults = new address[](2);
        c.vaults[1] = address(pairProtocolVault);
        c.prices = _ones(2);
        c.router = new WrapperExactOutRouter(pm);
        c.pm = pm;
        c.keys = new PoolKey[](1);
        c.keys[0] = poolKey;
        c.feeTo = address(feeCollector);
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = "cp-single";
        _seFeeOff(c.ses);
        _install(c);
    }
}

/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract P4_CPDual is TB_Dual, P4Suite {
    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function test_repro_dual_joinUnbalanced() public {
        handler.dumpState("before");
        console2.log("feeTo SE value", handler.feeToSeValue());
        handler.a_joinUnbalanced(2233729034, 46288, 1e15);
        handler.dumpState("after");
        console2.log("feeTo SE value", handler.feeToSeValue());
        handler.logStats();
    }

    function setUp() public override {
        super.setUp();
        _initPool();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, 3e15);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 1e17);
        vm.stopPrank();
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = tokenA;
        c.tokens[1] = tokenB;
        c.ses = new address[](2);
        c.ses[0] = seA;
        c.ses[1] = seB;
        c.vaults = new address[](2);
        c.vaults[0] = address(vaultA);
        c.vaults[1] = address(vaultB);
        c.prices = _ones(2);
        c.router = new WrapperExactOutRouter(pm);
        c.pm = pm;
        c.keys = new PoolKey[](1);
        c.keys[0] = poolKey;
        c.feeTo = address(feeCollector);
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = "cp-dual";
        _seFeeOff(c.ses);
        _install(c);
    }
}

/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// QUARANTINE: hook protocol fee disabled (usage fee 1 wei => feeOn false) -> NEW phantom protocol fee
///             (P4PhantomProtocolFee.t.sol) is not re-triggered through INV-5;
///             a_joinUnbalanced NARROWED (was: excluded) to joins at the current reserve ratio, so the joinUnbalanced
///             code path is still exercised but the NEW orbital par-valued unbalanced join (P4OrbitalUnbalanced.t.sol)
///             is not re-triggered.
contract P4_Orbital is TB_Orbital, P4Suite {

    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function test_diag_orbitalLpDrop() public {
        handler.a_manipulate(0, 0, 0, 25_000e18, 1_000e18, 2);
        handler.dumpState("after kind2");
        handler.a_manipulate(0, 0, 1, 25_000e18, 1_000e18, 0);
        handler.dumpState("after kind0");
        handler.logStats();
    }

    function setUp() public override {
        super.setUp();
        _setDexFee(3e15);
        _setUsageFee(1);
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](3);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.tokens[2] = token2;
        c.ses = new address[](3);
        c.ses[0] = se0;
        c.vaults = new address[](3);
        c.vaults[0] = address(vault0);
        c.prices = _ones(3);
        c.router = swapRouter;
        c.pm = pm;
        c.keys = new PoolKey[](3);
        c.keys[0] = poolKey01;
        c.keys[1] = poolKey12;
        c.keys[2] = poolKey02;
        c.feeTo = address(feeCollector);
        c.orbital = true;
        c.unbalancedPropOnly = true;
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = "orbital";
        _seFeeOff(c.ses);
        _install(c);
    }
}

/// QUARANTINE: SE yield (rate != 1) disabled -> rawleg-rp-lp-and-fee (1) Curve LP-domain arb not re-triggered;
///             hook protocol fee disabled (usage fee 1 wei) -> NEW phantom protocol fee not re-triggered.
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract P4_CurveQuad is TB_Curve, P4Suite {
    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function setUp() public override {
        super.setUp();
        _setDexFee(1e15);
        _setUsageFee(1);
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](4);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.tokens[2] = token2;
        c.tokens[3] = token3;
        c.ses = new address[](4);
        c.ses[0] = se0;
        c.vaults = new address[](4);
        c.vaults[0] = address(vault0);
        c.prices = _ones(4);
        c.router = swapRouter;
        c.pm = pm;
        c.keys = _keysFrom(poolKey01, c.tokens);
        c.feeTo = address(feeCollector);
        c.allowYield = false;
        c.seedEach = 100_000e18;
        c.family = "curve-quad";
        _seFeeOff(c.ses);
        _install(c);
    }

    /// yield actions are quarantined for curve; smoke must not call them.
    function test_p4_smoke_noYield() public {
        for (uint256 r; r < 3; ++r) {
            handler.h_joinProp(r, 10e18 + r);
            handler.h_joinSingle(r, r, 5e18);
            handler.h_swapRT(r, 0, 1, 3e18, r * 5);
            handler.a_roundTrip(r, r + 1, 50e18, r * 7);
            handler.a_manipulate(r, r, r, 1e24, 1e24, r);
            handler.a_unlockSandwich(r, r, r, 1e24, 1e24, r);
            handler.a_donateThenClaim(r, 1e18, r + 1, r);
            handler.a_sweep(r);
            handler.a_exactOutRefund(r, r + 1, 1e18, 50);
            handler.a_joinUnbalanced(r, 1e20, 30);
            handler.h_exitSingle(r, r + 1, 1e18);
            handler.h_exitProp(r, 1e30);
            handler.c_bankRun();
        }
        handler.logStats();
    }
}

/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
contract P4_BalancerQuad is TB_Bal, P4Suite {
    function _feeAdmin() internal view override returns (address, address) {
        return (owner, address(indexedexManager));
    }

    function setUp() public override {
        super.setUp();
        _setDexFee(1e15);
        _setUsageFee(1e17);
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](4);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.tokens[2] = token2;
        c.tokens[3] = token3;
        c.ses = new address[](4);
        c.ses[0] = se0;
        c.vaults = new address[](4);
        c.vaults[0] = address(vault0);
        c.prices = _ones(4);
        c.router = swapRouter;
        c.pm = pm;
        c.keys = _keysFrom(poolKey01, c.tokens);
        c.feeTo = address(feeCollector);
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = "balancer-quad";
        _seFeeOff(c.ses);
        _install(c);
    }
}

// =====================================================================================================
// Sanity: un-quarantine a KNOWN confirmed finding and show INV-1 catches it.
//   rawleg-rp-swap: weighted hook, raw leg carries a rate provider (r = 1.2). Same handler, same action.
// =====================================================================================================
contract P4_Sanity_RawLegRp is TB_Weighted {
    HookValueHandler internal handler;

    function _build(uint256 rate) internal {
        RateProviderMock rp1 = new RateProviderMock();
        rp1.mockRate(rate);
        address[] memory toks = new address[](3);
        toks[0] = address(token0);
        toks[1] = address(token1);
        toks[2] = address(token2);
        uint256[] memory w = new uint256[](3);
        w[0] = 333333333333333333;
        w[1] = 333333333333333333;
        w[2] = WAD - w[0] - w[1];
        address[] memory ses = new address[](3);
        ses[0] = se0;
        address[] memory rps = new address[](3);
        rps[1] = address(rp1);
        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));
        _setDexFee(3e15);
        _setUsageFee(0);
        HookValueHandler.Config memory c;
        c.hook = hook;
        c.tokens = new SimpleMintableERC20[](3);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.tokens[2] = token2;
        c.ses = new address[](3);
        c.ses[0] = se0;
        c.vaults = new address[](3);
        c.vaults[0] = address(vault0);
        c.prices = new uint256[](3);
        c.prices[0] = 1e18;
        c.prices[1] = rate; // fair price of the rated raw leg = its provider rate
        c.prices[2] = 1e18;
        c.router = swapRouter;
        c.pm = pm;
        c.keys = new PoolKey[](0);
        c.feeTo = address(feeCollector);
        c.allowYield = true;
        c.seedEach = 100_000e18;
        c.family = rate == 1e18 ? "sanity-control-r1.0" : "sanity-rawleg-r1.2";
        handler = new HookValueHandler(c);
        handler.seed();
    }

    /// The exact INV-1 action the fuzzer uses (a_roundTrip, SE exact-in both legs, token2 -> token1 -> token2).
    function test_sanity_unquarantined_rawLegRp_breaksNoCycleProfit() public {
        _build(1.2e18);
        handler.a_roundTrip(2, 1, 10_000e18, 0);
        handler.logStats();
        assertEq(handler.successes(7), 1, "action executed");
        assertGt(handler.cycleBreaks(), 0, "INV-1 must flag the known rawleg-rp-swap drain");
        assertGt(handler.worstCycle(), int256(1e21), "profit > 1000 tokens on a 10k round trip");
    }

    function test_sanity_control_rate1_noBreak() public {
        _build(1e18);
        handler.a_roundTrip(2, 1, 10_000e18, 0);
        handler.logStats();
        assertEq(handler.successes(7), 1, "action executed");
        assertEq(handler.cycleBreaks(), 0, "control: no cycle profit at rate 1");
        assertLt(handler.worstCycle(), 0, "control: round trip pays fees");
    }
}
