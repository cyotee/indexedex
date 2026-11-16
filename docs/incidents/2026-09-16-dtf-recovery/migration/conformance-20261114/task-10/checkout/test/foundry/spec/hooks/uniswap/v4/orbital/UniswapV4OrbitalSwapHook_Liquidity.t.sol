// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";

contract UniswapV4OrbitalSwapHook_Liquidity_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_firstMint_setsRadiusAndMinLiquidity() public {
        uint256 amount = 100 ether;
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) =
            _addLiquidity(amount, amount, amount);

        assertEq(u0, amount);
        assertEq(u1, amount);
        assertEq(u2, amount);
        assertEq(shares, 3 * amount - Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(address(0)), Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20Metadata(hook).decimals(), 18);

        assertEq(orbital.radius(), amount * 10);
        assertGt(orbital.lSquared(), 0);
        assertEq(orbital.reserveOf(address(token0)), amount);
        assertEq(orbital.reserveOf(address(token1)), amount);
        assertEq(orbital.reserveOf(address(token2)), amount);
    }

    function test_firstMint_requiresTwoLegs() public {
        vm.prank(user);
        vm.expectRevert();
        orbital.addLiquidity(100 ether, 0, 0, user, 0, block.timestamp + 1, "");
    }

    function test_previewAdd_bitExact_firstMint() public {
        uint256 a = 50 ether;
        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(a, a, a);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(a, a, a);
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);
    }

    function test_fullBook_threeLeg_previewBitExact() public {
        _seedThreeLeg(200 ether);
        uint256 a = 20 ether;
        (uint256 ps, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(a, a, a);
        (uint256 es, uint256 e0, uint256 e1, uint256 e2) = _addLiquidity(a, a, a);
        assertEq(ps, es);
        assertEq(p0, e0);
        assertEq(p1, e1);
        assertEq(p2, e2);
        assertGt(es, 0);
    }

    function test_fullBook_oneSidedReverts() public {
        _seedThreeLeg(200 ether);
        vm.prank(user);
        vm.expectRevert();
        orbital.addLiquidity(10 ether, 0, 0, user, 0, block.timestamp + 1, "");
    }

    function test_remove_bitExact_andBurnMsgSender() public {
        (uint256 shares,,,) = _addLiquidity(100 ether, 100 ether, 100 ether);
        uint256 half = shares / 2;
        (uint256 p0, uint256 p1, uint256 p2) = orbital.previewRemoveLiquidity(half);

        uint256 b0 = token0.balanceOf(user);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1);
        assertEq(a0, p0);
        assertEq(a1, p1);
        assertEq(a2, p2);
        assertEq(token0.balanceOf(user) - b0, a0);
        assertEq(IERC20(hook).balanceOf(user), shares - half);
    }

    function test_partial_seedOnly_sphereNav_notSumNav() public {
        // First mint with two legs only (token2 = 0) → partial book
        _addLiquidity(100 ether, 100 ether, 0);
        assertEq(orbital.reserveOf(address(token2)), 0);

        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 seed = 50 ether;
        uint256 expected = _sphereNavExpected(supplyBefore, seed);
        uint256 sumNav = (seed * supplyBefore)
            / (orbital.reserveOf(address(token0)) + orbital.reserveOf(address(token1)));
        assertTrue(expected != sumNav, "setup: sphere-NAV must differ from sum-NAV");

        (uint256 predShares, uint256 pred0, uint256 pred1, uint256 pred2) =
            orbital.previewAddLiquidity(0, 0, seed);
        assertEq(pred0 + pred1, 0);
        assertEq(pred2, seed);
        assertEq(predShares, expected);

        (uint256 shares,, uint256 u1, uint256 u2) = _addLiquidity(0, 0, seed);
        assertEq(u1, 0);
        assertEq(u2, seed);
        assertEq(shares, expected);
        assertTrue(shares != sumNav, "D72: must not use sum-NAV");
    }

    function _sphereNavExpected(uint256 supplyBefore, uint256 seed)
        internal
        view
        returns (uint256 expected)
    {
        uint256 R = orbital.radius();
        uint256 r0 = orbital.reserveOf(address(token0));
        uint256 r1 = orbital.reserveOf(address(token1));
        // p_i = R - r_i; zero leg p = R; V_before = Σ p_i r_i; V_in = p_seed * seed
        uint256 vBefore = (R - r0) * r0 + (R - r1) * r1;
        uint256 vIn = R * seed;
        expected = (supplyBefore * vIn) / vBefore;
    }
}
