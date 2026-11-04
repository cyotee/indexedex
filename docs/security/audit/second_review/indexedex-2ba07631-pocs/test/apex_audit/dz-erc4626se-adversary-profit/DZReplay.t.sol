// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {DZ_ERC4626SE_Base} from "./DZBase.sol";

/// Replay of the slot12 deep-campaign counterexample for P4_ERC4626SE_Invariant
/// (adversary +0.7314e18, honest -0.2121e18), with a control branch (rate move only) to
/// measure REAL honest loss (realizable redemption value) vs. harness ghost accounting.
contract DZ_ERC4626SE_Replay is DZ_ERC4626SE_Base {
    // shrunk counterexample args
    uint256 constant DON_TOK = 3315022205555633215256165509297557736;
    uint256 constant DON_AMT = 870509351070464923032994560593199039596753680606;
    uint256 constant RATE = 288;
    uint256 constant SW_TOK = 864000;
    uint256 constant SW_AMT = 16359;
    uint256 constant SW_BPS = 5621111;

    /// realizable value (underlying units) of `holder`'s SE shares via the SE's own redemption preview
    function _realizable(address holder) internal view returns (uint256) {
        uint256 sh = IERC20(seAddr).balanceOf(holder);
        if (sh == 0) return 0;
        uint256 rcpt = IERC4626(seAddr).previewRedeem(sh);
        return protocolVault.convertToAssets(rcpt);
    }

    function _log(string memory tag) internal view {
        console2.log("=====", tag);
        console2.log(" supply", IERC20(seAddr).totalSupply());
        console2.log(" SE receipts held / booked", protocolVault.balanceOf(seAddr), IBasicVault(seAddr).reserveOfToken(address(protocolVault)));
        console2.log(" SE totalAssets (receipt units)", IERC4626(seAddr).totalAssets());
        console2.log(" fairNav / reportedNav", fairNav(), reportedNav());
        console2.log(" rate (assets per 1e18 receipt)", protocolVault.convertToAssets(1e18));
        for (uint256 i; i < 4; ++i) {
            address w = handler.wallet(i);
            console2.log(" actor", i);
            console2.log("   shares", IERC20(seAddr).balanceOf(w));
            console2.log("   receipts / underlying", protocolVault.balanceOf(w), underlying.balanceOf(w));
            console2.log("   realizable share value", _realizable(w));
            console2.log("   harness netGain");
            console2.logInt(handler.netGain(i));
            console2.log("   harness exo");
            console2.logInt(handler.exo(i));
        }
        console2.log(" DEAD realizable", _realizable(DEAD));
    }

    function test_replay_counterexample() public {
        _log("after setUp");
        uint256 snap = vm.snapshotState();

        // ---- control: only the exogenous rate move
        handler.advRateMove(RATE);
        _log("CONTROL (rate move only)");
        uint256 ctlA0 = _realizable(handler.wallet(0));
        uint256 ctlDead = _realizable(DEAD);

        vm.revertToState(snap);

        // ---- attack sequence (shrunk counterexample)
        address adv = handler.wallet(3);
        handler.advDonate(DON_TOK, DON_AMT, false);
        uint256 donatedRcpt = protocolVault.balanceOf(seAddr) - IBasicVault(seAddr).reserveOfToken(address(protocolVault));
        console2.log("donated receipts (unbooked)", donatedRcpt);
        _log("after advDonate");
        handler.advRateMove(RATE);
        _log("after advRateMove");
        uint256 advRcptBefore = protocolVault.balanceOf(adv);
        handler.advPretransferMintOutSweep(SW_TOK, SW_AMT, SW_BPS);
        _log("after advPretransferMintOutSweep");
        console2.log("adv receipts refunded/kept delta", protocolVault.balanceOf(adv) - advRcptBefore);

        uint256 atkA0 = _realizable(handler.wallet(0));
        uint256 atkDead = _realizable(DEAD);
        console2.log("actor0 realizable: control / attack", ctlA0, atkA0);
        console2.log("DEAD   realizable: control / attack", ctlDead, atkDead);
        console2.log("harness adversary netGain / honest0 netGain");
        console2.logInt(handler.netGain(3));
        console2.logInt(handler.netGain(0));
        // REAL honest loss vs. counterfactual (no adversary): must be > rounding to be a finding
        console2.log("REAL actor0 loss vs control (signed: ctl - atk)");
        console2.logInt(int256(ctlA0) - int256(atkA0));
        console2.log("REAL DEAD loss vs control (signed: ctl - atk)");
        console2.logInt(int256(ctlDead) - int256(atkDead));
        assertApproxEqAbs(atkA0, ctlA0, 1e6, "honest realizable value differs from no-attack control");
        assertApproxEqAbs(atkDead, ctlDead, 1e6, "dead realizable value differs from no-attack control");
    }
}
