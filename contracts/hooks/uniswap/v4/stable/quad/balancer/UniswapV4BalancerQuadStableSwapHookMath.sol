// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {StableMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookMath
 * @notice Pure n=4 StableSwap math via Crane/Balancer V3 `StableMath` (AMP_PRECISION = 1e3).
 * @dev **Not** classic Curve `getD`/`getY` with AMP_PRECISION=100. Swap quotes call
 *      `StableMath.computeInvariant` / `computeOutGivenExactIn` / `computeInGivenExactOut` /
 *      `computeBalance` with favor-protocol ±1 where Balancer applies.
 *      Fee helpers are fee-on-output (exact-in deduct / exact-out gross-up) for V4 residual.
 *      No storage, no external calls.
 */
library UniswapV4BalancerQuadStableSwapHookMath {
    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant FEE_DENOMINATOR = 1_000_000;
    uint256 internal constant RATE_PRECISION = 1e18;
    /// @dev Balancer V3 StableMath precision (not Curve-100).
    uint256 internal constant AMP_PRECISION = 1e3;
    /// @dev Human amplification upper bound (Balancer StableMath MAX_AMP).
    uint256 internal constant MAX_AMP = 50_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
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
    /*                 Balancer StableMath wrappers (n=4 fixed)               */
    /* ---------------------------------------------------------------------- */

    function _toDyn(uint256[4] memory xp) private pure returns (uint256[] memory balances) {
        balances = new uint256[](N_TOKENS);
        balances[0] = xp[0];
        balances[1] = xp[1];
        balances[2] = xp[2];
        balances[3] = xp[3];
    }

    /**
     * @notice Invariant D for rate-scaled balances via Balancer `computeInvariant`.
     * @param xp Rate-scaled reserves [4]
     * @param amp Amplification including precision: baseAmp * AMP_PRECISION (1e3)
     */
    function getD(uint256[4] memory xp, uint256 amp) external pure returns (uint256) {
        return _getD(xp, amp);
    }

    function _getD(uint256[4] memory xp, uint256 amp) private pure returns (uint256) {
        uint256 S;
        unchecked {
            S = xp[0] + xp[1] + xp[2] + xp[3];
        }
        if (S == 0) return 0;
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) revert InvariantFailed();
        return StableMath.computeInvariant(amp, _toDyn(xp));
    }

    /**
     * @notice Solve for reserve at `j` given new balance of coin `i` is `x`, preserving D.
     * @dev Uses Balancer `computeBalance` (rounds up). Peer of Curve getY for zap inverse only.
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
        returns (uint256)
    {
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (D == 0 || x == 0) revert InvariantFailed();
        uint256[] memory balances = _toDyn(xp);
        balances[i] = x;
        return StableMath.computeBalance(amp, balances, D, j);
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

    /// @dev Soft under Balancer `MAX_IMBALANCE_RATIO` (10_000) so Newton remains usable for zap.
    uint256 internal constant MAX_ZAP_IMBALANCE_RATIO = 5_000;

    /**
     * @dev Post-swap book gate: pair live, all scaled legs non-zero, imbalance within soft cap.
     *      Extreme imbalance makes subsequent `computeInvariant` fail (Balancer Newton).
     */
    function _assertPostPriceable(
        uint256[4] memory newReserves,
        uint256[4] memory rates,
        uint256, /* amp */
        uint256 i,
        uint256 j
    ) private pure {
        _assertPostPairLive(newReserves, i, j);
        uint256[4] memory xpPost = _scaleReserves(newReserves, rates);
        if (xpPost[0] == 0 || xpPost[1] == 0 || xpPost[2] == 0 || xpPost[3] == 0) {
            revert InvariantFailed();
        }
        if (!_imbalanceWithin(xpPost, MAX_ZAP_IMBALANCE_RATIO)) revert InvariantFailed();
    }

    function _imbalanceWithin(uint256[4] memory xp, uint256 maxRatio) private pure returns (bool) {
        uint256 minB = xp[0];
        uint256 maxB = xp[0];
        for (uint256 k = 1; k < N_TOKENS; ++k) {
            if (xp[k] < minB) minB = xp[k];
            if (xp[k] > maxB) maxB = xp[k];
        }
        if (minB == 0) return false;
        return maxB / minB < maxRatio;
    }

    /// @notice True if rate-scaled reserves stay under soft imbalance cap (zap / mint gates).
    function imbalanceOk(uint256[4] memory reservesRaw, uint256[4] memory rates)
        internal
        pure
        returns (bool)
    {
        return _imbalanceWithin(_scaleReserves(reservesRaw, rates), MAX_ZAP_IMBALANCE_RATIO);
    }

    /**
     * @notice Exact-in on rate-scaled book via Balancer StableMath; fee-on-output after quote.
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
        uint256[4] memory xpFixed = _scaleReserves(c.reserves, c.rates);
        uint256[] memory xp = _toDyn(xpFixed);
        uint256 invariant = StableMath.computeInvariant(c.amp, xp);
        uint256 amountInScaled = scaleTo(amountIn, c.rates[c.i]);
        uint256 amountOutScaled =
            StableMath.computeOutGivenExactIn(c.amp, xp, c.i, c.j, amountInScaled, invariant);
        (amountOut,) = feeOnOutputExactIn(descale(amountOutScaled, c.rates[c.j]), c.lpFeePips);
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

        uint256[4] memory xpFixed = _scaleReserves(c.reserves, c.rates);
        uint256[] memory xp = _toDyn(xpFixed);
        uint256 invariant = StableMath.computeInvariant(c.amp, xp);
        uint256 amountOutScaled = scaleToUp(grossOut, c.rates[c.j]);
        if (amountOutScaled >= xp[c.j]) revert InvariantFailed();
        uint256 amountInScaled =
            StableMath.computeInGivenExactOut(c.amp, xp, c.i, c.j, amountOutScaled, invariant);
        amountIn = descaleUp(amountInScaled, c.rates[c.i]);
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
    /*                          dynamic array helpers                         */
    /* ---------------------------------------------------------------------- */

    function toDynamic(uint256[4] memory fixed_) internal pure returns (uint256[] memory dyn) {
        dyn = new uint256[](N_TOKENS);
        dyn[0] = fixed_[0];
        dyn[1] = fixed_[1];
        dyn[2] = fixed_[2];
        dyn[3] = fixed_[3];
    }

    function toFixed4(uint256[] memory dyn) internal pure returns (uint256[4] memory fixed_) {
        if (dyn.length != N_TOKENS) revert ZeroAmount();
        fixed_[0] = dyn[0];
        fixed_[1] = dyn[1];
        fixed_[2] = dyn[2];
        fixed_[3] = dyn[3];
    }

    function mulDivCeil(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        if (d == 0) revert ZeroAmount();
        if (a == 0 || b == 0) return 0;
        return (a * b + (d - 1)) / d;
    }
}
