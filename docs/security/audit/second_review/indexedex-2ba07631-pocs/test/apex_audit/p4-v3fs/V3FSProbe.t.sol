// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {V3FSFixture} from "./V3FSInvariant.t.sol";

/// @notice Investigation of the monitored (attributed, known-class) off-price maintenance events seen by the
///         campaign: does the post-op best-effort rebalance at the op's own moved spot leak value?
contract V3FSProbeTest is V3FSFixture {
    function _report(string memory tag, uint256 pv0) internal view {
        uint256 pv1 = h.valueOf(address(h.passive()));
        console2.log(tag);
        console2.log("  passive value before / after", pv0, pv1);
        console2.log("  off-price maintenance events / explained passive loss", h.offPriceMints(), h.explainedPassiveLoss());
        console2.log("  attacker profit", h.attackerProfit());
        console2.log("  attacker fee allowance", h.atkAllowance());
    }

    /// Honest-only flow: vault-routed swaps both directions; arbitrageur restores P0 after each.
    function test_probe_honestSwapsOnly() public {
        uint256 pv0 = h.valueOf(address(h.passive()));
        for (uint256 i; i < 20; ++i) {
            h.h_swapExactIn(i, i, 300 ether);
        }
        _report("honest vault swaps x20 (300e18 each, alternating)", pv0);
        _checkAll();
    }

    /// Honest-only flow: single-token zap-outs (vault burns + swaps through its own pool).
    function test_probe_honestZapOutsOnly() public {
        for (uint256 i; i < 3; ++i) h.h_dualDeposit(i, 600 ether);
        uint256 pv0 = h.valueOf(address(h.passive()));
        for (uint256 i; i < 12; ++i) h.h_zapOutExactIn(i, i, 150 ether);
        _report("honest zap-outs x12", pv0);
        _checkAll();
    }

    /// Attacker: create a one-sided free excess with a single-sided deposit, then a vault-routed swap that makes
    /// the other side exceed target at the moved spot -> best-effort mint at that spot -> attacker restores P0
    /// (capturing IL on the fresh liquidity) -> attacker exits.
    function test_probe_attacker_excessThenVaultSwap() public {
        uint256[4] memory dep = [uint256(100 ether), 300 ether, 600 ether, 1200 ether];
        uint256[3] memory sw = [uint256(150 ether), 400 ether, 600 ether];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 3; ++j) {
                uint256 snap = vm.snapshotState();
                uint256 pv0 = h.valueOf(address(h.passive()));
                h.a_singleDeposit(0, dep[i], false, 0); // token0 single-sided
                h.a_swapExactIn(1, sw[j], false); // token1 -> token0 via vault: token0 price up
                h.a_zapOutExactIn(1, type(uint256).max, false, 0); // exit everything (token1)
                console2.log("dep / swap (e18)", dep[i] / 1e18, sw[j] / 1e18);
                _report("  ", pv0);
                (bool ok,,) = h.checkNoFreeValue();
                console2.log("  INV-1 holds", ok);
                vm.revertToState(snap);
            }
        }
    }
}
