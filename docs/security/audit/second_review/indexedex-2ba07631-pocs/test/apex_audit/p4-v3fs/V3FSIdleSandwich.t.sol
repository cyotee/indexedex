// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {V3FSFixture} from "./V3FSInvariant.t.sol";

/// @notice Minimisation of the medium-campaign INV-1 break: a_sandwich(sub=2 mintExactOut, up=false, pushBps=8752->3756,
///         amt=183->tiny, sel=odd token1). One call, from genesis. Sweeps sub-op x direction x push size.
contract V3FSIdleSandwichTest is V3FSFixture {
    function _one(uint256 sub, bool up, uint256 bps, uint256 amt, uint256 sel) internal returns (int256 dProfit, int256 dPassive, uint256 offEv) {
        uint256 snap = vm.snapshotState();
        int256 p0 = h.attackerProfit();
        int256 v0 = int256(h.valueOf(address(h.passive())));
        uint256 e0 = h.offPriceMints();
        h.a_sandwich(sub, up, bps, amt, sel);
        dProfit = h.attackerProfit() - p0;
        dPassive = int256(h.valueOf(address(h.passive()))) - v0;
        offEv = h.offPriceMints() - e0;
        vm.revertToState(snap);
    }

    function test_repro_shrunkSequence() public {
        (int256 dp, int256 dv, uint256 ev) = _one(18, false, 8752, 183, 3727);
        console2.log("repro attacker dProfit", dp);
        console2.log("repro passive dValue", dv);
        console2.log("repro off-price maintenance events", ev);
        h.a_sandwich(18, false, 8752, 183, 3727);
        (bool ok,,) = h.checkNoFreeValue();
        assertFalse(ok, "reproduces INV-1 break");
    }

    function test_sweep() public {
        uint256[6] memory bps = [uint256(500), 1000, 2000, 3000, 3756, 5000];
        uint8[3] memory subs = [uint8(6), 2, 0]; // rebalance only, dust exact-out mint, dust single deposit
        for (uint256 k; k < 3; ++k) {
            for (uint256 d; d < 2; ++d) {
                for (uint256 i; i < 6; ++i) {
                    (int256 dp, int256 dv, uint256 ev) = _one(subs[k], d == 1, bps[i], 183, 3727);
                    console2.log(string.concat(
                        "sub=", vm.toString(uint256(subs[k])), d == 1 ? " up" : " down", " bps=", vm.toString(bps[i]),
                        " offEv=", vm.toString(ev), " atk dProfit=", vm.toString(dp), " passive dV=", vm.toString(dv)
                    ));
                }
            }
        }
    }
}
