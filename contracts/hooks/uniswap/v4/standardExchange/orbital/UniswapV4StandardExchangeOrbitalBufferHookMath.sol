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

    /**
     * @notice Zap split in WAD: sequential exact-in j then k; residual + outs proportional to e (D41c).
     * @dev Binary-search residualWad (≤64). Sales budget split by eJ:eK. Pure — no SE/RP.
     *      Returns sales of token i toward j and k, residual a_i, and sphere outs for j/k.
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
        if (amountInWad < 3 || e0 == 0 || e1 == 0 || e2 == 0 || R == 0) revert MathDomain();
        (uint8 j, uint8 k) = _otherIndices(inIdx);
        uint256 eIn = _pick(e0, e1, e2, inIdx);
        uint256 eJ = _pick(e0, e1, e2, j);
        uint256 eK = _pick(e0, e1, e2, k);
        if (eIn == 0 || eJ == 0 || eK == 0) revert MathDomain();

        // residual ∈ (0, amountIn); search so residual/eIn ≈ outJ/eJ ≈ outK/eK after sequential sales.
        uint256 lo = 1;
        uint256 hi = amountInWad - 2;
        bool found;
        for (uint256 iter; iter < 64; ++iter) {
            if (lo > hi) break;
            uint256 residual = (lo + hi) / 2;
            (bool ok, uint256 sj, uint256 sk, uint256 oj, uint256 ok_, int256 cmp) = _evalResidual(
                e0, e1, e2, R, L2, feeWad, inIdx, j, k, eIn, eJ, eK, amountInWad, residual
            );
            if (!ok) {
                // too aggressive sales or domain — increase residual (sell less)
                lo = residual + 1;
                continue;
            }
            found = true;
            sJWad = sj;
            sKWad = sk;
            aInWad = residual;
            aJWad = oj;
            aKWad = ok_;
            if (cmp > 0) {
                // residual ratio high vs outs → sell more (lower residual)
                if (residual == 0) break;
                hi = residual - 1;
            } else if (cmp < 0) {
                lo = residual + 1;
            } else {
                break; // matched
            }
        }
        if (!found || aInWad == 0 || aJWad == 0 || aKWad == 0 || sJWad == 0 || sKWad == 0) {
            revert MathDomain();
        }
    }

    /// @dev cmp > 0 residual too large vs outs; < 0 residual too small; 0 matched within 1e-6 relative (WAD/1e6).
    function _evalResidual(
        uint256 e0,
        uint256 e1,
        uint256 e2,
        uint256 R,
        uint256 L2,
        uint256 feeWad,
        uint8 inIdx,
        uint8 j,
        uint8 k,
        uint256 eIn,
        uint256 eJ,
        uint256 eK,
        uint256 amountInWad,
        uint256 residual
    )
        private
        pure
        returns (bool ok, uint256 sJWad, uint256 sKWad, uint256 aJWad, uint256 aKWad, int256 cmp)
    {
        if (residual == 0 || residual >= amountInWad) return (false, 0, 0, 0, 0, 0);
        uint256 budget = amountInWad - residual;
        uint256 den = eJ + eK;
        sJWad = (budget * eJ) / den;
        sKWad = budget - sJWad;
        if (sJWad == 0 || sKWad == 0) return (false, 0, 0, 0, 0, 0);

        // Sequential sphere exact-in on snapshot book (fee-net in, full face credit for L2 update)
        uint256 x = _pick(e0, e1, e2, inIdx);
        uint256 yJ = eJ;
        uint256 yK = eK;
        uint256 zJ = eK; // witness for first swap in→j is k
        uint256 netJ = applyTradingFeeNet(sJWad, feeWad);
        (bool okJ, uint256 outJ) = _tryExactIn(R, L2, x, yJ, zJ, netJ);
        if (!okJ) return (false, 0, 0, 0, 0, 0);

        // Update e after first: + full sJ to in, -outJ to j (match live face credit)
        uint256 eIn2 = x + sJWad;
        uint256 eJ2 = yJ - outJ;
        uint256 eK2 = yK;
        if (eIn2 >= R || eJ2 == 0) return (false, 0, 0, 0, 0, 0);
        // Rebuild L2 in binding order
        uint256 e0b = e0;
        uint256 e1b = e1;
        uint256 e2b = e2;
        if (inIdx == 0) e0b = eIn2;
        else if (inIdx == 1) e1b = eIn2;
        else e2b = eIn2;
        if (j == 0) e0b = eJ2;
        else if (j == 1) e1b = eJ2;
        else e2b = eJ2;
        uint256 L2b = recomputeL2(R, e0b, e1b, e2b);

        uint256 netK = applyTradingFeeNet(sKWad, feeWad);
        // Second swap in→k, witness j
        (bool okK, uint256 outK) = _tryExactIn(R, L2b, eIn2, eK2, eJ2, netK);
        if (!okK) return (false, 0, 0, 0, 0, 0);

        aJWad = outJ;
        aKWad = outK;
        ok = true;

        // Compare residual/eIn vs outJ/eJ vs outK/eK (use cross products to avoid division noise)
        // residual/eIn ? outJ/eJ  → residual * eJ ? outJ * eIn
        uint256 left = residual * eJ;
        uint256 right = outJ * eIn;
        uint256 tol = right / 1_000_000; // 1e-6 relative on right
        if (tol == 0) tol = 1;
        if (left > right + tol) cmp = 1;
        else if (right > left + tol) cmp = -1;
        else {
            // also check outJ/eJ vs outK/eK
            uint256 left2 = outJ * eK;
            uint256 right2 = outK * eJ;
            uint256 tol2 = right2 / 1_000_000;
            if (tol2 == 0) tol2 = 1;
            if (left2 > right2 + tol2) cmp = 1;
            else if (right2 > left2 + tol2) cmp = -1;
            else cmp = 0;
        }
    }

    function _tryExactIn(
        uint256 R,
        uint256 L2,
        uint256 xWad,
        uint256 yWad,
        uint256 zWad,
        uint256 dxNetWad
    ) private pure returns (bool ok, uint256 dyWad) {
        if (R == 0 || dxNetWad == 0) return (false, 0);
        if (xWad >= R || yWad >= R || zWad >= R) return (false, 0);
        uint256 xPrime = xWad + dxNetWad;
        if (xPrime >= R) return (false, 0);
        uint256 rx = R - xPrime;
        uint256 rz = R - zWad;
        uint256 sub = rx * rx + rz * rz;
        if (L2 < sub) return (false, 0);
        uint256 sqrtT = (L2 - sub).sqrt();
        if (sqrtT >= R) return (false, 0);
        uint256 yPrime = R - sqrtT;
        if (!(yPrime > 0 && yPrime < yWad)) return (false, 0);
        dyWad = yWad - yPrime;
        if (dyWad == 0) return (false, 0);
        return (true, dyWad);
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
