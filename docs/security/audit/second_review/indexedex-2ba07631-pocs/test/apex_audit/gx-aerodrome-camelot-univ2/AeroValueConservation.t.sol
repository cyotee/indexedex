// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

/// @notice Atomic pretransfer integrator (honest): transfer + exchangeOut in one call.
contract AeroAtomicPrepayer {
    function run(IStandardExchangeProxy v, IERC20 tIn, uint256 maxIn, uint256 sharesOut) external returns (uint256 used) {
        tIn.transfer(address(v), maxIn);
        used = v.exchangeOut(tIn, maxIn, IERC20(address(v)), sharesOut, address(this), true, block.timestamp + 1);
    }
}

contract AeroSweeper {
    function sweep(IStandardExchangeProxy v, IERC20 tIn, uint256 amt, IERC20 tOut) external returns (uint256) {(uint256 quotedAmountOut,) = v.exchangeIn(tIn, amt, tOut, 0, address(this), true, block.timestamp + 1);
    return quotedAmountOut;
    }
}

/// @notice gx-aerodrome-camelot-univ2: Aerodrome v1 SE value conservation / manipulation / first-deposit / refunds.
contract AeroValueConservation is TestBase_AerodromeStandardExchange {
    IStandardExchangeProxy vault;
    IPool pool;
    ERC20PermitMintableStub tA;
    ERC20PermitMintableStub tB;

    address alice = makeAddr("alice");
    address trader = makeAddr("trader");
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");
    uint256 aliceShares;

    function setUp() public override {
        super.setUp();
        pool = IPool(address(aeroBalancedPool));
        tA = aeroBalancedTokenA;
        tB = aeroBalancedTokenB;
        vault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(pool));
        uint256 lp = _getLp(alice, 2000e18, 2000e18);
        vm.startPrank(alice);
        IERC20(address(pool)).approve(address(vault), lp);(aliceShares,) = vault.exchangeIn(IERC20(address(pool)), lp, IERC20(address(vault)), 1, alice, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function _getLp(address to, uint256 a, uint256 b) internal returns (uint256 lp) {
        tA.mint(address(this), a);
        tB.mint(address(this), b);
        tA.approve(address(aerodromeRouter), a);
        tB.approve(address(aerodromeRouter), b);
        (,, lp) = aerodromeRouter.addLiquidity(address(tA), address(tB), false, a, b, 0, 0, to, block.timestamp + 1);
    }

    function _swap(address who, IERC20 tIn, IERC20 tOut, uint256 amt) internal returns (uint256 out) {
        vm.startPrank(who);
        tIn.approve(address(aerodromeRouter), amt);
        IRouter.Route[] memory r = new IRouter.Route[](1);
        r[0] = IRouter.Route({from: address(tIn), to: address(tOut), stable: false, factory: address(aerodromePoolFactory)});
        uint256[] memory amts = aerodromeRouter.swapExactTokensForTokens(amt, 0, r, who, block.timestamp + 1);
        vm.stopPrank();
        out = amts[amts.length - 1];
    }

    function _organicFees() internal {
        tA.mint(trader, 3000e18);
        tB.mint(trader, 3000e18);
        for (uint256 i; i < 5; ++i) {
            _swap(trader, tA, tB, 500e18);
            _swap(trader, tB, tA, 500e18);
        }
    }

    /// value of `shares` in LP after a compound (via preview; preview compounds pending fees).
    function _lpOf(uint256 shares) internal view returns (uint256) {(uint256 quotedAmountOut,) = vault.previewExchangeIn(IERC20(address(vault)), shares, IERC20(address(pool)));
    return quotedAmountOut;
    }

    /// LP valued in tokenA at the pool's CURRENT reserves (both legs, B priced 1:1 at fair balanced price).
    function _lpValueFair(uint256 lp) internal view returns (uint256) {
        (uint256 r0, uint256 r1,) = pool.getReserves();
        uint256 ts = IERC20(address(pool)).totalSupply();
        return lp * r0 / ts + lp * r1 / ts; // fair price A:B = 1:1
    }

    /* ---------------- G1: compound-on-touch sandwich (zero-min addLiquidity / zap) ---------------- */
    function test_G1_compoundSandwich_attackerLoses() public {
        _organicFees();
        uint256 snap = vm.snapshotState();
        // control: honest touch with tiny LP deposit
        uint256 tinyLp = _getLp(trader, 1e15, 1e15);
        vm.startPrank(trader);
        IERC20(address(pool)).approve(address(vault), tinyLp);vault.exchangeIn(IERC20(address(pool)), tinyLp, IERC20(address(vault)), 0, trader, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 aliceCtrlLp = _lpOf(aliceShares);
        vm.revertToState(snap);

        for (uint256 k; k < 3; ++k) {
            uint256 push = [uint256(500e18), 2000e18, 6000e18][k];
            uint256 s2 = vm.snapshotState();
            tA.mint(attacker, push);
            uint256 atkLp = _getLp(attacker, 1e15, 1e15);
            uint256 a0 = tA.balanceOf(attacker);
            uint256 b0 = tB.balanceOf(attacker);
            uint256 gotB = _swap(attacker, tA, tB, push);
            vm.startPrank(attacker);
            IERC20(address(pool)).approve(address(vault), atkLp);(uint256 sh,) = vault.exchangeIn(IERC20(address(pool)), atkLp, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
            vm.stopPrank();
            _swap(attacker, tB, tA, gotB);
            // attacker exits its vault position too
            vm.prank(attacker);(uint256 lpBack,) = vault.exchangeIn(IERC20(address(vault)), sh, IERC20(address(pool)), 0, attacker, false, block.timestamp + 1);
            int256 net = int256(tA.balanceOf(attacker) + tB.balanceOf(attacker) + _lpValueFair(lpBack))
                - int256(a0 + b0 + _lpValueFair(atkLp));
            uint256 aliceLp = _lpOf(aliceShares);
            emit log_named_uint("push tokenA", push);
            emit log_named_int("  attacker net (tokenA @1:1)", net);
            emit log_named_int("  alice LP vs control", int256(aliceLp) - int256(aliceCtrlLp));
            assertLe(net, 0, "attacker must not profit");
            vm.revertToState(s2);
        }
    }

    /* ---------------- G2: JIT fee capture (deposit right before compound) ---------------- */
    function test_G2_jitFeeCapture_noProfit() public {
        _organicFees();
        uint256 aliceBefore = _lpOf(aliceShares);
        uint256 lp = _getLp(attacker, 5000e18, 5000e18); // > alice's position
        vm.startPrank(attacker);
        IERC20(address(pool)).approve(address(vault), lp);(uint256 sh,) = vault.exchangeIn(IERC20(address(pool)), lp, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);(uint256 back,) = vault.exchangeIn(IERC20(address(vault)), sh, IERC20(address(pool)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 aliceAfter = _lpOf(aliceShares);
        emit log_named_uint("attacker LP in", lp);
        emit log_named_uint("attacker LP out", back);
        emit log_named_int("alice LP delta", int256(aliceAfter) - int256(aliceBefore));
        // pending fees are compounded before the JIT mint; the only residual is the vault's own zap-swap fee
        // rebate accrued between compounds (dust). Bound it at 1e-6 relative.
        assertLe(back, lp + lp / 1e6, "JIT depositor cannot capture pre-existing fees");
        assertGe(aliceAfter + 2, aliceBefore, "alice keeps her accrued fees");
    }

    /* ---------------- G3: zap-in -> zap-out round trip, both directions ---------------- */
    function test_G3_zapRoundTrip_noProfit() public {
        _organicFees();
        uint256[3] memory amts = [uint256(1e12), 10e18, 3000e18];
        for (uint256 i; i < 3; ++i) {
            uint256 s = vm.snapshotState();
            tA.mint(attacker, amts[i]);
            vm.startPrank(attacker);
            tA.approve(address(vault), amts[i]);(uint256 sh,) = vault.exchangeIn(IERC20(address(tA)), amts[i], IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);(uint256 out,) = vault.exchangeIn(IERC20(address(vault)), sh, IERC20(address(tA)), 0, attacker, false, block.timestamp + 1);
            vm.stopPrank();
            emit log_named_uint("zap in A", amts[i]);
            emit log_named_uint("  zap out A", out);
            assertLe(out, amts[i], "round trip must not profit");
            vm.revertToState(s);
        }
    }

    /* ---------------- G4: exact-out zap-in cost vs exact-in ---------------- */
    function test_G4_exactOutZapIn_vs_exactIn() public {
        _organicFees();
        uint256 want = aliceShares / 100;
        uint256 s = vm.snapshotState();
        tA.mint(victim, 1000e18);
        vm.startPrank(victim);
        tA.approve(address(vault), type(uint256).max);
        uint256 used = vault.exchangeOut(IERC20(address(tA)), 1000e18, IERC20(address(vault)), want, victim, false, block.timestamp + 1);
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(victim), want, "exact shares");
        assertEq(1000e18 - tA.balanceOf(victim), used, "pulled exactly used");
        vm.revertToState(s);
        tA.mint(victim, used);
        vm.startPrank(victim);
        tA.approve(address(vault), used);(uint256 shIn,) = vault.exchangeIn(IERC20(address(tA)), used, IERC20(address(vault)), 0, victim, false, block.timestamp + 1);
        vm.stopPrank();
        emit log_named_uint("exact-out used A", used);
        emit log_named_uint("exact-out shares", want);
        emit log_named_uint("exact-in shares for same A", shIn);
        assertGe(shIn * 1001, want * 1000, "exact-out overcharges > 0.1% vs exact-in");
    }

    /* ---------------- G5: atomic pretransfer exact-out refund correctness ---------------- */
    function test_G5_atomicPretransfer_refund() public {
        AeroAtomicPrepayer p = new AeroAtomicPrepayer();
        tA.mint(address(p), 100e18);
        uint256 want = aliceShares / 1000;
        uint256 used = p.run(vault, IERC20(address(tA)), 100e18, want);
        emit log_named_uint("used", used);
        assertEq(tA.balanceOf(address(p)), 100e18 - used, "refund = credit - used");
        assertEq(IERC20(address(vault)).balanceOf(address(p)), want, "exact shares");
        uint256 left = tA.balanceOf(address(vault));
        emit log_named_uint("zap residual A left in vault", left);
        // residual must be booked (not claimable by a pretransfer sweeper)
        AeroSweeper sw = new AeroSweeper();
        if (left > 0) {
            vm.expectRevert();
            sw.sweep(vault, IERC20(address(tA)), left, IERC20(address(tB)));
        }
    }

    /* ---------------- G6: exact-out zap-out burns no more shares than exact-in equivalent ---------------- */
    function test_G6_exactOutZapOut_vs_exactIn() public {
        _organicFees();
        uint256 wantA = 10e18;
        uint256 s = vm.snapshotState();
        vm.prank(alice);
        uint256 burned = vault.exchangeOut(IERC20(address(vault)), aliceShares, IERC20(address(tA)), wantA, alice, false, block.timestamp + 1);
        assertGe(tA.balanceOf(alice), wantA, "at least exact A out");
        assertEq(IERC20(address(vault)).balanceOf(alice), aliceShares - burned, "burned exactly");
        vm.revertToState(s);
        vm.prank(alice);(uint256 outIn,) = vault.exchangeIn(IERC20(address(vault)), burned, IERC20(address(tA)), 0, alice, false, block.timestamp + 1);
        emit log_named_uint("exact-out burned shares", burned);
        emit log_named_uint("exact-in A for same shares", outIn);
        assertGe(outIn * 1001, wantA * 1000, "exact-out burns >0.1% more than exact-in");
    }

    /* ---------------- G7: first deposit on unseeded vault (decimalOffset 0) ---------------- */
    function test_G7_firstDeposit_unseeded_inflation() public {
        IStandardExchangeProxy v = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroUnbalancedPool))));
        IERC20 lpT = IERC20(address(aeroUnbalancedPool));
        // LP for actors from the unbalanced pool
        aeroUnbalancedTokenA.mint(address(this), 20_000e18);
        aeroUnbalancedTokenB.mint(address(this), 2_000e18);
        aeroUnbalancedTokenA.approve(address(aerodromeRouter), type(uint256).max);
        aeroUnbalancedTokenB.approve(address(aerodromeRouter), type(uint256).max);
        (,, uint256 atkLp) = aerodromeRouter.addLiquidity(address(aeroUnbalancedTokenA), address(aeroUnbalancedTokenB), false, 10_000e18, 1_000e18, 0, 0, attacker, block.timestamp + 1);
        (,, uint256 vicLp) = aerodromeRouter.addLiquidity(address(aeroUnbalancedTokenA), address(aeroUnbalancedTokenB), false, 4_000e18, 400e18, 0, 0, victim, block.timestamp + 1);
        vm.startPrank(attacker);
        lpT.approve(address(v), type(uint256).max);(uint256 s1,) = v.exchangeIn(lpT, 1, IERC20(address(v)), 0, attacker, false, block.timestamp + 1);
        lpT.transfer(address(v), atkLp - 1); // donation
        vm.stopPrank();
        vm.startPrank(victim);
        lpT.approve(address(v), vicLp);(uint256 vs,) = v.exchangeIn(lpT, vicLp, IERC20(address(v)), 0, victim, false, block.timestamp + 1);
        vm.stopPrank();
        vm.prank(attacker);(uint256 back,) = v.exchangeIn(IERC20(address(v)), s1, lpT, 0, attacker, false, block.timestamp + 1);
        emit log_named_uint("attacker LP in", atkLp);
        emit log_named_uint("attacker LP back", back);
        emit log_named_uint("victim LP in", vicLp);
        emit log_named_uint("victim shares", vs);
        emit log_named_int("attacker net LP", int256(back) - int256(atkLp));
        assertLe(back, atkLp, "inflation not profitable");
    }
}
