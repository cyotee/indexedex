// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookMath
 * @notice Pure dual-scale + classic Curve StableSwap n=4 + inventory LP / growth helpers.
 * @dev **Ann pin (LOCKED):** `Ann = A' * N_TOKENS` where `A' = baseAmp * AMP_PRECISION` (`AMP_PRECISION=100`).
 *      Classic Curve StableSwap iterative getD/getY — **not** StableSwapNG, **not** Balancer StableMath.
 *      No storage/external calls. Swaps use ratedWad + input residual fee. LP / kLast use invWad (I1: geoMean4).
 *      Single-asset taxable portion uses dexSwapFee (mulUp peer).
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHookMath {
    error ZeroAmount();
    error InvalidFeeWad();
    error InvariantFailed();
    error MathDomain();
    error WouldZeroReserve();

    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RATE_PRECISION = 1e18;
    uint256 internal constant AMP_PRECISION = 100;
    uint256 internal constant MAX_AMP = 1_000_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_NR_ITERS = 255;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant PAIR_COUNT = 6;
    uint256 internal constant LP_SYMBOL_MAX = 32;
    uint256 internal constant LP_NAME_MAX = 64;
    int24 internal constant TICK_SPACING = 1;

    /* ---------------------------------------------------------------------- */
    /*                              Scale / descaling                         */
    /* ---------------------------------------------------------------------- */

    function baseScaleFromDecimals(uint8 decimals) internal pure returns (uint256) {
        if (decimals < 6 || decimals > 18) revert MathDomain();
        return 10 ** (36 - uint256(decimals));
    }

    function scaleTo(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / RATE_PRECISION;
    }

    function scaleToUp(uint256 amount, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        if (amount == 0) return 0;
        return (amount * rate + RATE_PRECISION - 1) / RATE_PRECISION;
    }

    function descale(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        return (scaled * RATE_PRECISION) / rate;
    }

    function descaleUp(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        if (scaled == 0) return 0;
        return (scaled * RATE_PRECISION + rate - 1) / rate;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b + (WAD - 1)) / WAD;
    }

    function mulDivCeil(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        if (d == 0) revert ZeroAmount();
        if (a == 0 || b == 0) return 0;
        return (a * b + (d - 1)) / d;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Fee helpers                               */
    /* ---------------------------------------------------------------------- */

    function applyTradingFeeNet(uint256 amountIn, uint256 feeWad) internal pure returns (uint256 net) {
        if (feeWad >= WAD) revert InvalidFeeWad();
        if (feeWad == 0) return amountIn;
        uint256 feeAmt = (amountIn * feeWad) / WAD;
        net = amountIn - feeAmt;
    }

    function grossUpExactOut(uint256 netIn, uint256 feeWad) internal pure returns (uint256 gross) {
        if (feeWad >= WAD) revert InvalidFeeWad();
        if (feeWad == 0) return netIn;
        uint256 den = WAD - feeWad;
        gross = (netIn * WAD + den - 1) / den;
    }

    function feeOverridePips(uint256 feeWad) internal pure returns (uint24) {
        return uint24(uint256((feeWad * 1e6) / WAD) | 0x400000);
    }

    /* ---------------------------------------------------------------------- */
    /*                            geometric mean 4                            */
    /* ---------------------------------------------------------------------- */

    /// @dev Pairwise sqrt. Zero input → 0. I1 kLast form + first mint domain.
    function geometricMean4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256) {
        if (a == 0 || b == 0 || c == 0 || d == 0) return 0;
        uint256 ab = FixedPointMathLib.sqrt(a * b);
        uint256 cd = FixedPointMathLib.sqrt(c * d);
        return FixedPointMathLib.sqrt(ab * cd);
    }

    /// @dev I1 freeze: rootK = geoMean4(invWad).
    function rootK(uint256[4] memory invWad) internal pure returns (uint256) {
        return geometricMean4(invWad[0], invWad[1], invWad[2], invWad[3]);
    }

    /// @dev Uni V2-style protocol LP mint from pre-intake growth of k.
    function protocolLpShares(
        uint256 supply,
        uint256 rootKNow,
        uint256 rootKLast,
        uint256 ownerFeeShare
    ) internal pure returns (uint256) {
        if (supply == 0 || rootKLast == 0 || rootKNow <= rootKLast || ownerFeeShare == 0) {
            return 0;
        }
        uint256 num = supply * (rootKNow - rootKLast);
        uint256 den = (rootKNow * FEE_DENOMINATOR) / ownerFeeShare + rootKNow - rootKLast;
        if (den == 0) return 0;
        return num / den;
    }

    /* ---------------------------------------------------------------------- */
    /*                     classic Curve getD / getY (n=4)                    */
    /* ---------------------------------------------------------------------- */

    function getD(uint256[4] memory xp, uint256 amp) internal pure returns (uint256) {
        return _getD(xp, amp);
    }

    function _getD(uint256[4] memory xpIn, uint256 amp) private pure returns (uint256 D) {
        // Local copy so zero-witness padding never mutates caller memory.
        uint256[4] memory xp;
        xp[0] = xpIn[0];
        xp[1] = xpIn[1];
        xp[2] = xpIn[2];
        xp[3] = xpIn[3];

        uint256 S;
        unchecked {
            S = xp[0] + xp[1] + xp[2] + xp[3];
        }
        if (S == 0) return 0;
        // Defensive zero-witness: pad missing legs with 1 wei when ≥2 live (swap solver only).
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) {
            uint256 live;
            for (uint256 i; i < N_TOKENS; ++i) {
                if (xp[i] > 0) ++live;
            }
            if (live < 2) revert InvariantFailed();
            for (uint256 i; i < N_TOKENS; ++i) {
                if (xp[i] == 0) xp[i] = 1;
            }
            unchecked {
                S = xp[0] + xp[1] + xp[2] + xp[3];
            }
        }

        D = S;
        uint256 Ann = amp * N_TOKENS;
        for (uint256 i; i < MAX_NR_ITERS; ++i) {
            uint256 D_P = D;
            D_P = (D_P * D) / (xp[0] * N_TOKENS);
            D_P = (D_P * D) / (xp[1] * N_TOKENS);
            D_P = (D_P * D) / (xp[2] * N_TOKENS);
            D_P = (D_P * D) / (xp[3] * N_TOKENS);

            uint256 Dprev = D;
            D = (((Ann * S) / AMP_PRECISION + D_P * N_TOKENS) * D)
                / (((Ann - AMP_PRECISION) * D) / AMP_PRECISION + (N_TOKENS + 1) * D_P);

            if (D > Dprev) {
                if (D - Dprev <= 1) return D;
            } else if (Dprev - D <= 1) {
                return D;
            }
        }
        revert InvariantFailed();
    }

    function getY(uint256 i, uint256 j, uint256 x, uint256[4] memory xp, uint256 amp, uint256 D)
        internal
        pure
        returns (uint256)
    {
        return _getY(i, j, x, xp, amp, D);
    }

    function _getY(uint256 i, uint256 j, uint256 x, uint256[4] memory xp, uint256 amp, uint256 D)
        private
        pure
        returns (uint256 y)
    {
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (D == 0 || x == 0) revert InvariantFailed();

        uint256 Ann = amp * N_TOKENS;
        uint256 c = D;
        uint256 S_;
        uint256 _x;

        for (uint256 k; k < N_TOKENS; ++k) {
            if (k == i) {
                _x = x;
            } else if (k != j) {
                _x = xp[k] == 0 ? 1 : xp[k]; // defensive pad for zero witness
            } else {
                continue;
            }
            if (_x == 0) revert InvariantFailed();
            S_ += _x;
            c = (c * D) / (_x * N_TOKENS);
        }
        c = (c * D * AMP_PRECISION) / (Ann * N_TOKENS);
        uint256 b = S_ + (D * AMP_PRECISION) / Ann;
        y = D;

        for (uint256 iter; iter < MAX_NR_ITERS; ++iter) {
            uint256 yPrev = y;
            y = (y * y + c) / (2 * y + b - D);
            if (y > yPrev) {
                if (y - yPrev <= 1) return y;
            } else if (yPrev - y <= 1) {
                return y;
            }
        }
        revert InvariantFailed();
    }

    /* ---------------------------------------------------------------------- */
    /*                     Swaps on rated book (fee on input)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Exact-in on ratedWad balances; fee residual on input; returns raw out in pair units
    ///         when ratedScale is identity — callers pass already-rated amountIn / balances.
    /// @param xp Rated WAD balances [4]
    /// @param i In index
    /// @param j Out index
    /// @param amountInRatedNet Fee-net amount already in rated WAD (caller applies fee first)
    /// @param amp A'
    function quoteExactInRated(
        uint256[4] memory xp,
        uint256 i,
        uint256 j,
        uint256 amountInRatedNet,
        uint256 amp
    ) internal pure returns (uint256 amountOutRated) {
        if (amountInRatedNet == 0) revert ZeroAmount();
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (xp[i] == 0 || xp[j] == 0) revert InvariantFailed();

        uint256 D = _getD(xp, amp);
        uint256 yOutNew = _getY(i, j, xp[i] + amountInRatedNet, xp, amp, D);
        if (yOutNew >= xp[j]) revert InvariantFailed();
        amountOutRated = xp[j] - yOutNew;
        if (amountOutRated == 0) revert ZeroAmount();
    }

    function quoteExactOutRated(
        uint256[4] memory xp,
        uint256 i,
        uint256 j,
        uint256 amountOutRated,
        uint256 amp
    ) internal pure returns (uint256 amountInRatedNet) {
        if (amountOutRated == 0) revert ZeroAmount();
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (xp[i] == 0 || xp[j] == 0) revert InvariantFailed();
        if (amountOutRated >= xp[j]) revert InvariantFailed();

        uint256 D = _getD(xp, amp);
        uint256 yOutNew = xp[j] - amountOutRated;
        if (yOutNew == 0) revert InvariantFailed();
        uint256 xInNew = _getY(j, i, yOutNew, xp, amp, D);
        if (xInNew <= xp[i]) revert InvariantFailed();
        amountInRatedNet = xInNew - xp[i];
        if (amountInRatedNet == 0) revert ZeroAmount();
    }

    /* ---------------------------------------------------------------------- */
    /*                         LP share helpers (inventory)                   */
    /* ---------------------------------------------------------------------- */

    function firstMintShares(uint256[4] memory invWad) internal pure returns (uint256 shares) {
        uint256 geo = geometricMean4(invWad[0], invWad[1], invWad[2], invWad[3]);
        if (geo <= MINIMUM_LIQUIDITY) revert ZeroAmount();
        shares = geo - MINIMUM_LIQUIDITY;
    }

    function proportionalJoinShares(uint256[4] memory amountWad, uint256[4] memory reserveWad, uint256 supply)
        internal
        pure
        returns (uint256 shares)
    {
        if (supply == 0) revert MathDomain();
        shares = type(uint256).max;
        for (uint256 i; i < N_TOKENS; ++i) {
            if (reserveWad[i] == 0) revert ZeroAmount();
            if (amountWad[i] == 0) revert ZeroAmount();
            uint256 s = (amountWad[i] * supply) / reserveWad[i];
            if (s < shares) shares = s;
        }
        if (shares == 0 || shares == type(uint256).max) revert MathDomain();
    }

    function proportionalUsedWad(uint256 shares, uint256 reserveWad, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        // pool-favoring ceil for used inventory
        return (shares * reserveWad + (supply - 1)) / supply;
    }

    function proportionalExitAmounts(uint256 shares, uint256[4] memory natives, uint256 supply)
        internal
        pure
        returns (uint256[4] memory amounts)
    {
        if (shares == 0 || supply == 0) revert ZeroAmount();
        for (uint256 i; i < N_TOKENS; ++i) {
            amounts[i] = (shares * natives[i]) / supply;
        }
    }

    /**
     * @notice Single-asset exact-in join on inventory WAD with taxable fee (dexSwapFee channel).
     * @dev Curve D growth + Balancer-style taxable above proportional ideal.
     */
    function singleJoinExactInShares(
        uint256[4] memory invWad,
        uint256 amountInWad,
        uint256 tokenInIndex,
        uint256 amp,
        uint256 supply,
        uint256 swapFeeWad
    ) internal pure returns (uint256 shares) {
        if (supply == 0 || amountInWad == 0) revert ZeroAmount();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        if (tokenInIndex >= N_TOKENS) revert MathDomain();
        for (uint256 i; i < N_TOKENS; ++i) {
            if (invWad[i] == 0) revert MathDomain();
        }

        uint256 D0 = _getD(invWad, amp);
        uint256[4] memory newXp = invWad;
        newXp[tokenInIndex] = invWad[tokenInIndex] + amountInWad;
        uint256 D1 = _getD(newXp, amp);
        if (D1 <= D0) revert MathDomain();

        // Ideal proportional contribution of this leg for D growth
        uint256 idealAmount = (invWad[tokenInIndex] * (D1 - D0)) / D0;
        uint256 taxable = amountInWad > idealAmount ? amountInWad - idealAmount : 0;
        uint256 feeAmount = mulUp(taxable, swapFeeWad);
        newXp[tokenInIndex] = invWad[tokenInIndex] + amountInWad - feeAmount;
        uint256 D2 = _getD(newXp, amp);
        if (D2 <= D0) revert MathDomain();
        shares = (supply * (D2 - D0)) / D0;
        if (shares == 0) revert ZeroAmount();
    }

    /**
     * @notice Single-asset exact-BPT-in exit on inventory WAD with taxable fee.
     */
    function singleExitExactBptInAmountOut(
        uint256[4] memory invWad,
        uint256 sharesIn,
        uint256 tokenOutIndex,
        uint256 amp,
        uint256 supply,
        uint256 swapFeeWad
    ) internal pure returns (uint256 amountOutWad) {
        if (sharesIn == 0 || supply == 0 || sharesIn >= supply) revert MathDomain();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        if (tokenOutIndex >= N_TOKENS) revert MathDomain();
        for (uint256 i; i < N_TOKENS; ++i) {
            if (invWad[i] == 0) revert MathDomain();
        }

        uint256 D0 = _getD(invWad, amp);
        uint256 D1 = (D0 * (supply - sharesIn)) / supply;
        if (D1 == 0 || D1 >= D0) revert MathDomain();

        // Solve for new balance of tokenOut such that getD ≈ D1 (Newton via getY pattern:
        // treat as reducing one leg while keeping others fixed — use getY with virtual pair).
        // y_new from invariant: use getY with i=out, j dummy doesn't work; use balance solve.
        uint256 yNew = _getYd(tokenOutIndex, invWad, amp, D1);
        if (yNew >= invWad[tokenOutIndex]) revert MathDomain();
        uint256 amountOut = invWad[tokenOutIndex] - yNew;

        // Ideal proportional out
        uint256 idealOut = (invWad[tokenOutIndex] * sharesIn) / supply;
        uint256 taxable = amountOut > idealOut ? amountOut - idealOut : 0;
        uint256 feeAmount = mulUp(taxable, swapFeeWad);
        amountOutWad = amountOut - feeAmount;
        if (amountOutWad == 0) revert ZeroAmount();
        // Full-book floor: remaining > 0
        if (invWad[tokenOutIndex] <= amountOutWad) revert WouldZeroReserve();
    }

    /// @dev Solve for balance of coin `j` given invariant D (other balances fixed).
    function _getYd(uint256 j, uint256[4] memory xp, uint256 amp, uint256 D)
        private
        pure
        returns (uint256 y)
    {
        if (j >= N_TOKENS || D == 0) revert InvariantFailed();
        uint256 Ann = amp * N_TOKENS;
        uint256 c = D;
        uint256 S_;
        for (uint256 k; k < N_TOKENS; ++k) {
            if (k == j) continue;
            uint256 _x = xp[k];
            if (_x == 0) revert InvariantFailed();
            S_ += _x;
            c = (c * D) / (_x * N_TOKENS);
        }
        c = (c * D * AMP_PRECISION) / (Ann * N_TOKENS);
        uint256 b = S_ + (D * AMP_PRECISION) / Ann;
        y = D;
        for (uint256 iter; iter < MAX_NR_ITERS; ++iter) {
            uint256 yPrev = y;
            y = (y * y + c) / (2 * y + b - D);
            if (y > yPrev) {
                if (y - yPrev <= 1) return y;
            } else if (yPrev - y <= 1) {
                return y;
            }
        }
        revert InvariantFailed();
    }

    function isFullBookReserves(uint256[4] memory reserves) internal pure returns (bool) {
        for (uint256 i; i < N_TOKENS; ++i) {
            if (reserves[i] == 0) return false;
        }
        return true;
    }

    function countPositive(uint256[4] memory amounts) internal pure returns (uint256 c) {
        for (uint256 i; i < N_TOKENS; ++i) {
            if (amounts[i] > 0) ++c;
        }
    }

    function toDynamic(uint256[4] memory a) internal pure returns (uint256[] memory d) {
        d = new uint256[](4);
        d[0] = a[0];
        d[1] = a[1];
        d[2] = a[2];
        d[3] = a[3];
    }

    function toFixed4(uint256[] memory a) internal pure returns (uint256[4] memory f) {
        if (a.length != 4) revert MathDomain();
        f[0] = a[0];
        f[1] = a[1];
        f[2] = a[2];
        f[3] = a[3];
    }
}
