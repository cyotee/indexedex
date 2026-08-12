// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPoint} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from
    "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookMath
 * @notice Pure dual-scale (inv/rated) + WeightedMath join/exit/swap helpers for SE Weighted Buffer Hook.
 * @dev rootK = V (full WeightedMath invariant) — LITERAL, no cbrt. No storage/calls.
 *      Wraps Crane Balancer WeightedMath + BasePoolMath-equivalent unbalanced joins.
 */
library UniswapV4StandardExchangeWeightedBufferHookMath {
    using FixedPoint for uint256;

    error ZeroAmount();
    error InvalidFeeWad();
    error MaxInRatio();
    error MaxOutRatio();
    error MaxInvariantRatio();
    error MinInvariantRatio();
    error WouldZeroReserve();
    error MathDomain();

    uint256 internal constant WAD = 1e18;
    uint256 internal constant ONE = 1e18;
    uint256 internal constant MIN_N = 2;
    uint256 internal constant MAX_N = 8;
    uint256 internal constant MIN_WEIGHT = 1e16;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_IN_RATIO = 30e16;
    uint256 internal constant MAX_OUT_RATIO = 30e16;
    uint256 internal constant MAX_INVARIANT_RATIO = 300e16;
    uint256 internal constant MIN_INVARIANT_RATIO = 70e16;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant RATE_PRECISION = 1e18;
    uint256 internal constant TICK_SPACING = 1;
    uint256 internal constant LP_SYMBOL_MAX = 32;
    uint256 internal constant LP_NAME_MAX = 64;

    /* ---------------------------------------------------------------------- */
    /*                              Scale / descaling                         */
    /* ---------------------------------------------------------------------- */

    /// @dev baseScale = 10^(36 - decimals) so scaleTo(a, baseScale) → 1e18-normalized when rate=1e18.
    function baseScaleFromDecimals(uint8 decimals) internal pure returns (uint256) {
        if (decimals < 6 || decimals > 18) revert MathDomain();
        return 10 ** (36 - uint256(decimals));
    }

    function scaleTo(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / RATE_PRECISION;
    }

    function scaleToUp(uint256 amount, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        return (amount * rate + RATE_PRECISION - 1) / RATE_PRECISION;
    }

    function descale(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        return (scaled * RATE_PRECISION) / rate;
    }

    function descaleUp(uint256 scaled, uint256 rate) internal pure returns (uint256) {
        if (rate == 0) revert MathDomain();
        return (scaled * RATE_PRECISION + rate - 1) / rate;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Fee helpers                               */
    /* ---------------------------------------------------------------------- */

    /// @dev Net after trading fee on input (floor residual stays in reserve).
    function applyTradingFeeNet(uint256 amountIn, uint256 feeWad) internal pure returns (uint256 net) {
        if (feeWad >= WAD) revert InvalidFeeWad();
        if (feeWad == 0) return amountIn;
        uint256 feeAmt = (amountIn * feeWad) / WAD;
        net = amountIn - feeAmt;
    }

    /// @dev Exact-out gross-up: ceil(net * 1e18 / (1e18 - fee)).
    function grossUpExactOut(uint256 netIn, uint256 feeWad) internal pure returns (uint256 gross) {
        if (feeWad >= WAD) revert InvalidFeeWad();
        if (feeWad == 0) return netIn;
        // pure ceil
        uint256 den = WAD - feeWad;
        gross = (netIn * WAD + den - 1) / den;
    }

    /// @dev V4 dynamic fee override pips | OVERRIDE_FEE_FLAG (0x400000).
    function feeOverridePips(uint256 feeWad) internal pure returns (uint24) {
        return uint24(uint256((feeWad * 1e6) / WAD) | 0x400000);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Invariant V / interim k                   */
    /* ---------------------------------------------------------------------- */

    /// @dev Full-book V = ∏ b_i^{w_i} (WeightedMath.computeInvariantDown).
    function _computeV(uint256[] memory weights, uint256[] memory scaledBalances) private pure returns (uint256) {
        return WeightedMath.computeInvariantDown(weights, scaledBalances);
    }

    function computeV(uint256[] memory weights, uint256[] memory scaledBalances) external pure returns (uint256) {
        return _computeV(weights, scaledBalances);
    }

    /// @dev Interim k on positive set with renormalized weights (PartialInterim).
    function _computeInterimK(
        uint256[] memory weights,
        uint256[] memory scaledBalances
    ) private pure returns (uint256 k) {
        uint256 n = weights.length;
        uint256 sumW;
        uint256 pos;
        for (uint256 i; i < n; ++i) {
            if (scaledBalances[i] > 0) {
                sumW += weights[i];
                ++pos;
            }
        }
        if (pos == 0 || sumW == 0) revert MathDomain();
        k = FixedPoint.ONE;
        for (uint256 i; i < n; ++i) {
            if (scaledBalances[i] == 0) continue;
            uint256 wPrime = (weights[i] * WAD) / sumW;
            k = k.mulDown(scaledBalances[i].powDown(wPrime));
        }
        if (k == 0) revert MathDomain();
    }

    function computeInterimK(
        uint256[] memory weights,
        uint256[] memory scaledBalances
    ) external pure returns (uint256 k) {
        return _computeInterimK(weights, scaledBalances);
    }

    /// @dev rootK = V literal for full book; interim k for partial.
    function rootKForMode(bool fullBook, uint256[] memory weights, uint256[] memory scaled)
        external
        pure
        returns (uint256 rootK)
    {
        if (fullBook) return _computeV(weights, scaled);
        return _computeInterimK(weights, scaled);
    }

    /// @dev Protocol LP: supply * (rootK - rootKLast) / (rootK * FEE_DENOM / ownerFeeShare + rootK - rootKLast)
    /// @notice rootK must already be V (full) or interim k (partial) — NOT cbrt.
    function protocolLpShares(
        uint256 supply,
        uint256 rootK,
        uint256 rootKLast,
        uint256 ownerFeeShare
    ) external pure returns (uint256) {
        if (supply == 0 || rootKLast == 0 || rootK <= rootKLast || ownerFeeShare == 0) {
            return 0;
        }
        uint256 num = supply * (rootK - rootKLast);
        uint256 den = (rootK * FEE_DENOMINATOR) / ownerFeeShare + rootK - rootKLast;
        if (den == 0) return 0;
        return num / den;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Swaps (fee on input)                      */
    /* ---------------------------------------------------------------------- */

    /// @dev Exact-in: fee on input; WeightedMath on net scaled; descales out floor.
    function quoteExactIn(
        uint256 balInScaled,
        uint256 wIn,
        uint256 balOutScaled,
        uint256 wOut,
        uint256 amountInRaw,
        uint256 rateIn,
        uint256 rateOut,
        uint256 feeWad
    ) external pure returns (uint256 amountOutRaw) {
        if (amountInRaw == 0) revert ZeroAmount();
        uint256 netIn = applyTradingFeeNet(amountInRaw, feeWad);
        if (netIn == 0) revert ZeroAmount();
        uint256 aInScaled = scaleTo(netIn, rateIn);
        // Pre-check Balancer max-in ratio (WeightedMath reverts MaxInRatio otherwise)
        if (aInScaled > balInScaled.mulDown(MAX_IN_RATIO)) revert MaxInRatio();
        uint256 outScaled =
            WeightedMath.computeOutGivenExactIn(balInScaled, wIn, balOutScaled, wOut, aInScaled);
        amountOutRaw = descale(outScaled, rateOut);
        if (amountOutRaw == 0) revert ZeroAmount();
    }

    /// @dev Exact-out: scale out up, compute in, descales up, gross-up for fee.
    function quoteExactOut(
        uint256 balInScaled,
        uint256 wIn,
        uint256 balOutScaled,
        uint256 wOut,
        uint256 amountOutRaw,
        uint256 rateIn,
        uint256 rateOut,
        uint256 feeWad
    ) external pure returns (uint256 amountInGross) {
        if (amountOutRaw == 0) revert ZeroAmount();
        uint256 aOutScaled = scaleToUp(amountOutRaw, rateOut);
        if (aOutScaled > balOutScaled.mulDown(MAX_OUT_RATIO)) revert MaxOutRatio();
        uint256 inScaled =
            WeightedMath.computeInGivenExactOut(balInScaled, wIn, balOutScaled, wOut, aOutScaled);
        uint256 netIn = descaleUp(inScaled, rateIn);
        amountInGross = grossUpExactOut(netIn, feeWad);
        if (amountInGross == 0) revert ZeroAmount();
    }

    /* ---------------------------------------------------------------------- */
    /*                              First mint                                */
    /* ---------------------------------------------------------------------- */

    /// @dev O2: shares = V - MINIMUM_LIQUIDITY (full book, all legs > 0 scaled).
    function firstMintSharesFull(uint256[] memory weights, uint256[] memory scaledAmounts)
        external
        pure
        returns (uint256 shares, uint256 V)
    {
        V = _computeV(weights, scaledAmounts);
        if (V <= MINIMUM_LIQUIDITY) revert MathDomain();
        shares = V - MINIMUM_LIQUIDITY;
    }

    /// @dev O4 partial first mint: interim k on positive set; shares = k - MIN.
    function firstMintSharesPartial(uint256[] memory weights, uint256[] memory scaledAmounts)
        external
        pure
        returns (uint256 shares, uint256 k)
    {
        k = _computeInterimK(weights, scaledAmounts);
        if (k <= MINIMUM_LIQUIDITY) revert MathDomain();
        shares = k - MINIMUM_LIQUIDITY;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Proportional join/exit                    */
    /* ---------------------------------------------------------------------- */

    /// @dev Uni V2 min-ratio on scaled domain for all positive legs (full or partial subset).
    function proportionalJoinShares(
        uint256[] memory amountScaled,
        uint256[] memory reserveScaled,
        uint256 supply
    ) external pure returns (uint256 shares) {
        if (supply == 0) revert MathDomain();
        shares = type(uint256).max;
        bool any;
        for (uint256 i; i < amountScaled.length; ++i) {
            if (reserveScaled[i] == 0) continue;
            if (amountScaled[i] == 0) revert ZeroAmount();
            uint256 s = (amountScaled[i] * supply) / reserveScaled[i];
            if (s < shares) shares = s;
            any = true;
        }
        if (!any || shares == 0 || shares == type(uint256).max) revert MathDomain();
    }

    function proportionalUsedScaled(uint256 shares, uint256 reserveScaled, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        return (shares * reserveScaled) / supply;
    }

    function proportionalExitAmounts(
        uint256 shares,
        uint256[] memory reserves,
        uint256 supply
    ) external pure returns (uint256[] memory amounts) {
        if (shares == 0 || supply == 0) revert ZeroAmount();
        amounts = new uint256[](reserves.length);
        for (uint256 i; i < reserves.length; ++i) {
            amounts[i] = (shares * reserves[i]) / supply;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     Unbalanced join (BasePoolMath-equivalent)          */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Mirror BasePoolMath.computeAddLiquidityUnbalanced in pure WeightedMath domain.
     * @param currentScaled balances rate-scaled
     * @param amountsScaled exact amounts in (scaled)
     * @param weights normalized weights
     * @param supply post-protocol totalSupply
     * @param swapFeeWad trading fee WAD (0 OK)
     */
    function _unbalancedJoinShares(
        uint256[] memory currentScaled,
        uint256[] memory amountsScaled,
        uint256[] memory weights,
        uint256 supply,
        uint256 swapFeeWad
    ) private pure returns (uint256 bptOut) {
        if (supply == 0) revert MathDomain();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        uint256 n = currentScaled.length;
        uint256[] memory newBalances = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            // Undo balance round-up peer: -1 on new balance path when amount > 0
            uint256 add = amountsScaled[i];
            newBalances[i] = currentScaled[i] + add;
            if (add > 0 && newBalances[i] > 0) {
                unchecked {
                    newBalances[i] -= 1;
                }
            }
        }
        uint256 currentInvariant = WeightedMath.computeInvariantUp(weights, currentScaled);
        uint256 newInvariant = WeightedMath.computeInvariantDown(weights, newBalances);
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);
        if (invariantRatio > MAX_INVARIANT_RATIO) revert MaxInvariantRatio();

        for (uint256 i; i < n; ++i) {
            uint256 proportionalTokenBalance = invariantRatio.mulDown(currentScaled[i]);
            if (newBalances[i] > proportionalTokenBalance) {
                uint256 taxableAmount;
                unchecked {
                    taxableAmount = newBalances[i] - proportionalTokenBalance;
                }
                uint256 feeAmount = taxableAmount.mulUp(swapFeeWad);
                newBalances[i] = newBalances[i] - feeAmount;
            }
        }
        uint256 invariantWithFees = WeightedMath.computeInvariantDown(weights, newBalances);
        if (invariantWithFees <= currentInvariant) revert MathDomain();
        bptOut = (supply * (invariantWithFees - currentInvariant)) / currentInvariant;
        if (bptOut == 0) revert ZeroAmount();
    }

    function unbalancedJoinShares(
        uint256[] memory currentScaled,
        uint256[] memory amountsScaled,
        uint256[] memory weights,
        uint256 supply,
        uint256 swapFeeWad
    ) external pure returns (uint256 bptOut) {
        return _unbalancedJoinShares(currentScaled, amountsScaled, weights, supply, swapFeeWad);
    }

    /// @dev Single-asset exact-out shares → amountIn scaled (with swap fee on taxable).
    function singleJoinExactOutAmountIn(
        uint256[] memory currentScaled,
        uint256[] memory weights,
        uint256 tokenInIndex,
        uint256 exactBptOut,
        uint256 supply,
        uint256 swapFeeWad
    ) external pure returns (uint256 amountInScaled) {
        if (supply == 0 || exactBptOut == 0) revert ZeroAmount();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        uint256 newSupply = supply + exactBptOut;
        uint256 invariantRatio = newSupply.divUp(supply);
        if (invariantRatio > MAX_INVARIANT_RATIO) revert MaxInvariantRatio();

        uint256 newBalance = WeightedMath.computeBalanceOutGivenInvariant(
            currentScaled[tokenInIndex], weights[tokenInIndex], invariantRatio
        );
        uint256 amountIn = newBalance - currentScaled[tokenInIndex];
        // non-taxable = proportional share of balance growth
        uint256 nonTaxableBalance = (newSupply * currentScaled[tokenInIndex]) / supply;
        uint256 taxableAmount = newBalance > nonTaxableBalance ? newBalance - nonTaxableBalance : 0;
        // amountInWithFee = nonTaxable + taxable / (1 - fee)
        if (taxableAmount == 0 || swapFeeWad == 0) {
            amountInScaled = amountIn;
        } else {
            uint256 feeFactor = WAD - swapFeeWad;
            uint256 taxableWithFee = taxableAmount.divUp(feeFactor);
            amountInScaled = (nonTaxableBalance - currentScaled[tokenInIndex]) + taxableWithFee;
        }
        if (amountInScaled == 0) revert ZeroAmount();
    }

    /// @dev Single-asset exact-in → shares (wraps unbalanced with one leg).
    function singleJoinExactInShares(
        uint256[] memory currentScaled,
        uint256[] memory weights,
        uint256 tokenInIndex,
        uint256 amountInScaled,
        uint256 supply,
        uint256 swapFeeWad
    ) external pure returns (uint256 shares) {
        uint256 n = currentScaled.length;
        uint256[] memory amounts = new uint256[](n);
        amounts[tokenInIndex] = amountInScaled;
        return _unbalancedJoinShares(currentScaled, amounts, weights, supply, swapFeeWad);
    }

    /// @dev Single-asset exact-in exit: shares → amountOut raw-scaled domain then caller descales.
    function singleExitExactInAmountOut(
        uint256[] memory currentScaled,
        uint256[] memory weights,
        uint256 tokenOutIndex,
        uint256 sharesIn,
        uint256 supply,
        uint256 swapFeeWad
    ) external pure returns (uint256 amountOutScaled) {
        if (sharesIn == 0 || supply == 0 || sharesIn >= supply) revert MathDomain();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        uint256 newSupply = supply - sharesIn;
        uint256 invariantRatio = newSupply.divUp(supply); // < 1
        if (invariantRatio < MIN_INVARIANT_RATIO) revert MinInvariantRatio();

        uint256 newBalance = WeightedMath.computeBalanceOutGivenInvariant(
            currentScaled[tokenOutIndex], weights[tokenOutIndex], invariantRatio
        );
        // amountOut before fee = current - newBalance (pool-favoring)
        uint256 amountOut = currentScaled[tokenOutIndex] - newBalance;
        // taxable portion charged fee on output side of single exit (Balancer peer)
        uint256 nonTaxable = currentScaled[tokenOutIndex] - (newSupply * currentScaled[tokenOutIndex]) / supply;
        // For remove single: fee reduces amountOut
        if (amountOut > nonTaxable && swapFeeWad != 0) {
            uint256 taxable = amountOut - nonTaxable;
            uint256 feeAmount = taxable.mulUp(swapFeeWad);
            amountOutScaled = amountOut - feeAmount;
        } else {
            amountOutScaled = amountOut;
        }
        if (amountOutScaled == 0) revert ZeroAmount();
    }

    /// @dev Single-asset exact-out exit: amountOut → sharesIn.
    function singleExitExactOutSharesIn(
        uint256[] memory currentScaled,
        uint256[] memory weights,
        uint256 tokenOutIndex,
        uint256 amountOutScaled,
        uint256 supply,
        uint256 swapFeeWad
    ) external pure returns (uint256 sharesIn) {
        if (amountOutScaled == 0 || supply == 0) revert ZeroAmount();
        if (swapFeeWad >= WAD) revert InvalidFeeWad();
        // Gross-up amountOut for fee on taxable (approximate: treat full amount as taxable for pool safety)
        uint256 amountOutGross = amountOutScaled;
        if (swapFeeWad != 0) {
            // amountOut = nonTaxable + taxable*(1-fee) ≈ amountOutGross after inverse
            // Conservative: amountOutGross = ceil(amountOut / (1-fee))
            amountOutGross = amountOutScaled.divUp(WAD - swapFeeWad);
        }
        if (amountOutGross >= currentScaled[tokenOutIndex]) revert WouldZeroReserve();
        uint256 newBalance = currentScaled[tokenOutIndex] - amountOutGross;
        // invariant ratio from balance change via inverse weight
        // newBalance / current ≈ invariantRatio ^ (1/w)  ⇒  invariantRatio ≈ (new/current)^w
        uint256 balanceRatio = newBalance.divDown(currentScaled[tokenOutIndex]);
        uint256 invariantRatio = balanceRatio.powDown(weights[tokenOutIndex]);
        if (invariantRatio < MIN_INVARIANT_RATIO) revert MinInvariantRatio();
        // sharesIn = supply * (1 - invariantRatio)
        sharesIn = supply - invariantRatio.mulDown(supply);
        if (sharesIn == 0) revert ZeroAmount();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Partial helpers                           */
    /* ---------------------------------------------------------------------- */

    function countPositive(uint256[] memory amounts) internal pure returns (uint256 c) {
        for (uint256 i; i < amounts.length; ++i) {
            if (amounts[i] > 0) ++c;
        }
    }

    function isFullBookReserves(uint256[] memory reserves) internal pure returns (bool) {
        for (uint256 i; i < reserves.length; ++i) {
            if (reserves[i] == 0) return false;
        }
        return true;
    }

    /// @dev Partial seed+prop shares: k_after growth formula when seeding zeros.
    function partialJoinSharesFromK(
        uint256 supply,
        uint256 kBefore,
        uint256 kAfter
    ) external pure returns (uint256 shares) {
        if (supply == 0 || kBefore == 0 || kAfter <= kBefore) revert MathDomain();
        shares = (supply * (kAfter - kBefore)) / kBefore;
        if (shares == 0) revert ZeroAmount();
    }
}
