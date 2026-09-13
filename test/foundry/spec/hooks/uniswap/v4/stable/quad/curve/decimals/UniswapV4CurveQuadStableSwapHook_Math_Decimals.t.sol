// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4CurveQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookMath.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_Math_Decimals
 * @notice Scale/descale extended with 9-dec. Gold 6-dec and 18-dec round-trips remain.
 */
contract UniswapV4CurveQuadStableSwapHook_Math_Decimals is Test {
    function test_FIX_SCALE_baseScaleFromDecimals() public pure {
        assertEq(Math.baseScaleFromDecimals(6), 10 ** 30);
        assertEq(Math.baseScaleFromDecimals(9), 10 ** 27);
        assertEq(Math.baseScaleFromDecimals(18), 10 ** 18);
    }

    function test_scaleDescale_roundTrip_18dec() public pure {
        uint256 rate = Math.baseScaleFromDecimals(18);
        uint256 amount = 123456789;
        uint256 scaled = Math.scaleTo(amount, rate);
        assertEq(Math.descale(scaled, rate), amount);
    }

    function test_scaleDescale_6dec() public pure {
        uint256 rate = Math.baseScaleFromDecimals(6);
        uint256 amount = 1_000_000;
        uint256 scaled = Math.scaleTo(amount, rate);
        assertEq(scaled, 1e18);
        assertEq(Math.descale(scaled, rate), amount);
    }

    function test_scaleDescale_9dec() public pure {
        uint256 rate = Math.baseScaleFromDecimals(9);
        uint256 amount = 1_000_000_000;
        uint256 scaled = Math.scaleTo(amount, rate);
        assertEq(scaled, 1e18);
        assertEq(Math.descale(scaled, rate), amount);
    }
}
