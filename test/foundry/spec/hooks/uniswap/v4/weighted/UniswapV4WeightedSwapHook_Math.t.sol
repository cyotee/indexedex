// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {WeightedMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title UniswapV4WeightedSwapHook_Math
 * @notice Pure FIX-* math fixtures (no PoolManager). Law: plan §6.9.
 * @dev rootK = V literal asserted in FIX-G1.
 */
contract UniswapV4WeightedSwapHook_Math_Test is Test {
    /* ---------------------------------------------------------------------- */
    /* FIX-S1 scale/descale mixed decimals                                    */
    /* ---------------------------------------------------------------------- */

    function test_FIX_S1_scaleDescalemixedDecimals() public pure {
        uint256 scale6 = Math.baseScaleFromDecimals(6);
        uint256 scale8 = Math.baseScaleFromDecimals(8);
        uint256 scale18 = Math.baseScaleFromDecimals(18);
        // 1e6 raw (6-dec) with rate=1e18 → scaleTo uses baseScale in effectiveRate path
        // unit: amount * baseScale / 1e18 for 6-dec: 1e6 * 10^30 / 1e18 = 1e18
        assertEq(Math.scaleTo(1e6, scale6), 1e18);
        assertEq(Math.scaleTo(1e8, scale8), 1e18);
        assertEq(Math.scaleTo(1e18, scale18), 1e18);
        assertEq(Math.descale(1e18, scale6), 1e6);
        assertEq(Math.descale(1e18, scale18), 1e18);
        // ceil identities
        assertEq(Math.scaleToUp(1, scale18), 1);
        assertGe(Math.descaleUp(1, scale6), Math.descale(1, scale6));
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-V1 n=2 50/50 equal balances                                        */
    /* ---------------------------------------------------------------------- */

    function test_FIX_V1_invariantStable() public pure {
        uint256[] memory w = new uint256[](2);
        w[0] = 5e17;
        w[1] = 5e17;
        uint256[] memory b = new uint256[](2);
        b[0] = 1000e18;
        b[1] = 1000e18;
        uint256 V1 = Math.computeV(w, b);
        uint256 V2 = Math.computeV(w, b);
        assertEq(V1, V2);
        assertGt(V1, 0);
        // peer WeightedMath bit-identical
        assertEq(V1, WeightedMath.computeInvariantDown(w, b));
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-V2 n=4 weights 40/30/20/10                                         */
    /* ---------------------------------------------------------------------- */

    function test_FIX_V2_invariantAndSwapGrowth() public pure {
        uint256[] memory w = new uint256[](4);
        w[0] = 4e17;
        w[1] = 3e17;
        w[2] = 2e17;
        w[3] = 1e17;
        uint256[] memory b = new uint256[](4);
        b[0] = 1000e18;
        b[1] = 900e18;
        b[2] = 800e18;
        b[3] = 700e18;
        uint256 V = Math.computeV(w, b);
        assertGt(V, 0);

        // exact-in fee residual: V' > V after gross in + out drain with fee 0.3%
        uint256 amountIn = 10e18;
        uint256 out = Math.quoteExactIn(
            b[0], w[0], b[1], w[1], amountIn, 1e18, 1e18, 3e15
        );
        uint256[] memory b2 = new uint256[](4);
        b2[0] = b[0] + amountIn; // gross (scaled domain with rate=1)
        b2[1] = b[1] - out;
        b2[2] = b[2];
        b2[3] = b[3];
        uint256 V2 = Math.computeV(w, b2);
        assertGt(V2, V);
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-SW1 exact-in fee=0 matches WeightedMath                            */
    /* ---------------------------------------------------------------------- */

    function test_FIX_SW1_exactInFeeZero() public pure {
        uint256 balIn = 1000e18;
        uint256 balOut = 1000e18;
        uint256 wIn = 5e17;
        uint256 wOut = 5e17;
        uint256 amountIn = 10e18;
        uint256 outHook = Math.quoteExactIn(balIn, wIn, balOut, wOut, amountIn, 1e18, 1e18, 0);
        uint256 outPeer = WeightedMath.computeOutGivenExactIn(balIn, wIn, balOut, wOut, amountIn);
        assertEq(outHook, outPeer);
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-SW2 exact-in fee residual identity                                 */
    /* ---------------------------------------------------------------------- */

    function test_FIX_SW2_exactInFeeResidual() public pure {
        uint256 balIn = 1000e18;
        uint256 balOut = 1000e18;
        uint256 amountIn = 100e18;
        uint256 feeWad = 3e15;
        uint256 net = Math.applyTradingFeeNet(amountIn, feeWad);
        assertEq(net + (amountIn * feeWad) / 1e18, amountIn);
        uint256 out = Math.quoteExactIn(balIn, 5e17, balOut, 5e17, amountIn, 1e18, 1e18, feeWad);
        uint256 outNoFee = Math.quoteExactIn(balIn, 5e17, balOut, 5e17, net, 1e18, 1e18, 0);
        assertEq(out, outNoFee);
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-SW3 exact-out gross-up pool-favoring                               */
    /* ---------------------------------------------------------------------- */

    function test_FIX_SW3_exactOutGrossUp() public pure {
        uint256 balIn = 1000e18;
        uint256 balOut = 1000e18;
        uint256 amountOut = 10e18;
        uint256 feeWad = 3e15;
        uint256 gross = Math.quoteExactOut(balIn, 5e17, balOut, 5e17, amountOut, 1e18, 1e18, feeWad);
        uint256 netPeer = WeightedMath.computeInGivenExactOut(balIn, 5e17, balOut, 5e17, amountOut);
        uint256 expectedGross = Math.grossUpExactOut(netPeer, feeWad);
        assertEq(gross, expectedGross);
        assertGe(gross, netPeer);
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-CAP1 max in ratio                                                  */
    /* ---------------------------------------------------------------------- */

    function test_FIX_CAP1_maxInRatioReverts() public {
        uint256 balIn = 100e18;
        uint256 amountIn = 40e18; // > 30%
        vm.expectRevert();
        this.externalQuoteExactIn(balIn, 5e17, 100e18, 5e17, amountIn, 0);
    }

    function externalQuoteExactIn(
        uint256 balIn,
        uint256 wIn,
        uint256 balOut,
        uint256 wOut,
        uint256 amountIn,
        uint256 feeWad
    ) external pure returns (uint256) {
        return Math.quoteExactIn(balIn, wIn, balOut, wOut, amountIn, 1e18, 1e18, feeWad);
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-G1 growth algebra rootK = V                                        */
    /* ---------------------------------------------------------------------- */

    function test_FIX_G1_protocolLpRootKIsV() public pure {
        uint256 supply = 1_000_000e18;
        // Worked: rootKLast = 1000e18, rootK = 1100e18, ownerFeeShare = 5000 (5% * 100_000)
        uint256 rootKLast = 1000e18;
        uint256 rootK = 1100e18;
        uint256 ownerFeeShare = 5000;
        uint256 lp = Math.protocolLpShares(supply, rootK, rootKLast, ownerFeeShare);
        // num = supply * 100e18
        // den = rootK * 100_000 / 5000 + 100e18 = rootK * 20 + 100e18
        uint256 num = supply * (rootK - rootKLast);
        uint256 den = (rootK * 100_000) / ownerFeeShare + rootK - rootKLast;
        assertEq(lp, num / den);
        assertGt(lp, 0);
        // Assert formula uses rootK as V directly (not cbrt): if we cbrt'd, numbers would differ
        // V values here are already full invariant scale — protocolLpShares must not cbrt.
    }

    /* ---------------------------------------------------------------------- */
    /* FIX-P1 partial interim k                                               */
    /* ---------------------------------------------------------------------- */

    function test_FIX_P1_partialInterimThenFull() public pure {
        uint256[] memory w = new uint256[](3);
        w[0] = 4e17;
        w[1] = 3e17;
        w[2] = 3e17;
        uint256[] memory b = new uint256[](3);
        b[0] = 1000e18;
        b[1] = 1000e18;
        b[2] = 0; // partial
        uint256 k = Math.computeInterimK(w, b);
        assertGt(k, 0);
        // seed third leg
        b[2] = 1000e18;
        uint256 V = Math.computeV(w, b);
        assertGt(V, 0);
        // full book rootK = V
        assertEq(Math.rootKForMode(true, w, b), V);
        b[2] = 0;
        assertEq(Math.rootKForMode(false, w, b), k);
    }

    /* ---------------------------------------------------------------------- */
    /* First mint O2                                                          */
    /* ---------------------------------------------------------------------- */

    function test_O2_firstMintShares() public pure {
        uint256[] memory w = new uint256[](2);
        w[0] = 5e17;
        w[1] = 5e17;
        uint256[] memory b = new uint256[](2);
        b[0] = 1000e18;
        b[1] = 1000e18;
        (uint256 shares, uint256 V) = Math.firstMintSharesFull(w, b);
        assertEq(shares, V - Math.MINIMUM_LIQUIDITY);
    }

    function test_feeOverridePips() public pure {
        uint24 pips = Math.feeOverridePips(3e15);
        assertEq(uint256(pips) & 0x400000, 0x400000);
        assertEq(uint256(pips) & 0x3FFFFF, 3000); // 0.3% in pips
    }
}
