// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

interface IV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function mint(address) external returns (uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
}

/// @notice gx-aerodrome-camelot-univ2: UniV2 SE value conservation / JIT / zaps / exact-out / first deposit.
contract UniV2ValueConservation is TestBase_UniswapV2StandardExchange_MultiPool {
    function setUp() public override {
        super.setUp();
        vault = balancedVault;
        pair = IV2Pair(address(uniswapBalancedPair));
        tA = uniswapBalancedTokenA;
        tB = uniswapBalancedTokenB;
        _postSetUp();
    }

    function _amountOut(ERC20PermitMintableStub, uint256 amt, uint256 rin, uint256 rout) internal pure returns (uint256) {
        uint256 f = amt * 997;
        return f * rout / (rin * 1000 + f);
    }

    function _freshVault() internal returns (IStandardExchangeProxy v) {
        // new pair, unseeded vault
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("XA", "XA", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("XB", "XB", 18, address(this), 0);
        pair = IV2Pair(uniswapV2Factory.createPair(address(a), address(b)));
        tA = a; tB = b;
        a.mint(address(pair), 10_000e18); b.mint(address(pair), 10_000e18); pair.mint(address(this));
        v = IStandardExchangeProxy(uniswapV2StandardExchangeDFPkg.deployVault(IUniswapV2Pair(address(pair))));
    }

    address alice = makeAddr("alice");
    address trader = makeAddr("trader");
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");
    IStandardExchangeProxy vault;
    IV2Pair pair;
    ERC20PermitMintableStub tA;
    ERC20PermitMintableStub tB;
    uint256 aliceShares;

    function _postSetUp() internal {
        uint256 lp = _getLp(alice, 2000e18);
        vm.startPrank(alice);
        IERC20(address(pair)).approve(address(vault), lp);(aliceShares,) = vault.exchangeIn(IERC20(address(pair)), lp, IERC20(address(vault)), 1, alice, false, block.timestamp + 1);
        vm.stopPrank();
    }

    /// proportional add of `a` tokenA worth at current reserves, LP minted to `to`
    function _getLp(address to, uint256 a) internal returns (uint256) {
        (uint256 rA, uint256 rB) = _res();
        uint256 b = a * rB / rA + 1;
        tA.mint(address(pair), a);
        tB.mint(address(pair), b);
        return pair.mint(to);
    }

    function _res() internal view returns (uint256 rA, uint256 rB) {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (rA, rB) = pair.token0() == address(tA) ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    function _swap(address who, ERC20PermitMintableStub tIn, uint256 amt) internal returns (uint256 out) {
        (uint256 rA, uint256 rB) = _res();
        (uint256 rin, uint256 rout) = address(tIn) == address(tA) ? (rA, rB) : (rB, rA);
        out = _amountOut(tIn, amt, rin, rout);
        vm.prank(who);
        tIn.transfer(address(pair), amt);
        bool inIs0 = pair.token0() == address(tIn);
        pair.swap(inIs0 ? 0 : out, inIs0 ? out : 0, who, new bytes(0));
    }

    function _organic() internal {
        tA.mint(trader, 3000e18);
        tB.mint(trader, 3000e18);
        for (uint256 i; i < 5; ++i) {
            _swap(trader, tA, 300e18);
            _swap(trader, tB, 300e18);
        }
    }

    function _lpOf(uint256 sh) internal view returns (uint256) {(uint256 quotedAmountOut,) = vault.previewExchangeIn(IERC20(address(vault)), sh, IERC20(address(pair)));
    return quotedAmountOut;
    }

    function test_H1_jitAroundFeeMint_noProfit() public {
        _organic();
        uint256 aliceBefore = _lpOf(aliceShares);
        uint256 lp = _getLp(attacker, 5000e18);
        vm.startPrank(attacker);
        IERC20(address(pair)).approve(address(vault), lp);(uint256 sh,) = vault.exchangeIn(IERC20(address(pair)), lp, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);(uint256 back,) = vault.exchangeIn(IERC20(address(vault)), sh, IERC20(address(pair)), 0, attacker, false, block.timestamp + 1);
        vm.stopPrank();
        emit log_named_uint("attacker LP in", lp);
        emit log_named_uint("attacker LP out", back);
        emit log_named_int("alice LP delta", int256(_lpOf(aliceShares)) - int256(aliceBefore));
        assertLe(back, lp, "JIT no profit");
    }

    function test_H2_zapRoundTrip_noProfit() public {
        _organic();
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

    function test_H3_exactOutZapIn_vs_exactIn() public {
        _organic();// grid-aligned request so Camelot strict equality (known r2 finding) does not mask the comparison
        (uint256 want,) = vault.previewExchangeIn(IERC20(address(tA)), 10e18, IERC20(address(vault)));
        uint256 s = vm.snapshotState();
        tA.mint(victim, 1000e18);
        vm.startPrank(victim);
        tA.approve(address(vault), type(uint256).max);
        try vault.exchangeOut(IERC20(address(tA)), 1000e18, IERC20(address(vault)), want, victim, false, block.timestamp + 1) returns (uint256 used) {
            vm.stopPrank();
            assertEq(IERC20(address(vault)).balanceOf(victim), want, "exact shares");
            assertEq(1000e18 - tA.balanceOf(victim), used, "pulled exactly used");
            emit log_named_uint("exact-out used A for preview(10e18) shares", used);
            assertLe(used, 10e18 + 10e18 / 1000, "exact-out overcharges > 0.1% vs exact-in");
        } catch (bytes memory r) {
            vm.stopPrank();
            emit log_named_bytes("exact-out zap-in reverted (see known r2 strict equality)", r);
        }
        vm.revertToState(s);
    }

    function test_H4_exactOutZapOut_vs_exactIn() public {
        _organic();
        uint256 wantA = 10e18;
        uint256 s = vm.snapshotState();
        vm.prank(alice);
        uint256 burned = vault.exchangeOut(IERC20(address(vault)), aliceShares, IERC20(address(tA)), wantA, alice, false, block.timestamp + 1);
        uint256 got = tA.balanceOf(alice);
        emit log_named_uint("exact-out A delivered", got);
        assertGe(got, wantA, "delivered >= amountOut");
        assertEq(IERC20(address(vault)).balanceOf(alice), aliceShares - burned, "burned exactly");
        vm.revertToState(s);
        vm.prank(alice);(uint256 outIn,) = vault.exchangeIn(IERC20(address(vault)), burned, IERC20(address(tA)), 0, alice, false, block.timestamp + 1);
        emit log_named_uint("exact-out burned shares", burned);
        emit log_named_uint("exact-in A for same shares", outIn);
        assertGe(outIn * 1001, wantA * 1000, "exact-out burns >0.1% more than exact-in");
    }

    function test_H5_feeMintSandwich_attackerLoses() public {
        _organic();
        for (uint256 k; k < 2; ++k) {
            uint256 push = [uint256(1000e18), 5000e18][k];
            uint256 s = vm.snapshotState();
            tA.mint(attacker, push);
            uint256 atkLp = _getLp(attacker, 1e15);
            uint256 gotB = _swap(attacker, tA, push);
            vm.startPrank(attacker);
            IERC20(address(pair)).approve(address(vault), atkLp);(uint256 sh,) = vault.exchangeIn(IERC20(address(pair)), atkLp, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1);
            vm.stopPrank();
            uint256 aBack = _swap(attacker, tB, gotB);
            vm.prank(attacker);(uint256 lpBack,) = vault.exchangeIn(IERC20(address(vault)), sh, IERC20(address(pair)), 0, attacker, false, block.timestamp + 1);
            int256 net = int256(aBack + lpBack * 2) - int256(push + atkLp * 2); // LP ~ 2 tokenA-at-1:1 per unit (balanced)
            emit log_named_uint("push", push);
            emit log_named_int("  attacker net (approx tokenA)", net);
            assertLe(net, 0, "no profit");
            vm.revertToState(s);
        }
    }

    function test_H6_unseededFirstDeposit_donation() public {
        IStandardExchangeProxy v = _freshVault();
        IERC20 lpT = IERC20(address(pair));
        uint256 atkLp = _getLp(attacker, 1000e18);
        uint256 vicLp = _getLp(victim, 400e18);
        vm.startPrank(attacker);
        lpT.approve(address(v), type(uint256).max);(uint256 s1,) = v.exchangeIn(lpT, 1, IERC20(address(v)), 0, attacker, false, block.timestamp + 1);
        lpT.transfer(address(v), atkLp - 1);
        vm.stopPrank();
        vm.startPrank(victim);
        lpT.approve(address(v), vicLp);try v.exchangeIn(lpT, vicLp, IERC20(address(v)), 0, victim, false, block.timestamp + 1) returns (uint256 vs, uint256) {
            vm.stopPrank();
            emit log_named_uint("victim shares", vs);
            vm.prank(attacker);(uint256 back,) = v.exchangeIn(IERC20(address(v)), s1, lpT, 0, attacker, false, block.timestamp + 1);
            emit log_named_int("attacker net LP", int256(back) - int256(atkLp));
            assertLe(back, atkLp, "donation inflation not profitable");
        } catch (bytes memory r) {
            vm.stopPrank();
            emit log_named_bytes("victim deposit reverted", r);
        }
    }
}
