// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";

/**
 * @title UniswapV4OrbitalSwapHookMath
 * @notice Pure sphere, WAD, shares, sphere-NAV (D72), growth fee (D56) helpers.
 */
library UniswapV4OrbitalSwapHookMath {
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

    /// @dev Exact-in on out-leg in 1e18 domain. x is in-reserve, y out-reserve, z witness.
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

    /// @dev Exact-out: given dyWad out, return net dx (pre fee gross-up) in 1e18.
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

    /// @dev Trading fee residual: net = gross - floor(gross * feeWad / 1e18). D20.
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

    /// @dev Exact-out gross-up: net * 1e18 / (1e18 - fee) + 1 when fee > 0. D20a.
    function grossUpExactOut(uint256 netWad, uint256 feeWad) internal pure returns (uint256 grossWad) {
        if (feeWad >= WAD) revert MathDomain();
        if (feeWad == 0) return netWad;
        grossWad = (netWad * WAD) / (WAD - feeWad) + 1;
    }

    /// @dev V4 pips with OVERRIDE bit. D20b. feeWad < 1e18.
    function feeOverridePips(uint256 feeWad) internal pure returns (uint24) {
        // OVERRIDE_FEE_FLAG = 0x400000
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

    /// @dev Full-book Uni V2 min-ratio shares (all three legs). D24.
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

    /// @dev Sphere spot weight p_i = R - r_i (zero leg ⇒ R). D72.
    function sphereSpotWeight(uint256 R, uint256 rWad) internal pure returns (uint256) {
        if (R == 0) revert MathDomain();
        if (rWad >= R) revert MathDomain();
        return R - rWad;
    }

    /// @dev shares = supply * V_in / V_before (floor). D72 / Q44.
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

    /// @dev Protocol LP from rootK growth (D56). rootK already cbrt(product) or sum.
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
}
