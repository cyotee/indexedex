// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {StableMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookMath
 * @notice Pure dual-scale + Balancer V3 StableMath n=4 + inventory LP / growth helpers.
 * @dev **AMP pin (LOCKED):** `amp = baseAmp * AMP_PRECISION` with `AMP_PRECISION=1e3`
 *      (Balancer StableMath identity — **not** classic Curve-100).
 *      Swaps use ratedWad + input residual fee (SE package fee model).
 *      LP / kLast use invWad (I1: geoMean4). Single-asset taxable portion uses dexSwapFee (mulUp).
 *      No storage / external calls.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookMath {
    error ZeroAmount();
    error InvalidFeeWad();
    error InvariantFailed();
    error MathDomain();
    error WouldZeroReserve();

    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RATE_PRECISION = 1e18;
    /// @dev Balancer V3 StableMath precision (not Curve-100).
    uint256 internal constant AMP_PRECISION = 1e3;
    /// @dev Human amplification upper bound (Balancer StableMath MAX_AMP).
    uint256 internal constant MAX_AMP = 50_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
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

    /// @dev Uni V2-style protocol LP mint from pre-trade growth of k.
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
    /*              Balancer StableMath getD / getY (n=4 fixed)               */
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
     * @param xp Rate-scaled (or invWad) balances [4]
     * @param amp Amplification including precision: baseAmp * AMP_PRECISION (1e3)
     */
    function getD(uint256[4] memory xp, uint256 amp) internal pure returns (uint256) {
        return _getD(xp, amp);
    }

    function _getD(uint256[4] memory xp, uint256 amp) private pure returns (uint256) {
        uint256 S;
        unchecked {
            S = xp[0] + xp[1] + xp[2] + xp[3];
        }
        if (S == 0) return 0;
        // Balancer StableMath requires all balances non-zero (no Curve-style zero-witness pad).
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) revert InvariantFailed();
        return StableMath.computeInvariant(amp, _toDyn(xp));
    }

    /**
     * @notice Solve for reserve at `j` given new balance of coin `i` is `x`, preserving D.
     * @dev Uses Balancer `computeBalance` (rounds up).
     */
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
        returns (uint256)
    {
        if (i == j || i >= N_TOKENS || j >= N_TOKENS) revert InvariantFailed();
        if (D == 0 || x == 0) revert InvariantFailed();
        uint256[] memory balances = _toDyn(xp);
        balances[i] = x;
        return StableMath.computeBalance(amp, balances, D, j);
    }

    /// @dev Solve for balance of coin `j` given invariant D (other balances fixed).
    function _getYd(uint256 j, uint256[4] memory xp, uint256 amp, uint256 D)
        private
        pure
        returns (uint256)
    {
        if (j >= N_TOKENS || D == 0) revert InvariantFailed();
        return StableMath.computeBalance(amp, _toDyn(xp), D, j);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Swaps on rated book (fee on input)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Exact-in on ratedWad balances; fee residual on input already applied by caller.
    /// @param xp Rated WAD balances [4]
    /// @param amountInRatedNet Fee-net amount already in rated WAD
    /// @param amp A' = baseAmp * AMP_PRECISION (1e3)
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

        uint256[] memory balances = _toDyn(xp);
        uint256 invariant = StableMath.computeInvariant(amp, balances);
        amountOutRated =
            StableMath.computeOutGivenExactIn(amp, balances, i, j, amountInRatedNet, invariant);
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

        uint256[] memory balances = _toDyn(xp);
        uint256 invariant = StableMath.computeInvariant(amp, balances);
        amountInRatedNet =
            StableMath.computeInGivenExactOut(amp, balances, i, j, amountOutRated, invariant);
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
     * @dev Balancer D growth + taxable above proportional ideal (StableMath invariant).
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
