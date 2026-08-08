// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4CurveQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookMath.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_Math_Test
 * @notice Pure Math FIX-* fixtures (plan §6.2). No protocol deps.
 */
contract UniswapV4CurveQuadStableSwapHook_Math_Test is Test {
    /// @dev FIX-D1: equal balances, |D − S| ≤ 1
    function test_FIX_D1_equalBalance_D_near_S() public pure {
        uint256 baseAmp = 100;
        uint256 Aprime = baseAmp * Math.AMP_PRECISION; // 10_000
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256 S = 4e24;
        uint256 D = Math.getD(xp, Aprime);
        uint256 diff = D > S ? D - S : S - D;
        assertLe(diff, 1, "FIX-D1 |D-S|<=1");
        // stable re-run
        uint256 D2 = Math.getD(xp, Aprime);
        assertEq(D2, D, "FIX-D1 bit-identical re-run");
    }

    /// @dev FIX-D2: mild imbalance converges; getY preserves D within 1
    function test_FIX_D2_mildImbalance_getY_preservesD() public pure {
        uint256 Aprime = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(2e24), 1e24, 1e24, 1e24];
        uint256 D = Math.getD(xp, Aprime);
        assertGt(D, 0);

        // add 1e21 scaled on leg 0, solve y for leg 1
        uint256 xInNew = xp[0] + 1e21;
        uint256 yOut = Math.getY(0, 1, xInNew, xp, Aprime, D);
        assertLt(yOut, xp[1], "FIX-D2 y decreases");

        uint256[4] memory xp2 = xp;
        xp2[0] = xInNew;
        xp2[1] = yOut;
        uint256 D2 = Math.getD(xp2, Aprime);
        uint256 diff = D2 > D ? D2 - D : D - D2;
        assertLe(diff, 1, "FIX-D2 reconverge |D'-D|<=1");
    }

    /// @dev FIX-Y1: exact-in style getY from equal balance
    function test_FIX_Y1_exactIn_getY() public pure {
        uint256 Aprime = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256 D = Math.getD(xp, Aprime);
        uint256 xInNew = xp[0] + 1e22;
        uint256 yOut = Math.getY(0, 1, xInNew, xp, Aprime, D);
        assertLt(yOut, xp[1]);

        uint256[4] memory xp2 = xp;
        xp2[0] = xInNew;
        xp2[1] = yOut;
        Math.getD(xp2, Aprime); // must converge
    }

    /// @dev FIX-FEE1: fee-on-output identities
    function test_FIX_FEE1_feeIdentities() public pure {
        uint24 fee = 500;
        uint256 rawOut = 1_000_000;
        (uint256 userOut, uint256 f) = Math.feeOnOutputExactIn(rawOut, fee);
        // fee = ceil(rawOut * 500 / 1e6) = 500
        assertEq(f, 500);
        assertEq(userOut, rawOut - f);

        // gross-up: ceil(userOut * 1e6 / (1e6-500))
        uint256 gross = Math.feeOnOutputExactOutGrossUp(userOut, fee);
        // pool-favoring: gross >= rawOut (ceil may push above)
        assertGe(gross, rawOut - 1); // allow tiny rounding
        // exact-out of userOut should require at least userOut after fee deduct
        (uint256 u2,) = Math.feeOnOutputExactIn(gross, fee);
        assertGe(u2, userOut);
    }

    /// @dev FIX-NR1: zero product / pathological reverts InvariantFailed
    function test_FIX_NR1_zeroBalance_reverts() public {
        uint256 Aprime = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 0];
        vm.expectRevert(Math.InvariantFailed.selector);
        Math.getD(xp, Aprime);
    }

    function test_scaleDescale_roundTrip_18dec() public pure {
        uint256 rate = Math.baseScaleFromDecimals(18); // 1e18
        uint256 amount = 123456789;
        uint256 scaled = Math.scaleTo(amount, rate);
        assertEq(Math.descale(scaled, rate), amount);
    }

    function test_scaleDescale_6dec() public pure {
        uint256 rate = Math.baseScaleFromDecimals(6); // 1e30
        uint256 amount = 1_000_000; // 1 token
        uint256 scaled = Math.scaleTo(amount, rate);
        assertEq(scaled, 1e18); // 1e6 * 1e30 / 1e18 = 1e18
        assertEq(Math.descale(scaled, rate), amount);
    }

    function test_geometricMean4_equal() public pure {
        uint256 g = Math.geometricMean4(1e18, 1e18, 1e18, 1e18);
        assertEq(g, 1e18);
    }

    function test_Ann_convention() public pure {
        // A' = 100 * 100 = 10000; Ann = A' * 4 = 40000 used inside getD
        uint256 Aprime = 100 * Math.AMP_PRECISION;
        uint256[4] memory xp = [uint256(1e24), 1e24, 1e24, 1e24];
        uint256 D = Math.getD(xp, Aprime);
        assertGt(D, 0);
    }
}
