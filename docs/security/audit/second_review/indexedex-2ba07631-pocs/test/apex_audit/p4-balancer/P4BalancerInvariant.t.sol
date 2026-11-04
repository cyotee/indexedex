// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {CoordinatorSeRouterDeployLib} from "test/foundry/spec/routers/balancerV3-uniswapV4/helpers/CoordinatorSeRouterDeployLib.sol";
import {P4BalancerHandler, P4Adversary, P4Env, IP4SERouter, IP4RP} from "./P4BalancerHandler.sol";

/// @title P4 stateful invariant harness: Balancer V3 SE buffer pool + native BPT SE + routers + rate provider
/// @notice Fixture = project's own TestBase_StandardExchangeBufferPool (real crane Balancer V3 VaultMock +
///         RouterMock, Aerodrome DAI/USDC SE vault, StandardExchangeRateProvider, constProd buffer pool
///         diamond with hook + native SE facets) + the IndexedEx BalancerV3StandardExchangeRouter diamond.
///
/// QUARANTINE (known confirmed findings excluded so the fuzzer hunts new bugs):
///  - balancer-buffer-computebalance-domain: Vault SINGLE_TOKEN_EXACT_IN removals and SINGLE_TOKEN_EXACT_OUT adds
///    (adversary kinds 14/15 only with allowKnown), native SE exits (BPT->token) and native exact-out joins (route
///    through the same kinds) are never called.
///  - hook-midstate-reentrancy: the adversary calls Vault.swap as "router" but does NOT implement
///    prepaySessionActive(), so the hook never calls back into it mid-hook.
///  - balancer-router-permit-overpull: no *WithPermit selectors, and no exact-out pass-through route
///    (pool==tokenInVault==tokenOutVault) on the SE router.
///  - se-rate-provider-full-book-manipulable / cross-venue NAV arbitrage: the adversary never trades the SE vault
///    directly (no SE-vault zap legs), and no BPT-as-SE-subject rate provider is instantiated.
abstract contract P4BalancerInvariantBase is TestBase_StandardExchangeBufferPool {
    P4BalancerHandler internal h;
    address internal seRouterAddr;

    function setUp() public virtual override {
        super.setUp();
        seRouterAddr = address(
            CoordinatorSeRouterDeployLib.deploy(create3Factory, diamondPackageFactory, IVault(address(vault)), permit2, IWETH(address(weth)))
        );
        vm.label(seRouterAddr, "SERouter");
        P4Env memory env = P4Env({
            vault: IVault(address(vault)),
            router: address(router),
            seRouter: seRouterAddr,
            pool: bufferPool,
            seVault: address(seVault),
            tta: address(dai),
            usdc: address(usdc),
            aeroPool: address(aeroDaiUsdcPool),
            aeroRouter: address(aeroRouter),
            permit2: address(permit2),
            rp: address(seRateProvider)
        });
        h = new P4BalancerHandler(env);
        h.init();
        h.setQuarantineTtaDomain(_quarantineNewTtaDomain());
        vm.label(address(h), "P4Handler");

        bool q = _quarantineNewTtaDomain();
        bytes4[] memory sels = new bytes4[](q ? 16 : 17);
        uint256 n;
        sels[n++] = P4BalancerHandler.h_mockSwapExactIn.selector;
        sels[n++] = P4BalancerHandler.h_mockSwapExactOut.selector;
        sels[n++] = P4BalancerHandler.h_seSwapExactIn.selector;
        sels[n++] = P4BalancerHandler.h_seSwapExactOut.selector;
        sels[n++] = P4BalancerHandler.h_addUnbalanced.selector;
        sels[n++] = P4BalancerHandler.h_nativeJoin.selector;
        sels[n++] = P4BalancerHandler.h_addProportional.selector;
        sels[n++] = P4BalancerHandler.h_removeProportional.selector;
        // NEW B2/B3: single-sided exact-out exits overpay & hook scales the virtual book proportionally
        // -> excluded in quarantined (deep) mode
        if (!q) sels[n++] = P4BalancerHandler.h_removeSingleExactOut.selector;
        sels[n++] = P4BalancerHandler.h_donate.selector;
        sels[n++] = P4BalancerHandler.h_aeroMarket.selector;
        sels[n++] = P4BalancerHandler.h_aeroArb.selector;
        sels[n++] = P4BalancerHandler.h_warp.selector;
        sels[n++] = P4BalancerHandler.a_program.selector;
        sels[n++] = P4BalancerHandler.a_program.selector; // weight adversarial programs x2
        sels[n++] = P4BalancerHandler.a_gift.selector;
        sels[n++] = P4BalancerHandler.a_aeroMovePersistent.selector;
        targetContract(address(h));
        targetSelector(StdInvariant.FuzzSelector({addr: address(h), selectors: sels}));
    }

    /// @dev NEW finding (this harness) B1/B2: live TTA invisible to computeInvariant. Quarantined in the
    ///      *Q / Medium contracts so the fuzzer keeps hunting beyond it.
    function _quarantineNewTtaDomain() internal pure virtual returns (bool) {
        return true;
    }

    /* ------------------------------------------------------------------------------------ */

    function _tokens() internal view returns (address[6] memory t) {
        t = [address(dai), address(usdc), address(seVault), bufferPool, address(aeroDaiUsdcPool), address(weth)];
    }

    function _checkAll() internal view {
        address[6] memory t = _tokens();
        // I1 routers hold nothing after every call (beyond adversary gifts)
        for (uint256 i; i < t.length; ++i) {
            assertLe(IERC20(t[i]).balanceOf(address(router)), h.gifted(address(router), t[i]), "I1 RouterMock residue");
            assertLe(IERC20(t[i]).balanceOf(seRouterAddr), h.gifted(seRouterAddr, t[i]), "I1 SE router residue");
            // I2 hook / pool diamond holds nothing at rest
            assertLe(IERC20(t[i]).balanceOf(bufferPool), h.gifted(bufferPool, t[i]), "I2 hook/pool diamond residue");
        }
        assertEq(seRouterAddr.balance, 0, "I1 SE router ETH residue");
        assertEq(IVault(address(vault)).balanceOf(bufferPool, bufferPool), 0, "I2 pool-held BPT (native SE credit)");
        assertFalse(IP4SERouter(seRouterAddr).prepaySessionActive(), "I1 SE router prepay session left open");
        // I3 Vault solvency
        for (uint256 i; i < 3; ++i) {
            assertGe(IERC20(t[i]).balanceOf(address(vault)), IVault(address(vault)).getReservesOf(IERC20(t[i])), "I3 vault insolvent");
        }
        // I4 user never pays more than limit / receives less than limit or than reported
        assertEq(h.limitViolations(), 0, string.concat("I4 limit: ", h.lastLimitViolation()));
        // I5 pool (virtual-book) invariant per BPT non-decreasing across every action
        assertEq(h.invDropViolations(), 0, string.concat("I5 invariant/BPT drop: ", h.lastInvDrop()));
        // I6 single-token join / exit vs proportional consistency
        assertEq(h.exitViolations(), 0, string.concat("I6 single-exit overpays: ", h.lastJoinExitViolation()));
        assertEq(h.joinViolations(), 0, string.concat("I6 single-join underpays: ", h.lastJoinExitViolation()));
        // I7 adversarial programs never profit (beyond dust + own gifts)
        assertEq(h.profitViolations(), 0, string.concat("I7 adversary profit: ", h.lastProfitViolation()));
        // I9 LP fair book value per BPT never drops >50 bps during one adversarial program
        assertEq(h.bookDropViolations(), 0, string.concat("I9 LP fair book drop: ", h.lastBookDrop()));
        // I8 rate provider sane: non-zero; whole-book valuation never above fair value when Aerodrome is at par
        uint256 rate = IP4RP(address(seRateProvider)).getRate();
        assertGt(rate, 0, "I8 rate zero");
        if (h.aeroNearPar()) {
            uint256 fsv = h.fairShareValue();
            assertLe(rate, fsv + fsv / 500, "I8 rate above fair share value");
        }
    }

    function _logSummary() internal view {
        h.logSummary();
        console2.log("rate", IP4RP(address(seRateProvider)).getRate(), "fairShareValue", h.fairShareValue());
    }

    /* ----------------- cross-run aggregation (process env persists across invariant runs) ----------------- */

    function _acc(string memory key, uint256 add) internal returns (uint256 tot) {
        tot = vm.envOr(key, uint256(0)) + add;
        vm.setEnv(key, vm.toString(tot));
    }

    function _aggregate(string memory pfx) internal {
        uint256 runs = _acc(string.concat(pfx, "_runs"), 1);
        uint256 ta = _acc(string.concat(pfx, "_totAtt"), h.totalAtt());
        uint256 to = _acc(string.concat(pfx, "_totOk"), h.totalOk());
        console2.log("==== AGGREGATE over runs so far:", runs);
        console2.log("  handler calls ok/att", to, ta);
        string[17] memory nm = [
            "h_mockSwapExactIn", "h_mockSwapExactOut", "h_seSwapExactIn", "h_seSwapExactOut", "h_addUnbalanced",
            "h_nativeJoin(TTA)", "h_nativeJoin(SH)", "h_addProportional", "h_removeProportional",
            "h_removeSingleExactOut(TTA)", "h_removeSingleExactOut(SH)", "h_donate", "h_aeroMarket", "h_aeroArb",
            "h_warp", "a_program", "a_gift"
        ];
        for (uint256 i; i < nm.length; ++i) {
            (uint256 a, uint256 o) = h.counts(nm[i]);
            uint256 A = _acc(string.concat(pfx, "_a_", nm[i]), a);
            uint256 O = _acc(string.concat(pfx, "_o_", nm[i]), o);
            if (A > 0) console2.log(string.concat("  ", nm[i], " ok/att"), O, A);
        }
        (uint256 aa, uint256 ao) = h.counts("a_aeroMovePersistent");
        console2.log("  a_aeroMovePersistent ok/att", _acc(string.concat(pfx, "_o_amp"), ao), _acc(string.concat(pfx, "_a_amp"), aa));
        for (uint256 k; k < 16; ++k) {
            uint256 A = _acc(string.concat(pfx, "_opA", vm.toString(k)), h.opAtt(k));
            uint256 O = _acc(string.concat(pfx, "_opO", vm.toString(k)), h.opOk(k));
            if (A > 0) console2.log(string.concat("  program op kind ", vm.toString(k), " ok/att"), O, A);
        }
        console2.log("  programs ok/att", _acc(string.concat(pfx, "_pO"), h.programsOk()), _acc(string.concat(pfx, "_pA"), h.programsAtt()));
        for (uint256 r; r < 7; ++r) {
            uint256 A = _acc(string.concat(pfx, "_siA", vm.toString(r)), h.seInAtt(r));
            uint256 O = _acc(string.concat(pfx, "_siO", vm.toString(r)), h.seInOk(r));
            if (A > 0) console2.log(string.concat("  seRouter exactIn route ", vm.toString(r), " ok/att"), O, A);
        }
        for (uint256 r; r < 6; ++r) {
            uint256 A = _acc(string.concat(pfx, "_soA", vm.toString(r)), h.seOutAtt(r));
            uint256 O = _acc(string.concat(pfx, "_soO", vm.toString(r)), h.seOutOk(r));
            if (A > 0) console2.log(string.concat("  seRouter exactOut route ", vm.toString(r), " ok/att"), O, A);
        }
        console2.log("  quarantined NEW-B events join/exit", _acc(string.concat(pfx, "_qj"), h.qJoinEvents()), _acc(string.concat(pfx, "_qe"), h.qExitEvents()));
        int256 mp = h.maxProgramProfit();
        int256 prevMax = vm.envOr(string.concat(pfx, "_maxP"), int256(type(int128).min));
        if (mp > prevMax) vm.setEnv(string.concat(pfx, "_maxP"), vm.toString(mp));
        console2.log("  max adversary program profit (DAI wei) across runs:");
        console2.logInt(mp > prevMax ? mp : prevMax);
        _aggregateChecks(pfx, runs);
        if (runs >= 4) assertGe(to * 100, ta * 60, "non-vacuity: <60% of handler calls succeeded (aggregate)");
    }

    function _aggregateChecks(string memory pfx, uint256 runs) internal {
        uint256 ic = _acc(string.concat(pfx, "_invC"), h.invChecks());
        uint256 isk = _acc(string.concat(pfx, "_invS"), h.invSkips());
        uint256 jc = _acc(string.concat(pfx, "_joinC"), h.joinChecks());
        uint256 jq = _acc(string.concat(pfx, "_joinQ"), h.joinQuarantined());
        uint256 js = _acc(string.concat(pfx, "_joinS"), h.joinSkips());
        console2.log("  I5 per-action checks evaluated / skipped", ic, isk);
        console2.log("  I6 join checks asserted / quarantined / skipped", jc, jq, js);
        console2.log("  gift residue recaptured in programs (cum DAI wei)", _acc(string.concat(pfx, "_giftR"), h.giftRecaptured()));
        // non-vacuity over the aggregate: most calls succeed
        if (runs >= 4) {
            // audit fix: I5 / I6 must actually be evaluated, not silently early-returned
            assertGe(ic * 100, (ic + isk) * 80, "non-vacuity: >20% of I5 per-action checks skipped (aggregate)");
            assertGt(jc, 0, "non-vacuity: I6 join check never asserted (aggregate)");
        }
    }

    function _nonVacuity() internal view {
        // per-run: most calls succeed
        if (h.totalAtt() >= 5) assertGe(h.totalOk() * 100, h.totalAtt() * 40, "non-vacuity: <40% of handler calls succeeded in a run");
    }
}

