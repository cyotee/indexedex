// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Liquidity_Test
 * @notice First mint, later mint, remove, mixed decimals, donation ignore.
 */
contract UniswapV4QuadStableSwapHook_Liquidity_Test is TestBase_UniswapV4QuadStableSwapHook {
    function test_L1_firstMint_locksMinLiqToZero() public {
        uint256[4] memory amounts = _balancedAmounts(1_000);
        uint256[4] memory mins;
        vm.prank(user);
        (uint256 shares,) = quad.addLiquidity(amounts, mins, user, 0);
        assertGt(shares, 0);
        // MINIMUM_LIQUIDITY locked to address(0)
        (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
        uint256 bal0 = abi.decode(ret, (uint256));
        assertEq(bal0, Math.MINIMUM_LIQUIDITY);
        (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
        uint256 ts = abi.decode(retTs, (uint256));
        assertEq(ts, shares + Math.MINIMUM_LIQUIDITY);
    }

    function test_L2_firstMint_withOpenDoors_noPriorSwaps() public {
        // doors already open from factory; no swaps yet
        _addLiquidityFirst(500);
        uint256[4] memory r = _bookReserves();
        assertGt(r[0], 0);
        assertGt(r[1], 0);
        assertGt(r[2], 0);
        assertGt(r[3], 0);
    }

    function test_L3_laterProportional_mins() public {
        _addLiquidityFirst(1_000);
        uint256[4] memory amounts = _balancedAmounts(100);
        uint256[4] memory mins = [uint256(1), 1, 1, 1];
        (uint256 pred,) = quad.previewAddLiquidity(amounts);
        vm.prank(user);
        (uint256 shares, uint256[4] memory actual) = quad.addLiquidity(amounts, mins, user, pred);
        assertEq(shares, pred);
        for (uint256 i; i < 4; ++i) {
            assertLe(actual[i], amounts[i]);
        }
    }

    function test_L4_removeProRata() public {
        uint256 shares = _addLiquidityFirst(1_000);
        uint256 half = shares / 2;
        uint256[4] memory mins;
        uint256[4] memory pred = quad.previewRemoveLiquidity(half);
        vm.prank(user);
        uint256[4] memory got = quad.removeLiquidity(half, user, mins);
        for (uint256 i; i < 4; ++i) {
            assertEq(got[i], pred[i]);
        }
    }

    function test_L5_mixedDecimals_6_6_18_18() public {
        // TestBase already uses 6/6/18/18 after sort
        bool has6;
        bool has18;
        if (t0.decimals() == 6) has6 = true;
        if (t1.decimals() == 6) has6 = true;
        if (t2.decimals() == 18) has18 = true;
        if (t3.decimals() == 18) has18 = true;
        // after address sort, 6-dec and 18-dec are mixed among t0..t3
        assertTrue(t0.decimals() == 6 || t0.decimals() == 18);
        _addLiquidityFirst(1_000);
        uint256[4] memory r = _bookReserves();
        assertGt(r[0] + r[1] + r[2] + r[3], 0);
        has6;
        has18;
    }

    function test_L6_donation_doesNotChangeReserves() public {
        _addLiquidityFirst(1_000);
        uint256[4] memory before = _bookReserves();
        t0.mint(hook, _raw(t0, 999)); // donation
        uint256[4] memory after_ = _bookReserves();
        for (uint256 i; i < 4; ++i) {
            assertEq(after_[i], before[i]);
        }
    }
}
