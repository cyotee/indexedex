// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {StableMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookMath
 * @notice Balancer V3 StableMath over 2–5 active normalized balances.
 * @dev **AMP pin (LOCKED):** `amp = baseAmp * AMP_PRECISION` with `AMP_PRECISION=1e3`
 *      (Balancer StableMath identity — **not** classic Curve-100).
 *      Swaps use ratedWad + input residual fee (SE package fee model).
 *      Bootstrap LP uses D(initial pair values) / n; subsequent liquidity uses the rated invariant.
 *      Protocol growth revalues checkpoint inventory at current SE rates to exclude passive yield.
 *      Physical LP ownership stays in native inventory. Liquidity rounding follows pinned BasePoolMath.
 *      Crane reference: 280799d7bd4c8d6ed85c6840c92afdc2d7370e18.
 *      No storage / external calls.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookMath {
    error ZeroAmount();
    error InvalidFeeWad();
    error InvariantFailed();
    error MathDomain();
    error WouldZeroReserve();
    error InvalidN();
    error InvariantRatioAboveMax(uint256 ratio, uint256 maxRatio);
    error InvariantRatioBelowMin(uint256 ratio, uint256 minRatio);

    uint256 internal constant MIN_TOKENS = 2;
    uint256 internal constant MAX_TOKENS = 5;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RATE_PRECISION = 1e18;
    /// @dev Balancer V3 StableMath precision (not Curve-100).
    uint256 internal constant AMP_PRECISION = 1e3;
    /// @dev Human amplification upper bound (Balancer StableMath MAX_AMP).
    uint256 internal constant MAX_AMP = 50_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant LP_SYMBOL_MAX = 32;
    uint256 internal constant LP_NAME_MAX = 64;
    int24 internal constant TICK_SPACING = 1;

    /* ---------------------------------------------------------------------- */
    /*                              Scale / descaling                         */
    /* ---------------------------------------------------------------------- */

    function baseScaleFromDecimals(uint8 decimals) internal pure returns (uint256) {
        if (decimals < 6 || decimals > 36) revert MathDomain();
        return 10 ** (36 - uint256(decimals));
    }

    function scaleTo(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDiv(amount, rate, RATE_PRECISION);
    }

    function scaleToUp(uint256 amount, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        if (amount == 0) return 0;
        return FixedPointMathLib.fullMulDivUp(amount, rate, RATE_PRECISION);
    }

    function descale(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        return FixedPointMathLib.fullMulDiv(scaled, RATE_PRECISION, rate);
    }

    function descaleUp(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        if (scaled == 0) return 0;
        return FixedPointMathLib.fullMulDivUp(scaled, RATE_PRECISION, rate);
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return FixedPointMathLib.fullMulDivUp(a, b, WAD);
    }

    function mulDivCeil(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        if (d == 0) revert ZeroAmount();
        if (a == 0 || b == 0) return 0;
        return FixedPointMathLib.fullMulDivUp(a, b, d);
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

    function _checkCount(uint256 n) private pure {
        if (n < MIN_TOKENS || n > MAX_TOKENS) revert InvalidN();
    }

    function _copy(uint256[] memory a) private pure returns (uint256[] memory b) {
        b = new uint256[](a.length);
        for (uint256 i; i < a.length; ++i) b[i] = a[i];
    }

    function getD(uint256[] memory balances, uint256 amp) internal pure returns (uint256) {
        _checkCount(balances.length);
        return StableMath.computeInvariant(amp, balances);
    }

    function _checkBalances(uint256[] memory balances) private pure {
        _checkCount(balances.length);
        (uint256 minimum, uint256 maximum) = StableMath.getMinAndMaxBalances(balances);
        if (minimum == 0) revert InvariantFailed();
        StableMath.ensureBalancesWithinMaxImbalanceRange(minimum, maximum);
    }

    function _invariant(uint256[] memory balances, uint256 amp, bool roundUp) private pure returns (uint256 d) {
        _checkBalances(balances);
        d = StableMath.computeInvariant(amp, balances);
        if (roundUp && d != 0) ++d;
    }

    function getY(uint256 i, uint256 j, uint256 x, uint256[] memory balances, uint256 amp, uint256 d)
        internal pure returns (uint256)
    {
        _checkCount(balances.length);
        if (i == j || i >= balances.length || j >= balances.length) revert InvariantFailed();
        uint256[] memory next = _copy(balances);
        next[i] = x;
        return StableMath.computeBalance(amp, next, d, j);
    }

    function _balanceForRatio(uint256[] memory balances, uint256 index, uint256 ratio, uint256 amp)
        private pure returns (uint256 result)
    {
        _checkCount(balances.length);
        if (index >= balances.length) revert InvalidN();
        uint256 d = StableMath.computeInvariant(amp, balances);
        if (d != 0) ++d;
        result = StableMath.computeBalance(amp, balances, mulUp(d, ratio), index);
        (uint256 minimum, uint256 maximum) = StableMath.getMinAndMaxBalances(balances);
        if (result < minimum) minimum = result;
        if (result > maximum) maximum = result;
        if (minimum == 0) revert InvariantFailed();
        StableMath.ensureBalancesWithinMaxImbalanceRange(minimum, maximum);
    }

    function _checkSwapBalances(uint256[] memory balances, uint256 i, uint256 j, uint256 amountIn, uint256 amountOut)
        private pure
    {
        (uint256 minimum, uint256 maximum) = StableMath.getMinAndMaxBalances(balances);
        uint256 nextIn = balances[i] + amountIn;
        uint256 nextOut = balances[j] - amountOut;
        if (nextIn > maximum) maximum = nextIn;
        if (nextOut < minimum) minimum = nextOut;
        if (minimum == 0) revert InvariantFailed();
        StableMath.ensureBalancesWithinMaxImbalanceRange(minimum, maximum);
    }

    function quoteExactInRated(uint256[] memory balances, uint256 i, uint256 j, uint256 amountIn, uint256 amp)
        internal pure returns (uint256 amountOut)
    {
        _checkCount(balances.length);
        if (i == j || i >= balances.length || j >= balances.length) revert InvariantFailed();
        uint256 d = StableMath.computeInvariant(amp, balances);
        amountOut = StableMath.computeOutGivenExactIn(amp, balances, i, j, amountIn, d);
        _checkSwapBalances(balances, i, j, amountIn, amountOut);
    }

    function quoteExactOutRated(uint256[] memory balances, uint256 i, uint256 j, uint256 amountOut, uint256 amp)
        internal pure returns (uint256 amountIn)
    {
        _checkCount(balances.length);
        if (i == j || i >= balances.length || j >= balances.length) revert InvariantFailed();
        uint256 d = StableMath.computeInvariant(amp, balances);
        amountIn = StableMath.computeInGivenExactOut(amp, balances, i, j, amountOut, d);
        _checkSwapBalances(balances, i, j, amountIn, amountOut);
    }

    /// @dev Normalize an invariant by its active currency count.
    function rootK(uint256[] memory invWad, uint256 amp) internal pure returns (uint256) {
        return _invariant(invWad, amp, false) / invWad.length;
    }

    function firstMintShares(uint256[] memory invWad, uint256 amp) internal pure returns (uint256 shares) {
        uint256 initialSupply = rootK(invWad, amp);
        if (initialSupply <= MINIMUM_LIQUIDITY) revert ZeroAmount();
        return initialSupply - MINIMUM_LIQUIDITY;
    }

    /// @dev IndexedEx fee attribution on inventory growth valued at common rates; separate from Balancer protocol fees.
    function protocolLpShares(uint256 supply, uint256 nowK, uint256 lastK, uint256 feeShare)
        internal pure returns (uint256)
    {
        if (supply == 0 || lastK == 0 || nowK <= lastK || feeShare == 0) return 0;
        uint256 denominator = FixedPointMathLib.fullMulDiv(nowK, FEE_DENOMINATOR, feeShare) + nowK - lastK;
        return FixedPointMathLib.fullMulDiv(supply, nowK - lastK, denominator);
    }

    function proportionalJoinShares(uint256[] memory amounts, uint256[] memory reserves, uint256 supply)
        internal pure returns (uint256 shares)
    {
        _checkCount(reserves.length);
        if (amounts.length != reserves.length) revert InvalidN();
        if (supply == 0) revert ZeroAmount();
        shares = type(uint256).max;
        for (uint256 i; i < reserves.length; ++i) {
            if (reserves[i] == 0 || amounts[i] == 0) revert ZeroAmount();
            uint256 candidate = FixedPointMathLib.fullMulDiv(amounts[i], supply, reserves[i]);
            if (candidate < shares) shares = candidate;
        }
        if (shares == 0) revert ZeroAmount();
    }

    function proportionalUsedWad(uint256 shares, uint256 reserve, uint256 supply) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDivUp(shares, reserve, supply);
    }

    function proportionalExitAmounts(uint256 shares, uint256[] memory reserves, uint256 supply)
        internal pure returns (uint256[] memory amounts)
    {
        _checkCount(reserves.length);
        if (shares == 0 || supply == 0) revert ZeroAmount();
        amounts = new uint256[](reserves.length);
        for (uint256 i; i < reserves.length; ++i) amounts[i] = FixedPointMathLib.fullMulDiv(shares, reserves[i], supply);
    }

    function _fee(uint256 feeWad) private pure {
        if (feeWad >= WAD) revert InvalidFeeWad();
    }

    function _maxRatio(uint256 ratio) private pure {
        if (ratio > StableMath.MAX_INVARIANT_RATIO) revert InvariantRatioAboveMax(ratio, StableMath.MAX_INVARIANT_RATIO);
    }

    function _minRatio(uint256 ratio) private pure {
        if (ratio < StableMath.MIN_INVARIANT_RATIO) revert InvariantRatioBelowMin(ratio, StableMath.MIN_INVARIANT_RATIO);
    }

    /// @dev Pinned BasePoolMath.computeAddLiquidityUnbalanced, with explicit immutable amp.
    function unbalancedJoinShares(uint256[] memory balances, uint256[] memory amounts, uint256 amp, uint256 supply, uint256 feeWad)
        internal pure returns (uint256)
    {
        _fee(feeWad);
        if (amounts.length != balances.length) revert InvalidN();
        uint256[] memory next = new uint256[](balances.length);
        for (uint256 i; i < next.length; ++i) next[i] = balances[i] + amounts[i] - 1;
        uint256 currentD = _invariant(balances, amp, true);
        uint256 ratio = FixedPointMathLib.fullMulDiv(_invariant(next, amp, false), WAD, currentD);
        _maxRatio(ratio);
        for (uint256 i; i < next.length; ++i) {
            uint256 proportional = FixedPointMathLib.fullMulDiv(ratio, balances[i], WAD);
            if (next[i] > proportional) next[i] -= mulUp(next[i] - proportional, feeWad);
        }
        return FixedPointMathLib.fullMulDiv(supply, _invariant(next, amp, false) - currentD, currentD);
    }

    function singleJoinExactInShares(uint256[] memory balances, uint256 amount, uint256 index, uint256 amp, uint256 supply, uint256 feeWad)
        internal pure returns (uint256)
    {
        if (index >= balances.length) revert InvalidN();
        if (amount == 0 || supply == 0) revert ZeroAmount();
        uint256[] memory amounts = new uint256[](balances.length);
        amounts[index] = amount;
        return unbalancedJoinShares(balances, amounts, amp, supply, feeWad);
    }

    function singleJoinExactOutAmountIn(uint256[] memory balances, uint256 shares, uint256 index, uint256 amp, uint256 supply, uint256 feeWad)
        internal pure returns (uint256)
    {
        _fee(feeWad);
        if (shares == 0 || supply == 0) revert ZeroAmount();
        uint256 nextSupply = supply + shares;
        uint256 ratio = FixedPointMathLib.fullMulDivUp(nextSupply, WAD, supply);
        _maxRatio(ratio);
        uint256 nextBalance = _balanceForRatio(balances, index, ratio, amp);
        uint256 amount = nextBalance - balances[index];
        uint256 taxable = nextBalance - FixedPointMathLib.fullMulDiv(nextSupply, balances[index], supply);
        return amount + FixedPointMathLib.fullMulDivUp(taxable, WAD, WAD - feeWad) - taxable;
    }

    function singleExitExactBptInAmountOut(uint256[] memory balances, uint256 shares, uint256 index, uint256 amp, uint256 supply, uint256 feeWad)
        internal pure returns (uint256)
    {
        _fee(feeWad);
        if (shares == 0 || supply == 0 || shares >= supply) revert MathDomain();
        uint256 nextSupply = supply - shares;
        uint256 ratio = FixedPointMathLib.fullMulDivUp(nextSupply, WAD, supply);
        _minRatio(ratio);
        uint256 nextBalance = _balanceForRatio(balances, index, ratio, amp);
        uint256 taxable = FixedPointMathLib.fullMulDivUp(nextSupply, balances[index], supply) - nextBalance;
        return balances[index] - nextBalance - mulUp(taxable, feeWad);
    }

    function singleExitExactTokenOutShares(uint256[] memory balances, uint256 amount, uint256 index, uint256 amp, uint256 supply, uint256 feeWad)
        internal pure returns (uint256)
    {
        _fee(feeWad);
        if (index >= balances.length) revert InvalidN();
        if (amount == 0 || supply == 0) revert ZeroAmount();
        uint256[] memory next = new uint256[](balances.length);
        for (uint256 i; i < next.length; ++i) next[i] = balances[i] - 1;
        next[index] -= amount;
        uint256 currentD = _invariant(balances, amp, true);
        uint256 ratio = FixedPointMathLib.fullMulDivUp(_invariant(next, amp, true), WAD, currentD);
        _minRatio(ratio);
        uint256 taxable = mulUp(ratio, balances[index]) - next[index];
        next[index] -= FixedPointMathLib.fullMulDivUp(taxable, WAD, WAD - feeWad) - taxable;
        return FixedPointMathLib.fullMulDivUp(supply, currentD - _invariant(next, amp, false), currentD);
    }

    function isFullBookReserves(uint256[] memory reserves) internal pure returns (bool) {
        if (reserves.length < MIN_TOKENS || reserves.length > MAX_TOKENS) return false;
        for (uint256 i; i < reserves.length; ++i) if (reserves[i] == 0) return false;
        return true;
    }

    function countPositive(uint256[] memory amounts) internal pure returns (uint256 count) {
        for (uint256 i; i < amounts.length; ++i) if (amounts[i] != 0) ++count;
    }

    function toDynamic(uint256[] memory amounts) internal pure returns (uint256[] memory) {
        return _copy(amounts);
    }
}
