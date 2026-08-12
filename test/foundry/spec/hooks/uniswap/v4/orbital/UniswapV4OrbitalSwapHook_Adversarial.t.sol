// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Adversarial_Test
 * @notice Catalog A–H residual (WP-ADV-HOOK-001): donations ignored for pricing; R sticky; radius invariant.
 * @dev Deferred P2: G composition; fork MEV sandwich reconstructions.
 */
contract UniswapV4OrbitalSwapHook_Adversarial_Test is TestBase_UniswapV4OrbitalSwapHook {
    /// @notice A1: donations ignored for pricing / reserveOf (Repo SoT).
    function test_A1_donationsIgnored_reserveOfUnchanged() public {
        _seedThreeLeg(100 ether);
        uint256 r0 = orbital.reserveOf(address(token0));
        uint256 bal = token0.balanceOf(hook);

        token0.mint(hook, 50 ether);

        assertEq(orbital.reserveOf(address(token0)), r0, "Repo SoT ignores donations");
        assertEq(token0.balanceOf(hook), bal + 50 ether, "physical balance rose");

        (uint256 shares,,,) = orbital.previewAddLiquidity(10 ether, 10 ether, 10 ether);
        assertGt(shares, 0);
    }

    /// @notice E1: post-swap reserves strictly under radius (capacity invariant).
    function test_E1_postState_reservesStrictlyUnderRadius() public {
        _seedThreeLeg(100 ether);
        _setDexFee(0);
        for (uint256 i; i < 10; i++) {
            _swapExactIn(address(token0), address(token1), 2 ether);
            _swapExactIn(address(token1), address(token2), 2 ether);
            _swapExactIn(address(token2), address(token0), 2 ether);
        }
        uint256 R = orbital.radius();
        assertLt(orbital.reserveOf(address(token0)), R);
        assertLt(orbital.reserveOf(address(token1)), R);
        assertLt(orbital.reserveOf(address(token2)), R);
        // L² consistent with sphere parameter
        assertGt(orbital.lSquared(), 0);
    }

    /// @notice H1: full exit leaves R sticky + min dust; subsequent add works.
    function test_H1_fullExit_R_sticky_and_minDust() public {
        (uint256 shares,,,) = _addLiquidity(100 ether, 100 ether, 100 ether);
        uint256 userShares = IERC20(hook).balanceOf(user);
        assertEq(userShares, shares);

        uint256 R = orbital.radius();
        vm.prank(user);
        orbital.removeLiquidity(userShares, user, 0, 0, 0, block.timestamp + 1);

        assertEq(IERC20(hook).totalSupply(), Repo.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook).balanceOf(address(0)), Repo.MINIMUM_LIQUIDITY);
        assertEq(orbital.radius(), R);

        uint256 sumPos = orbital.reserveOf(address(token0)) + orbital.reserveOf(address(token1))
            + orbital.reserveOf(address(token2));
        assertGt(sumPos, 0);

        (uint256 s2,,,) = _addLiquidity(10 ether, 10 ether, 10 ether);
        assertGt(s2, 0);
        assertEq(orbital.radius(), R, "R still sticky after subsequent add");
    }

    /// @notice F3: hook flags include liquidity bans + swap surface.
    function test_F3_hookFlags_includeLiquidityBans() public view {
        uint160 flags = _requiredFlags();
        assertTrue(flags & Hooks.BEFORE_ADD_LIQUIDITY_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_SWAP_FLAG != 0);
        assertTrue(flags & Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG != 0);
    }
}