/// Validation run with the NEW TTA-domain finding UN-quarantined (profile defaults: runs=16 depth=8).
contract P4BalancerInvariantShort is P4BalancerInvariantBase {
    function _quarantineNewTtaDomain() internal pure override returns (bool) {
        return false;
    }

    function _aggKey() internal pure returns (string memory) {
        return "P4B_SHORT";
    }

    /// forge-config: audit.invariant.fail-on-revert = false
    /// forge-config: audit.invariant.show-metrics = true
    function invariant_p4_all() public view {
        _checkAll();
    }

    function afterInvariant() public {
        _logSummary();
        _aggregate(_aggKey());
        _nonVacuity();
    }

    /* ------------------------------ sanity: known bug is caught ------------------------------ */

    function _knownOps(bool unquarantine) internal pure returns (P4Adversary.Op[] memory ops) {
        ops = new P4Adversary.Op[](22);
        ops[0] = P4Adversary.Op(0, 100e18 - 1e16); // TTA->shares EXACT_IN ~100 TTA (sets h > 0)
        ops[1] = P4Adversary.Op(5, 1e18 - 1e16); // unbalanced shares-only add ~1 share -> BPT
        for (uint256 i = 2; i < 22; ++i) {
            // KNOWN: dust SINGLE_TOKEN_EXACT_IN exits to shares (5% of held BPT each); control: proportional
            ops[i] = unquarantine ? P4Adversary.Op(14, 500 - 1) : P4Adversary.Op(7, 500 - 1);
        }
    }

    function test_sanity_unquarantinedKnownBug_isCaught() public {
        h.setAllowKnown(true);
        int256 profit = h.runProgramExt(_knownOps(true));
        console2.log("known-bug program profit (DAI wei)");
        console2.logInt(profit);
        h.logSummary();
        assertGt(h.profitViolations(), 0, "I7 must flag the known computeBalance-domain drain");
        assertGt(h.invDropViolations(), 0, "I5 must flag the known computeBalance-domain drain");
    }

    function test_sanity_control_quarantined_noViolation() public {
        int256 profit = h.runProgramExt(_knownOps(false));
        console2.log("control program profit (DAI wei)");
        console2.logInt(profit);
        assertEq(h.profitViolations(), 0, "control must not violate I7");
        assertEq(h.invDropViolations(), 0, "control must not violate I5");
    }
}

