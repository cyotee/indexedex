// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4BalancerQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookMath.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Math_Decimals
 * @notice FIX-SCALE extended with 9-dec `baseScaleFromDecimals`.
 */
contract UniswapV4BalancerQuadStableSwapHook_Math_Decimals is Test {
    function test_FIX_SCALE_baseScaleFromDecimals() public pure {
        assertEq(Math.baseScaleFromDecimals(6), 10 ** 30);
        assertEq(Math.baseScaleFromDecimals(9), 10 ** 27);
        assertEq(Math.baseScaleFromDecimals(18), 10 ** 18);
        uint256 scaled9 = Math.scaleTo(1e9, Math.baseScaleFromDecimals(9));
        assertEq(scaled9, 1e18);
        assertEq(Math.descale(scaled9, Math.baseScaleFromDecimals(9)), 1e9);
    }
}
