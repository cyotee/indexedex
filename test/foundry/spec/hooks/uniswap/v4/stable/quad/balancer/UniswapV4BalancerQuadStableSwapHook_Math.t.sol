// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StableMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {
    UniswapV4BalancerQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookMath.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Math_Test
 * @notice Pure Math fixtures: AMP_PRECISION=1e3 and identity with Crane StableMath.
 */
contract UniswapV4BalancerQuadStableSwapHook_Math_Test is Test {
    function _toDyn(uint256[4] memory xp) private pure returns (uint256[] memory b) {
        b = new uint256[](4);
        b[0] = xp[0];
        b[1] = xp[1];
        b[2] = xp[2];
        b[3] = xp[3];
    }

    /// @dev FIX-AMP: product constant is Balancer 1e3, not Curve 100.
    function test_FIX_AMP_precisionIs1e3() public pure {
        assertEq(Math.AMP_PRECISION, 1e3);
        assertTrue(Math.AMP_PRECISION != 100);
    }

    /// @dev FIX-D1: equal balances, |D − S| ≤ 1; matches StableMath.computeInvariant
    function test_FIX_D1_equalBalance_D_near_S_matchesStableMath() public pure {
        uint256 baseAmp = 100;
        uint256 amp = baseAmp * Math.AMP_PRECISION; // 100_000
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256 S = 4e24;
        uint256 D = Math.getD(xp, amp);
        uint256 diff = D > S ? D - S : S - D;
        assertLe(diff, 1, "FIX-D1 |D-S|<=1");
        uint256 Dref = StableMath.computeInvariant(amp, _toDyn(xp));
        assertEq(D, Dref, "FIX-D1 identity with StableMath");
        assertEq(Math.getD(xp, amp), D, "FIX-D1 bit-identical re-run");
    }

    /// @dev FIX-D2: mild imbalance converges; getY/computeBalance preserves D within 1
    function test_FIX_D2_mildImbalance_getY_preservesD() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(2e24), 1e24, 1e24, 1e24];
        uint256 D = Math.getD(xp, amp);
        assertGt(D, 0);

        uint256 xInNew = xp[0] + 1e21;
        uint256 yOut = Math.getY(0, 1, xInNew, xp, amp, D);
        assertLt(yOut, xp[1], "FIX-D2 y decreases");

        uint256[4] memory xp2 = xp;
        xp2[0] = xInNew;
        xp2[1] = yOut;
        uint256 D2 = Math.getD(xp2, amp);
        uint256 diff = D2 > D ? D2 - D : D - D2;
        assertLe(diff, 1, "FIX-D2 reconverge |D'-D|<=1");

        // StableMath.computeBalance identity
        uint256[] memory b = _toDyn(xp);
        b[0] = xInNew;
        uint256 yRef = StableMath.computeBalance(amp, b, D, 1);
        assertEq(yOut, yRef, "FIX-D2 getY == computeBalance");
    }

    /// @dev FIX-Y1: exact-in style via StableMath.computeOutGivenExactIn
    function test_FIX_Y1_exactIn_matchesStableMath() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256 amountInScaled = 1e22;
        uint256[] memory b = _toDyn(xp);
        uint256 inv = StableMath.computeInvariant(amp, b);
        uint256 outRef = StableMath.computeOutGivenExactIn(amp, b, 0, 1, amountInScaled, inv);

        uint256[4] memory reserves = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256[4] memory rates = [uint256(1e18), 1e18, 1e18, 1e18];
        // fee=0 so quote == StableMath raw out (descale identity)
        (uint256 amountOut,) = Math.quoteExactIn(reserves, rates, 0, 1, amountInScaled, amp, 0);
        assertEq(amountOut, outRef, "FIX-Y1 fee0 exact-in == StableMath");
    }

    /// @dev FIX-Y2: exact-out style via StableMath.computeInGivenExactOut
    function test_FIX_Y2_exactOut_matchesStableMath() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory reserves = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256[4] memory rates = [uint256(1e18), 1e18, 1e18, 1e18];
        uint256 amountOut = 1e21;
        uint256[] memory b = _toDyn(reserves);
        uint256 inv = StableMath.computeInvariant(amp, b);
        uint256 inRef = StableMath.computeInGivenExactOut(amp, b, 0, 1, amountOut, inv);

        (uint256 amountIn,) = Math.quoteExactOut(reserves, rates, 0, 1, amountOut, amp, 0);
        assertEq(amountIn, inRef, "FIX-Y2 fee0 exact-out == StableMath");
    }

    /// @dev FIX-FEE1: fee-on-output identities
    function test_FIX_FEE1_feeIdentities() public pure {
        uint24 fee = 500;
        uint256 rawOut = 1_000_000;
        (uint256 userOut, uint256 f) = Math.feeOnOutputExactIn(rawOut, fee);
        assertEq(f, 500);
        assertEq(userOut, rawOut - f);

        uint256 gross = Math.feeOnOutputExactOutGrossUp(userOut, fee);
        assertGe(gross, rawOut - 1);
        (uint256 u2,) = Math.feeOnOutputExactIn(gross, fee);
        assertGe(u2, userOut);
    }

    /// @dev FIX-QUOTE1: fee-on-output exact-in reduces vs fee0
    function test_FIX_QUOTE1_feeReducesExactInOut() public pure {
        uint256 amp = 100 * Math.AMP_PRECISION;
        uint256[4] memory reserves = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256[4] memory rates = [uint256(1e18), 1e18, 1e18, 1e18];
        uint256 amountIn = 1e21;
        (uint256 out0,) = Math.quoteExactIn(reserves, rates, 0, 1, amountIn, amp, 0);
        (uint256 outFee,) = Math.quoteExactIn(reserves, rates, 0, 1, amountIn, amp, 500);
        assertLt(outFee, out0);
        assertGt(outFee, 0);
    }

    function test_FIX_SCALE_baseScaleFromDecimals() public pure {
        assertEq(Math.baseScaleFromDecimals(6), 10 ** 30);
        assertEq(Math.baseScaleFromDecimals(18), 10 ** 18);
    }
}