/// Validation run, all known + new findings quarantined (profile defaults: runs=16 depth=8).
contract P4BalancerInvariantShortQ is P4BalancerInvariantBase {
    function _aggKey() internal pure returns (string memory) {
        return "P4B_SHORTQ";
    }

    /// forge-config: audit.invariant.fail-on-revert = false
    /// forge-config: audit.invariant.show-metrics = true
    function invariant_p4_all_q() public view {
        _checkAll();
    }

    function _pv(address who) internal returns (uint256 v) {
        uint256 bal = IERC20(bufferPool).balanceOf(who);
        if (bal == 0) return 0;
        uint256 snap = vm.snapshotState();
        uint256 t0 = dai.balanceOf(who);
        uint256 s0 = shares.balanceOf(who);
        removeLiquidityProportional(who, bal, 0, 0);
        v = (dai.balanceOf(who) - t0) + (shares.balanceOf(who) - s0) * h.fairShareValue() / 1e18;
        vm.revertToState(snap);
    }

    function _poolLog(string memory tag) internal view {
        (,, uint256[] memory raw,) = IVault(address(vault)).getPoolTokenInfo(bufferPool);
        (bool ok, bytes memory r) = bufferPool.staticcall(abi.encodeWithSignature("virtualTTA()"));
        (, bytes memory r2) = bufferPool.staticcall(abi.encodeWithSignature("hookSharesDelta()"));
        (, bytes memory r3) = bufferPool.staticcall(abi.encodeWithSignature("ttaIndex()"));
        console2.log(tag);
        console2.log("  raw0 / raw1 / ttaIdx", raw[0], raw[1], abi.decode(r3, (uint256)));
        if (ok) console2.log("  virtualTTA", abi.decode(r, (uint256)));
        console2.logInt(abi.decode(r2, (int256)));
        console2.log("  supply / rate / fsv", IVault(address(vault)).totalSupply(bufferPool), IP4RP(address(seRateProvider)).getRate(), h.fairShareValue());
    }

    /// audit diagnostic: shares-only join at the initial state (h == 0) -> joiner value received vs paid
    function test_diag_sharesOnlyJoin_initialState() public {
        _poolLog("initial");
        address u = makeAddr("diagJoiner");
        uint256 S = mintShares(u, 100e18);
        uint256 alice0 = _pv(alice);
        vm.startPrank(u);
        IERC20(address(seVault)).approve(bufferPool, type(uint256).max);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        (bool ok, bytes memory ret) = bufferPool.call(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)", address(seVault), S, bufferPool, 0, u, false, block.timestamp
            )
        );
        vm.stopPrank();
        require(ok, "join failed");
        _poolLog("after native shares join");
        uint256 v = _pv(u);
        console2.log("shares in / bpt", S, abi.decode(ret, (uint256)));
        console2.log("value in @fsv / @rate", S * h.fairShareValue() / 1e18, S * IP4RP(address(seRateProvider)).getRate() / 1e18);
        console2.log("joiner prop-exit value @fsv", v);
        console2.log("alice prop-exit value before/after @fsv", alice0, _pv(alice));
    }

    /// audit probe: classify the 0/111 native TTA join (expected: B1 -> preview 0 -> MinAmountNotMet / panic)
    function test_probe_nativeJoinTta_revertReason() public {
        address u = makeAddr("probeJoiner");
        dai.mint(u, 100e18);
        vm.startPrank(u);
        IERC20(address(dai)).approve(bufferPool, type(uint256).max);
        (bool ok, bytes memory ret) = bufferPool.call(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)", address(dai), 10e18, bufferPool, 0, u, false, block.timestamp
            )
        );
        vm.stopPrank();
        console2.log("native TTA join ok", ok);
        console2.logBytes(ret);
        assertFalse(ok, "native TTA join unexpectedly succeeded");
    }

    function afterInvariant() public {
        _logSummary();
        _aggregate(_aggKey());
        _nonVacuity();
    }
}

/// Medium run, all known + new findings quarantined.
contract P4BalancerInvariantMedium is P4BalancerInvariantBase {
    function _aggKey() internal pure returns (string memory) {
        return "P4B_MEDIUM";
    }

    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    /// forge-config: audit.invariant.fail-on-revert = false
    /// forge-config: audit.invariant.show-metrics = true
    function invariant_p4_all_medium() public view {
        _checkAll();
    }

    function afterInvariant() public {
        _logSummary();
        _aggregate(_aggKey());
        _nonVacuity();
    }
}
