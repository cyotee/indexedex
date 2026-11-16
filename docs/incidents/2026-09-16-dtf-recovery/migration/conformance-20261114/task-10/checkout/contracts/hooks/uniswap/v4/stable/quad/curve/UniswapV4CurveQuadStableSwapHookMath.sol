// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHookMath
 * @notice Pure n=4 StableSwap math (classic Curve Newton getD/getY).
 * @dev **Ann pin (LOCKED):** `Ann = A' * N_TOKENS` where `A' = baseAmp * AMP_PRECISION`.
 *      Classic Curve StableSwap iterative form — **not** StableSwapNG, **not** Balancer StableMath.
 *      No storage, no external calls. Fixtures in `UniswapV4CurveQuadStableSwapHook_Math.t.sol` are law.
 * @custom:divergences Fee helpers are fee-on-output (exact-in deduct / exact-out gross-up). Orbital peer is fee-on-input.
 */
library UniswapV4CurveQuadStableSwapHookMath {
    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant FEE_DENOMINATOR = 1_000_000;
    uint256 internal constant RATE_PRECISION = 1e18;
    uint256 internal constant AMP_PRECISION = 100;
    uint256 internal constant MAX_AMP = 1_000_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_NR_ITERS = 255;
    uint256 internal constant PAIR_COUNT = 6;
    int24 internal constant TICK_SPACING = 1;
    uint256 internal constant LP_SYMBOL_MAX = 32;
    uint256 internal constant LP_NAME_MAX = 64;

    error InvariantFailed();
    error ZeroAmount();

    /* ---------------------------------------------------------------------- */
    /*                              scale / descale                           */
    /* ---------------------------------------------------------------------- */

    /// @notice `baseScale = 10^(36 - decimals)` for decimals ∈ [6,18].
    function baseScaleFromDecimals(uint8 decimals) internal pure returns (uint256) {
        return 10 ** (36 - uint256(decimals));
    }

    function scaleTo(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / RATE_PRECISION;
    }

    function scaleToUp(uint256 amount, uint256 rate) internal pure returns (uint256) {
        if (amount == 0) return 0;
        return (amount * rate + (RATE_PRECISION - 1)) / RATE_PRECISION;
    }

    function descale(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert ZeroAmount();
        return (scaled * RATE_PRECISION) / rate;
    }

    function descaleUp(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert ZeroAmount();
        if (scaled == 0) return 0;
        return (scaled * RATE_PRECISION + (rate - 1)) / rate;
    }

    /* ---------------------------------------------------------------------- */
    /*                            geometric mean 4                            */
    /* ---------------------------------------------------------------------- */

    /// @dev Pairwise sqrt to reduce overflow. Zero input → 0.
    function geometricMean4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256) {
        if (a == 0 || b == 0 || c == 0 || d == 0) return 0;
        uint256 ab = FixedPointMathLib.sqrt(a * b);
        uint256 cd = FixedPointMathLib.sqrt(c * d);
        return FixedPointMathLib.sqrt(ab * cd);
    }

    /* ---------------------------------------------------------------------- */
    /*                     classic Curve getD / getY (n=4)                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Newton-Raphson invariant D for rate-scaled balances.
     * @param xp Rate-scaled reserves [4]
     * @param amp A' = baseAmp * AMP_PRECISION (getCurrentAmp)
     * @dev Ann = amp * N_TOKENS. Any zero xp with S>0 reverts (product undefined).
     *      S==0 returns 0.
     */
    function getD(uint256[4] memory xp, uint256 amp) external pure returns (uint256) {
        return _getD(xp, amp);
    }

    function _getD(uint256[4] memory xp, uint256 amp) private pure returns (uint256 D) {
        uint256 S;
        unchecked {
            S = xp[0] + xp[1] + xp[2] + xp[3];
        }
        if (S == 0) return 0;
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) revert InvariantFailed();

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

    /**
     * @notice Solve for reserve at `j` given new balance of coin `i` is `x`, preserving D.
     * @param i Index of known (changed) leg
     * @param j Index of unknown leg
     * @param x New rate-scaled balance of leg i
     * @param xp Current rate-scaled balances (leg i value ignored; use `x`)
     * @param amp A' = baseAmp * AMP_PRECISION
     * @param D Invariant (must match getD of pre-trade state when used for swaps)
     */
    function getY(uint256 i, uint256 j, uint256 x, uint256[4] memory xp, uint256 amp, uint256 D)
        external
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
                _x = xp[k];
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
    /*                         fee-on-output helpers                          */
    /* ---------------------------------------------------------------------- */

    /// @notice Exact-in: fee = ceil(rawOut * feePips / 1e6); userOut = rawOut - fee.
    function feeOnOutputExactIn(uint256 rawOut, uint24 lpFeePips)
        internal
        pure
        returns (uint256 userOut, uint256 fee)
    {
        if (rawOut == 0) return (0, 0);
        fee = (rawOut * uint256(lpFeePips) + (FEE_DENOMINATOR - 1)) / FEE_DENOMINATOR;
        if (fee > rawOut) fee = rawOut;
        userOut = rawOut - fee;
    }

    /// @notice Exact-out: grossOut = ceil(amountOut * 1e6 / (1e6 - feePips)).
    function feeOnOutputExactOutGrossUp(uint256 amountOut, uint24 lpFeePips)
        internal
        pure
        returns (uint256 grossOut)
    {
        if (amountOut == 0) revert ZeroAmount();
        uint256 denom = FEE_DENOMINATOR - uint256(lpFeePips);
        if (denom == 0) revert ZeroAmount();
        grossOut = (amountOut * FEE_DENOMINATOR + (denom - 1)) / denom;
    }

    /* ---------------------------------------------------------------------- */
    /*                          swap quote helpers                            */
    /* ---------------------------------------------------------------------- */

    struct QuoteCtx {
        uint256[4] reserves;
        uint256[4] rates;
        uint256 i;
        uint256 j;
        uint256 amp;
        uint24 lpFeePips;
    }

    function _scaleReserves(uint256[4] memory reservesRaw, uint256[4] memory rates)
        private
        pure
        returns (uint256[4] memory xp)
    {
        xp[0] = scaleTo(reservesRaw[0], rates[0]);
        xp[1] = scaleTo(reservesRaw[1], rates[1]);
        xp[2] = scaleTo(reservesRaw[2], rates[2]);
        xp[3] = scaleTo(reservesRaw[3], rates[3]);
    }

    function _assertPostPairLive(uint256[4] memory newReserves, uint256 i, uint256 j) private pure {
        if (newReserves[i] == 0 || newReserves[j] == 0) revert InvariantFailed();
    }

    function _assertPostPriceable(
        uint256[4] memory newReserves,
        uint256[4] memory rates,
        uint256 amp,
        uint256 i,
        uint256 j
    ) private pure {
        uint256[4] memory xpPost = _scaleReserves(newReserves, rates);
        if (xpPost[0] == 0 || xpPost[1] == 0 || xpPost[2] == 0 || xpPost[3] == 0) {
            _assertPostPairLive(newReserves, i, j);
            return;
        }
        _getD(xpPost, amp);
    }

    /**
     * @notice Exact-in on rate-scaled book: returns userOut (raw) after fee-on-output.
     * @param reservesRaw Raw reserves snapshot
     * @param rates Effective rates per leg
     * @param i In index
     * @param j Out index
     * @param amountIn Raw input amount
     * @param amp A' amplification
     * @param lpFeePips Fee in pips
     */
    function quoteExactIn(
        uint256[4] memory reservesRaw,
        uint256[4] memory rates,
        uint256 i,
        uint256 j,
        uint256 amountIn,
        uint256 amp,
        uint24 lpFeePips
    ) external pure returns (uint256 amountOut, uint256[4] memory newReserves) {
        if (amountIn == 0) revert ZeroAmount();
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (reservesRaw[i] == 0 || reservesRaw[j] == 0) revert InvariantFailed();

        QuoteCtx memory c;
        c.reserves = reservesRaw;
        c.rates = rates;
        c.i = i;
        c.j = j;
        c.amp = amp;
        c.lpFeePips = lpFeePips;
        return _quoteExactIn(c, amountIn);
    }

    function _quoteExactIn(QuoteCtx memory c, uint256 amountIn)
        private
        pure
        returns (uint256 amountOut, uint256[4] memory newReserves)
    {
        uint256[4] memory xp = _scaleReserves(c.reserves, c.rates);
        uint256 D = _getD(xp, c.amp);
        uint256 yOutNew = _getY(c.i, c.j, xp[c.i] + scaleTo(amountIn, c.rates[c.i]), xp, c.amp, D);
        if (yOutNew >= xp[c.j]) revert InvariantFailed();
        (amountOut,) = feeOnOutputExactIn(descale(xp[c.j] - yOutNew, c.rates[c.j]), c.lpFeePips);
        if (amountOut == 0) revert ZeroAmount();

        newReserves = c.reserves;
        newReserves[c.i] = c.reserves[c.i] + amountIn;
        newReserves[c.j] = c.reserves[c.j] - amountOut;
        _assertPostPriceable(newReserves, c.rates, c.amp, c.i, c.j);
    }

    function quoteExactOut(
        uint256[4] memory reservesRaw,
        uint256[4] memory rates,
        uint256 i,
        uint256 j,
        uint256 amountOut,
        uint256 amp,
        uint24 lpFeePips
    ) external pure returns (uint256 amountIn, uint256[4] memory newReserves) {
        if (amountOut == 0) revert ZeroAmount();
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (reservesRaw[i] == 0 || reservesRaw[j] == 0) revert InvariantFailed();
        if (amountOut >= reservesRaw[j]) revert InvariantFailed();

        QuoteCtx memory c;
        c.reserves = reservesRaw;
        c.rates = rates;
        c.i = i;
        c.j = j;
        c.amp = amp;
        c.lpFeePips = lpFeePips;
        return _quoteExactOut(c, amountOut);
    }

    function _quoteExactOut(QuoteCtx memory c, uint256 amountOut)
        private
        pure
        returns (uint256 amountIn, uint256[4] memory newReserves)
    {
        uint256 grossOut = feeOnOutputExactOutGrossUp(amountOut, c.lpFeePips);
        if (grossOut > c.reserves[c.j]) revert InvariantFailed();

        uint256[4] memory xp = _scaleReserves(c.reserves, c.rates);
        uint256 D = _getD(xp, c.amp);
        uint256 yOutNewScaled = xp[c.j] - scaleToUp(grossOut, c.rates[c.j]);
        if (yOutNewScaled == 0) revert InvariantFailed();
        uint256 xInNew = _getY(c.j, c.i, yOutNewScaled, xp, c.amp, D);
        if (xInNew <= xp[c.i]) revert InvariantFailed();
        amountIn = descaleUp(xInNew - xp[c.i], c.rates[c.i]);
        if (amountIn == 0) revert ZeroAmount();

        newReserves = c.reserves;
        newReserves[c.i] = c.reserves[c.i] + amountIn;
        newReserves[c.j] = c.reserves[c.j] - amountOut;
        _assertPostPriceable(newReserves, c.rates, c.amp, c.i, c.j);
    }

    /* ---------------------------------------------------------------------- */
    /*                         LP share helpers                               */
    /* ---------------------------------------------------------------------- */

    function firstMintShares(uint256[4] memory scaledAmounts) internal pure returns (uint256 shares) {
        uint256 geo = geometricMean4(scaledAmounts[0], scaledAmounts[1], scaledAmounts[2], scaledAmounts[3]);
        if (geo <= MINIMUM_LIQUIDITY) revert ZeroAmount();
        shares = geo - MINIMUM_LIQUIDITY;
    }

    function laterMintShares(uint256[4] memory amounts, uint256[4] memory reserves, uint256 supply)
        internal
        pure
        returns (uint256 shares, uint256[4] memory actual)
    {
        if (supply == 0) revert ZeroAmount();
        shares = type(uint256).max;
        for (uint256 i; i < N_TOKENS; ++i) {
            if (reserves[i] == 0) {
                if (amounts[i] == 0) continue;
                revert ZeroAmount();
            }
            uint256 s = (amounts[i] * supply) / reserves[i];
            if (s < shares) shares = s;
        }
        if (shares == 0 || shares == type(uint256).max) revert ZeroAmount();
        // Pool-favoring ceil can push one leg over `amounts`; shrink shares until all fit.
        while (shares > 0) {
            bool ok = true;
            for (uint256 i; i < N_TOKENS; ++i) {
                actual[i] = (shares * reserves[i] + (supply - 1)) / supply;
                if (actual[i] > amounts[i]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return (shares, actual);
            unchecked {
                --shares;
            }
        }
        revert ZeroAmount();
    }

    function removeAmounts(uint256 shares, uint256[4] memory reserves, uint256 supply)
        internal
        pure
        returns (uint256[4] memory amounts)
    {
        if (shares == 0 || supply == 0) revert ZeroAmount();
        for (uint256 i; i < N_TOKENS; ++i) {
            amounts[i] = (shares * reserves[i]) / supply;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                          ceil helpers                                  */
    /* ---------------------------------------------------------------------- */

    function mulDivCeil(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        if (d == 0) revert ZeroAmount();
        if (a == 0 || b == 0) return 0;
        return (a * b + (d - 1)) / d;
    }
}
