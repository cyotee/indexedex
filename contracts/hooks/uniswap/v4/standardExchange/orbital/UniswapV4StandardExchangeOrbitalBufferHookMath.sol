// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookMath
 * @notice Pure sphere, WAD, shares, sphere-NAV, growth fee, zap-split helpers.
 * @dev No SE / RP external calls. Domain is 1e18 effective reserves.
 */
library UniswapV4StandardExchangeOrbitalBufferHookMath {
    using FixedPointMathLib for uint256;

    error MathDomain();
    error ZeroOut();
    error Drain();

    uint256 internal constant WAD = 1e18;

    function toWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function fromWadFloor(uint256 amountWad, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amountWad;
        if (decimals < 18) return amountWad / (10 ** (18 - decimals));
        return amountWad * (10 ** (decimals - 18));
    }

    function fromWadCeil(uint256 amountWad, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amountWad;
        if (decimals < 18) {
            uint256 scale = 10 ** (18 - decimals);
            return (amountWad + scale - 1) / scale;
        }
        return amountWad * (10 ** (decimals - 18));
    }

    function recomputeL2(uint256 R, uint256 xWad, uint256 yWad, uint256 zWad)
        internal
        pure
        returns (uint256)
    {
        if (R == 0) return 0;
        if (xWad >= R || yWad >= R || zWad >= R) revert MathDomain();
        uint256 dx = R - xWad;
        uint256 dy = R - yWad;
        uint256 dz = R - zWad;
        return dx * dx + dy * dy + dz * dz;
    }

    function sphereExactInOutWad(
        uint256 R,
        uint256 L2,
        uint256 xWad,
        uint256 yWad,
        uint256 zWad,
        uint256 dxNetWad
    ) internal pure returns (uint256 dyWad) {
        if (R == 0 || dxNetWad == 0) revert MathDomain();
        if (xWad >= R || yWad >= R || zWad >= R) revert MathDomain();
        uint256 xPrime = xWad + dxNetWad;
        if (xPrime >= R) revert MathDomain();
        uint256 rx = R - xPrime;
        uint256 rz = R - zWad;
        uint256 sub = rx * rx + rz * rz;
        if (L2 < sub) revert MathDomain();
        uint256 T = L2 - sub;
        uint256 sqrtT = T.sqrt();
        if (sqrtT >= R) revert MathDomain();
        uint256 yPrime = R - sqrtT;
        if (!(yPrime > 0 && yPrime < yWad)) revert MathDomain();
        dyWad = yWad - yPrime;
        if (dyWad == 0) revert ZeroOut();
    }

    function sphereExactOutInNetWad(
        uint256 R,
        uint256 L2,
        uint256 xWad,
        uint256 yWad,
        uint256 zWad,
        uint256 dyWad
    ) internal pure returns (uint256 dxNetWad) {
        if (R == 0 || dyWad == 0) revert MathDomain();
        if (xWad >= R || yWad >= R || zWad >= R) revert MathDomain();
        if (dyWad >= yWad) revert Drain();
        uint256 yPrime = yWad - dyWad;
        if (yPrime == 0) revert Drain();
        uint256 ry = R - yPrime;
        uint256 rz = R - zWad;
        uint256 sub = ry * ry + rz * rz;
        if (L2 < sub) revert MathDomain();
        uint256 T = L2 - sub;
        uint256 sqrtT = T.sqrt();
        if (sqrtT >= R) revert MathDomain();
        uint256 xPrime = R - sqrtT;
        if (xPrime <= xWad) revert MathDomain();
        dxNetWad = xPrime - xWad;
        if (dxNetWad == 0) revert ZeroOut();
    }

    function applyTradingFeeNet(uint256 amountWad, uint256 feeWad)
        internal
        pure
        returns (uint256 netWad)
    {
        if (feeWad >= WAD) revert MathDomain();
        if (feeWad == 0) return amountWad;
        uint256 feeAmt = (amountWad * feeWad) / WAD;
        netWad = amountWad - feeAmt;
    }

    function grossUpExactOut(uint256 netWad, uint256 feeWad) internal pure returns (uint256 grossWad) {
        if (feeWad >= WAD) revert MathDomain();
        if (feeWad == 0) return netWad;
        grossWad = (netWad * WAD) / (WAD - feeWad) + 1;
    }

    function feeOverridePips(uint256 feeWad) internal pure returns (uint24) {
        return uint24(uint256(feeWad * 1e6 / WAD) | 0x400000);
    }

    function firstMintShares(uint256 sumWad) internal pure returns (uint256 shares) {
        if (sumWad <= Repo.MINIMUM_LIQUIDITY) revert MathDomain();
        shares = sumWad - Repo.MINIMUM_LIQUIDITY;
    }

    function firstMintRadius(uint256 a0Wad, uint256 a1Wad, uint256 a2Wad)
        internal
        pure
        returns (uint256 R)
    {
        uint256 m = a0Wad;
        if (a1Wad > m) m = a1Wad;
        if (a2Wad > m) m = a2Wad;
        if (m == 0) revert MathDomain();
        R = m * Repo.R_SAFETY_MULTIPLIER;
    }

    function fullBookShares(
        uint256 a0MaxWad,
        uint256 a1MaxWad,
        uint256 a2MaxWad,
        uint256 r0Wad,
        uint256 r1Wad,
        uint256 r2Wad,
        uint256 supply
    ) internal pure returns (uint256 shares) {
        if (supply == 0 || r0Wad == 0 || r1Wad == 0 || r2Wad == 0) revert MathDomain();
        uint256 s0 = (a0MaxWad * supply) / r0Wad;
        uint256 s1 = (a1MaxWad * supply) / r1Wad;
        uint256 s2 = (a2MaxWad * supply) / r2Wad;
        shares = s0;
        if (s1 < shares) shares = s1;
        if (s2 < shares) shares = s2;
        if (shares == 0) revert MathDomain();
    }

    function fullBookUsedWad(uint256 shares, uint256 rWad, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        return (shares * rWad) / supply;
    }

    function sphereSpotWeight(uint256 R, uint256 rWad) internal pure returns (uint256) {
        if (R == 0) revert MathDomain();
        if (rWad >= R) revert MathDomain();
        return R - rWad;
    }

    function sphereNavShares(
        uint256 supply,
        uint256 R,
        uint256 r0Wad,
        uint256 r1Wad,
        uint256 r2Wad,
        uint256 used0Wad,
        uint256 used1Wad,
        uint256 used2Wad
    ) internal pure returns (uint256 shares) {
        if (supply == 0 || R == 0) revert MathDomain();
        uint256 p0 = sphereSpotWeight(R, r0Wad);
        uint256 p1 = sphereSpotWeight(R, r1Wad);
        uint256 p2 = sphereSpotWeight(R, r2Wad);
        uint256 vBefore = p0 * r0Wad + p1 * r1Wad + p2 * r2Wad;
        if (vBefore == 0) revert MathDomain();
        uint256 vIn = p0 * used0Wad + p1 * used1Wad + p2 * used2Wad;
        shares = (supply * vIn) / vBefore;
        if (shares == 0) revert MathDomain();
    }

    function protocolLpShares(
        uint256 supply,
        uint256 rootK,
        uint256 rootKLast,
        uint256 ownerFeeShare
    ) internal pure returns (uint256) {
        if (supply == 0 || rootKLast == 0 || rootK <= rootKLast || ownerFeeShare == 0) {
            return 0;
        }
        uint256 num = supply * (rootK - rootKLast);
        uint256 den = (rootK * Repo.FEE_DENOMINATOR) / ownerFeeShare + rootK - rootKLast;
        if (den == 0) return 0;
        return num / den;
    }

    function cbrt(uint256 x) internal pure returns (uint256) {
        return FixedPointMathLib.cbrt(x);
    }

    /// @dev Packed args for zapSplitWad (avoids stack-too-deep at call sites without viaIR).
    struct ZapSplitArgs {
        uint256 e0;
        uint256 e1;
        uint256 e2;
        uint256 R;
        uint256 L2;
        uint256 feeWad;
        uint8 inIdx;
        uint256 amountInWad;
    }

    /// @dev Packed result for zapSplitWad.
    struct ZapSplitResult {
        uint256 sJWad;
        uint256 sKWad;
        uint256 aInWad;
        uint256 aJWad;
        uint256 aKWad;
    }

    /// @dev WAD legs for full-book share math (memory packs stack).
    struct FullBookArgs {
        uint256 a0Wad;
        uint256 a1Wad;
        uint256 a2Wad;
        uint256 e0Wad;
        uint256 e1Wad;
        uint256 e2Wad;
        uint256 supply;
    }

    /// @dev WAD legs for sphere-NAV partial shares.
    struct SphereNavArgs {
        uint256 supply;
        uint256 R;
        uint256 r0Wad;
        uint256 r1Wad;
        uint256 r2Wad;
        uint256 used0Wad;
        uint256 used1Wad;
        uint256 used2Wad;
    }

    /**
     * @notice Zap split in WAD: sequential exact-in j then k; residual + outs proportional to e (D41c).
     * @dev Binary-search residualWad (≤64). Sales budget split by eJ:eK. Pure — no SE/RP.
     *      Returns sales of token i toward j and k, residual a_i, and sphere outs for j/k.
     *      Prefer `zapSplitWad(ZapSplitArgs)` at call sites under legacy codegen.
     */
    function zapSplitWad(
        uint256 e0,
        uint256 e1,
        uint256 e2,
        uint256 R,
        uint256 L2,
        uint256 feeWad,
        uint8 inIdx,
        uint256 amountInWad
    )
        internal
        pure
        returns (uint256 sJWad, uint256 sKWad, uint256 aInWad, uint256 aJWad, uint256 aKWad)
    {
        ZapSplitArgs memory a;
        a.e0 = e0;
        a.e1 = e1;
        a.e2 = e2;
        a.R = R;
        a.L2 = L2;
        a.feeWad = feeWad;
        a.inIdx = inIdx;
        a.amountInWad = amountInWad;
        ZapSplitResult memory r = zapSplitWad(a);
        return (r.sJWad, r.sKWad, r.aInWad, r.aJWad, r.aKWad);
    }

    /// @dev Fixed legs for residual binary search (avoids 14-arg _evalResidual stack).
    struct ResidualSearchCtx {
        ZapSplitArgs a;
        uint8 j;
        uint8 k;
        uint256 eIn;
        uint256 eJ;
        uint256 eK;
    }

    struct EvalResidualResult {
        bool ok;
        uint256 sJWad;
        uint256 sKWad;
        uint256 aJWad;
        uint256 aKWad;
        int256 cmp;
    }

    /// @notice Packed entry for zap split (single memory pointer in/out — stack-safe call sites).
    function zapSplitWad(ZapSplitArgs memory a) internal pure returns (ZapSplitResult memory r) {
        if (a.amountInWad < 3 || a.e0 == 0 || a.e1 == 0 || a.e2 == 0 || a.R == 0) revert MathDomain();
        ResidualSearchCtx memory c;
        c.a = a;
        (c.j, c.k) = _otherIndices(a.inIdx);
        c.eIn = _pick(a.e0, a.e1, a.e2, a.inIdx);
        c.eJ = _pick(a.e0, a.e1, a.e2, c.j);
        c.eK = _pick(a.e0, a.e1, a.e2, c.k);
        if (c.eIn == 0 || c.eJ == 0 || c.eK == 0) revert MathDomain();

        // residual ∈ (0, amountIn); search so residual/eIn ≈ outJ/eJ ≈ outK/eK after sequential sales.
        uint256 lo = 1;
        uint256 hi = a.amountInWad - 2;
        bool found;
        for (uint256 iter; iter < 64; ++iter) {
            if (lo > hi) break;
            uint256 residual = (lo + hi) / 2;
            EvalResidualResult memory ev = _evalResidual(c, residual);
            if (!ev.ok) {
                // too aggressive sales or domain — increase residual (sell less)
                lo = residual + 1;
                continue;
            }
            found = true;
            r.sJWad = ev.sJWad;
            r.sKWad = ev.sKWad;
            r.aInWad = residual;
            r.aJWad = ev.aJWad;
            r.aKWad = ev.aKWad;
            if (ev.cmp > 0) {
                // residual ratio high vs outs → sell more (lower residual)
                if (residual == 0) break;
                hi = residual - 1;
            } else if (ev.cmp < 0) {
                lo = residual + 1;
            } else {
                break; // matched
            }
        }
        if (!found || r.aInWad == 0 || r.aJWad == 0 || r.aKWad == 0 || r.sJWad == 0 || r.sKWad == 0) {
            revert MathDomain();
        }
    }

    function fullBookShares(FullBookArgs memory a) internal pure returns (uint256 shares) {
        if (a.supply == 0 || a.e0Wad == 0 || a.e1Wad == 0 || a.e2Wad == 0) revert MathDomain();
        uint256 s0 = (a.a0Wad * a.supply) / a.e0Wad;
        uint256 s1 = (a.a1Wad * a.supply) / a.e1Wad;
        uint256 s2 = (a.a2Wad * a.supply) / a.e2Wad;
        shares = s0;
        if (s1 < shares) shares = s1;
        if (s2 < shares) shares = s2;
        if (shares == 0) revert MathDomain();
    }

    function sphereNavShares(SphereNavArgs memory a) internal pure returns (uint256 shares) {
        if (a.supply == 0 || a.R == 0) revert MathDomain();
        uint256 p0 = sphereSpotWeight(a.R, a.r0Wad);
        uint256 p1 = sphereSpotWeight(a.R, a.r1Wad);
        uint256 p2 = sphereSpotWeight(a.R, a.r2Wad);
        uint256 vBefore = p0 * a.r0Wad + p1 * a.r1Wad + p2 * a.r2Wad;
        if (vBefore == 0) revert MathDomain();
        uint256 vIn = p0 * a.used0Wad + p1 * a.used1Wad + p2 * a.used2Wad;
        shares = (a.supply * vIn) / vBefore;
        if (shares == 0) revert MathDomain();
    }

    /// @dev cmp > 0 residual too large vs outs; < 0 residual too small; 0 matched within 1e-6 relative (WAD/1e6).
    function _evalResidual(ResidualSearchCtx memory c, uint256 residual)
        private
        pure
        returns (EvalResidualResult memory r)
    {
        if (residual == 0 || residual >= c.a.amountInWad) return r;
        uint256 budget = c.a.amountInWad - residual;
        uint256 den = c.eJ + c.eK;
        r.sJWad = (budget * c.eJ) / den;
        r.sKWad = budget - r.sJWad;
        if (r.sJWad == 0 || r.sKWad == 0) return r;

        if (!_fillSequentialOuts(c, r)) return r;
        r.ok = true;
        r.cmp = _compareResidualRatios(c, residual, r.aJWad, r.aKWad);
    }

    /// @dev First swap in→j then in→k; writes aJWad/aKWad into r. Returns false on domain failure.
    function _fillSequentialOuts(ResidualSearchCtx memory c, EvalResidualResult memory r)
        private
        pure
        returns (bool ok)
    {
        uint256 outJ = _firstLegOut(c, r.sJWad);
        if (outJ == 0) return false;

        uint256 x = _pick(c.a.e0, c.a.e1, c.a.e2, c.a.inIdx);
        uint256 eIn2 = x + r.sJWad;
        uint256 eJ2 = c.eJ - outJ;
        if (eIn2 >= c.a.R || eJ2 == 0) return false;

        uint256 outK = _secondLegOut(c, r.sKWad, eIn2, eJ2);
        if (outK == 0) return false;

        r.aJWad = outJ;
        r.aKWad = outK;
        return true;
    }

    function _firstLegOut(ResidualSearchCtx memory c, uint256 sJWad) private pure returns (uint256 outJ) {
        uint256 x = _pick(c.a.e0, c.a.e1, c.a.e2, c.a.inIdx);
        uint256 netJ = applyTradingFeeNet(sJWad, c.a.feeWad);
        SphereLegsWad memory legs;
        legs.R = c.a.R;
        legs.L2 = c.a.L2;
        legs.xWad = x;
        legs.yWad = c.eJ;
        legs.zWad = c.eK; // witness for first swap in→j is k
        (bool okJ, uint256 dy) = _tryExactInPacked(legs, netJ);
        if (okJ) outJ = dy;
    }

    function _secondLegOut(
        ResidualSearchCtx memory c,
        uint256 sKWad,
        uint256 eIn2,
        uint256 eJ2
    ) private pure returns (uint256 outK) {
        uint256 L2b = _l2AfterFirstSale(c, eIn2, eJ2);
        uint256 netK = applyTradingFeeNet(sKWad, c.a.feeWad);
        SphereLegsWad memory legs;
        legs.R = c.a.R;
        legs.L2 = L2b;
        legs.xWad = eIn2;
        legs.yWad = c.eK;
        legs.zWad = eJ2; // witness j
        (bool okK, uint256 dy) = _tryExactInPacked(legs, netK);
        if (okK) outK = dy;
    }

    /// @dev Sphere legs for try-exact-in (shared shape with Target packing).
    struct SphereLegsWad {
        uint256 R;
        uint256 L2;
        uint256 xWad;
        uint256 yWad;
        uint256 zWad;
    }

    function _tryExactInPacked(SphereLegsWad memory s, uint256 dxNetWad)
        private
        pure
        returns (bool ok, uint256 dyWad)
    {
        if (s.R == 0 || dxNetWad == 0) return (false, 0);
        if (s.xWad >= s.R || s.yWad >= s.R || s.zWad >= s.R) return (false, 0);
        uint256 xPrime = s.xWad + dxNetWad;
        if (xPrime >= s.R) return (false, 0);
        uint256 rx = s.R - xPrime;
        uint256 rz = s.R - s.zWad;
        uint256 sub = rx * rx + rz * rz;
        if (s.L2 < sub) return (false, 0);
        uint256 sqrtT = (s.L2 - sub).sqrt();
        if (sqrtT >= s.R) return (false, 0);
        uint256 yPrime = s.R - sqrtT;
        if (!(yPrime > 0 && yPrime < s.yWad)) return (false, 0);
        dyWad = s.yWad - yPrime;
        if (dyWad == 0) return (false, 0);
        return (true, dyWad);
    }

    function _l2AfterFirstSale(ResidualSearchCtx memory c, uint256 eIn2, uint256 eJ2)
        private
        pure
        returns (uint256)
    {
        uint256 e0b = c.a.e0;
        uint256 e1b = c.a.e1;
        uint256 e2b = c.a.e2;
        if (c.a.inIdx == 0) e0b = eIn2;
        else if (c.a.inIdx == 1) e1b = eIn2;
        else e2b = eIn2;
        if (c.j == 0) e0b = eJ2;
        else if (c.j == 1) e1b = eJ2;
        else e2b = eJ2;
        return recomputeL2(c.a.R, e0b, e1b, e2b);
    }

    function _compareResidualRatios(
        ResidualSearchCtx memory c,
        uint256 residual,
        uint256 outJ,
        uint256 outK
    ) private pure returns (int256 cmp) {
        // residual/eIn ? outJ/eJ  → residual * eJ ? outJ * eIn
        uint256 left = residual * c.eJ;
        uint256 right = outJ * c.eIn;
        uint256 tol = right / 1_000_000;
        if (tol == 0) tol = 1;
        if (left > right + tol) return 1;
        if (right > left + tol) return -1;
        // also check outJ/eJ vs outK/eK
        uint256 left2 = outJ * c.eK;
        uint256 right2 = outK * c.eJ;
        uint256 tol2 = right2 / 1_000_000;
        if (tol2 == 0) tol2 = 1;
        if (left2 > right2 + tol2) return 1;
        if (right2 > left2 + tol2) return -1;
        return 0;
    }

    function _otherIndices(uint8 inIdx) private pure returns (uint8 j, uint8 k) {
        if (inIdx == 0) return (1, 2);
        if (inIdx == 1) return (0, 2);
        return (0, 1);
    }

    function _pick(uint256 a0, uint256 a1, uint256 a2, uint8 i) private pure returns (uint256) {
        if (i == 0) return a0;
        if (i == 1) return a1;
        return a2;
    }
}
