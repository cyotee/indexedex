// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {FSInvHandler, IFSVault} from "./FSInvHandler.sol";

/// @notice Shared invariant suite (mixed into the hookless / Pons test contracts).
abstract contract FSInvSuite is Test {
    FSInvHandler internal handler;

    function _vaultAddr() internal view virtual returns (address);
    function _lp0() internal view virtual returns (address) { return address(this); }

    function _findPosition(Vm.Log[] memory logs, address pm, address v)
        internal pure returns (int24 lo, int24 hi, bytes32 salt)
    {
        bytes32 sig = keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)");
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == pm && logs[i].topics[0] == sig && address(uint160(uint256(logs[i].topics[2]))) == v) {
                (lo, hi,, salt) = abi.decode(logs[i].data, (int24, int24, int256, bytes32));
                found = true;
            }
        }
        require(found, "vault position not found");
    }

    function _wireHandler() internal {
        targetContract(address(handler));
        targetSelector(StdInvariant.FuzzSelector({addr: address(handler), selectors: handler.fuzzSelectors()}));
    }

    // ------------------------------------------------------------------
    // Combined invariant (one campaign checks everything after every call)
    // ------------------------------------------------------------------
    function invariant_all() public {
        address v = _vaultAddr();
        IERC20 t0 = handler.t0();
        IERC20 t1 = handler.t1();
        uint256 EPS = handler.EPS();

        // harness sanity: every action leaves the pool at the fair price
        assertTrue(handler.priceAtP0(), "harness: price not at P0");
        assertEq(handler.priceNotRestored(), 0, "harness: restore failed");

        // I1 no-free-value: no action makes its actor richer at the fair price (net of everything it paid)
        assertEq(handler.actorGainViolations(), 0, "I1 no-free-value: actor gained");
        assertLe(handler.attackerOwnDeltaSum(), int256(EPS * (handler.attackerActions() + 1)), "I1 attacker cumulative gain");

        // I2 share price (NAV/S at P0) non-decreasing except vault-swap cost (fee + bounded impact)
        assertEq(handler.navViolations(), 0, "I2 share price dropped beyond vault-swap allowance");

        // classifier sanity: every quarantined hit is attributed to a documented class
        assertEq(handler.unattributedQuarantineHits(), 0, "harness: unattributed quarantine");

        // I6 R synced after every op; R never exceeds the live balance
        assertEq(handler.rSyncViolations(), 0, "I6 R not synced after op");
        assertLe(IStandardExchangeProxy(v).reserveOfToken(address(t0)), t0.balanceOf(v), "I6 R0 > bal0");
        assertLe(IStandardExchangeProxy(v).reserveOfToken(address(t1)), t1.balanceOf(v), "I6 R1 > bal1");
        assertLe(IStandardExchangeProxy(v).reserveOfToken(v), IERC20(v).balanceOf(v), "I6 Rshare > balShare");

        // I4 preview == execute (within 2 wei or 1 ppm)
        assertEq(handler.previewViolations(), 0, "I4 preview != execute");

        // I5 sleeve accounting: free == balances, deployed == pool position at live price
        assertEq(IFSVault(v).localReserve(address(t0)), t0.balanceOf(v), "I5 free0");
        assertEq(IFSVault(v).localReserve(address(t1)), t1.balanceOf(v), "I5 free1");
        (bool depOk,,,,) = handler.deployedMatchesPool();
        assertTrue(depOk, "I5 deployed != pool position");

        // I3 Sum redeemable (single-sided previews) <= fair value; NAV >= sum of fair claims
        uint256 S = IERC20(v).totalSupply();
        uint256 N = handler.nav();
        if (S != 0) {
            assertGt(N, 0, "I3 supply without backing");
            uint256 n = handler.actorCount();
            for (uint256 i; i <= n; ++i) {
                address h = i == n ? _lp0() : handler.actorAt(i);
                uint256 sh = IERC20(v).balanceOf(h);
                if (sh == 0) continue;
                uint256 fair = sh * N / S;
                for (uint256 k; k < 2; ++k) {try IStandardExchangeIn(v).previewExchangeIn(IERC20(v), sh, k == 0 ? t0 : t1) returns (uint256 q, uint256) {
                        if (q > fair + EPS) {
                            console2.log("I3 redeem preview > fair", i, q, fair);
                            fail();
                        }
                    } catch {}
                }
            }
        }
    }

    /// non-vacuity: per-selector successful-call counts; most calls must succeed
    function _metricsPath() internal view virtual returns (string memory) { return "cache_audit/p4fs_metrics.csv"; }

    function _resetMetrics() internal {
        try vm.removeFile(_metricsPath()) {} catch {}
    }

    function afterInvariant() public {
        handler.summary();
        string memory path = _metricsPath();
        uint256 n = handler.selCount();
        for (uint256 i; i < n; ++i) {
            (string memory nm, uint256 c, uint256 o) = handler.selStat(i);
            vm.writeLine(path, string.concat(nm, ",", vm.toString(c), ",", vm.toString(o)));
        }
        vm.writeLine(path, string.concat("RUN,", vm.toString(handler.actorGainViolations()), ",", vm.toString(handler.navViolations()),
            ",", vm.toString(handler.previewChecks()), ",", vm.toString(handler.previewExact()), ",", vm.toString(handler.maxPreviewDevPpm()),
            ",", vm.toString(handler.knownJitHits()), ",", vm.toString(handler.knownBseHits()), ",", vm.toString(handler.dumpHits()),
            ",", vm.toString(handler.bseP0Hits()), ",", vm.toString(handler.selfJitHits())));
        (uint256 tc, uint256 to) = handler.totals();
        if (tc >= 10) assertGe(to * 100, tc * 50, "non-vacuity: <50% of handler calls succeeded in this run");
    }
}
