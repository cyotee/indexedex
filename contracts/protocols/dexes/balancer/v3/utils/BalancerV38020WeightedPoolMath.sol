// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

/**
 * @title BalancerV38020WeightedPoolMath
 * @notice Math library for 80/20 weighted pool operations used by seigniorage DETF.
 * @dev Provides calculations for:
 *      - Proportional liquidity deposits/withdrawals
 *      - Single-sided liquidity operations
 *      - Spot price calculations with decimal normalization
 *      - Delta calculations to reach target prices
 */
library BalancerV38020WeightedPoolMath {
    using FixedPoint for uint256;

    /* ---------------------------------------------------------------------- */
    /*                               Constants                                */
    /* ---------------------------------------------------------------------- */

    /// @notice Minimum total supply amount for pool initialization
    uint256 internal constant _POOL_MINIMUM_TOTAL_SUPPLY = 1e6;

    /// @notice WAD constant for 18 decimal precision
    uint256 private constant WAD = 1e18;

    /* ---------------------------------------------------------------------- */
    /*                               Errors                                   */
    /* ---------------------------------------------------------------------- */

    error ZeroInvariant();
    error InvalidTokenIndex();

    /* ---------------------------------------------------------------------- */
    /*                     Proportional Deposit Functions                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculate equivalent proportional amounts given amount of one token.
     * @dev For an 80/20 pool, computes the other token amount to maintain proportionality.
     * @param balances Current pool balances [token0, token1] (scaled to 18 decimals).
     * @param normalizedWeights Normalized weights (e.g., [0.8e18, 0.2e18]).
     * @param totalSupply Current total BPT supply.
     * @param tokenIndex Index of the given token (0 or 1).
     * @param amountIn Amount of the given token.
     * @return otherAmount Amount of the other token needed for proportionality.
     */
    function calcEquivalentProportionalGivenSingle(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 totalSupply,
        uint256 tokenIndex,
        uint256 amountIn
    ) internal pure returns (uint256 otherAmount) {
        require(balances.length == 2 && normalizedWeights.length == 2, "80/20 pool only");
        require(normalizedWeights[0] + normalizedWeights[1] == FixedPoint.ONE, "weights sum != 1e18");

        if (amountIn == 0) return 0;

        uint256 otherIndex = 1 - tokenIndex;

        if (totalSupply == 0) {
            // Empty pool: force initial ratio to match configured weights
            otherAmount = amountIn.mulUp(normalizedWeights[otherIndex].divDown(normalizedWeights[tokenIndex]));
        } else {
            // Normal case: keep current balance ratio exactly the same
            otherAmount = amountIn.mulUp(balances[otherIndex].divUp(balances[tokenIndex]));
        }
    }

    /**
     * @notice Calculate equivalent proportional amounts and expected BPT out.
     * @param balances Current pool balances [token0, token1] (scaled).
     * @param normalizedWeights Normalized weights [0.8e18, 0.2e18].
     * @param totalSupply Current total BPT supply.
     * @param tokenIndex Index of the given token (0 or 1).
     * @param amountIn Amount of the given token.
     * @return otherAmount Amount of the other token needed for proportionality.
     * @return bptOut BPT minted if deposited proportionally.
     */
    function calcEquivalentProportionalGivenSingleAndBPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 totalSupply,
        uint256 tokenIndex,
        uint256 amountIn
    ) internal pure returns (uint256 otherAmount, uint256 bptOut) {
        require(balances.length == 2 && normalizedWeights.length == 2, "80/20 only");
        require(normalizedWeights[0] + normalizedWeights[1] == FixedPoint.ONE, "weights must sum to 1e18");
        if (amountIn == 0) return (0, 0);

        uint256 otherIndex = 1 - tokenIndex;

        if (totalSupply == 0) {
            // Initial deposit: proportional = deposit in weight ratio
            otherAmount = amountIn.mulUp(normalizedWeights[otherIndex].divDown(normalizedWeights[tokenIndex]));

            uint256[] memory postDepositBalances = new uint256[](2);
            postDepositBalances[tokenIndex] = amountIn;
            postDepositBalances[otherIndex] = otherAmount;

            bptOut = WeightedMath.computeInvariantDown(normalizedWeights, postDepositBalances);
            bptOut -= _POOL_MINIMUM_TOTAL_SUPPLY;
        } else {
            // Normal case: keep current balance ratio
            otherAmount = amountIn.mulUp(balances[otherIndex].divUp(balances[tokenIndex]));

            // BPT minted = totalSupply * (amountIn / balances[tokenIndex])
            uint256 ratio = amountIn.divDown(balances[tokenIndex]);
            bptOut = totalSupply.mulDown(ratio);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      BPT Calculation Functions                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculate BPT out for an unbalanced deposit.
     * @param balances Current pool balances (live scaled to 18 decimals).
     * @param normalizedWeights Normalized weights array.
     * @param amountsIn Exact amounts of tokens to deposit.
     * @param totalSupply Current total BPT supply.
     * @param swapFeePercentage Pool swap fee (e.g., 0.01e18 for 1%).
     * @return BPT minted (rounded down).
     */
    function calcBptOutGivenUnbalancedIn(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsIn,
        uint256 totalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        require(balances.length == 2 && normalizedWeights.length == 2 && amountsIn.length == 2, "80/20 pool only");
        if (totalSupply == 0) return 0;

        // Check if all amountsIn are zero
        bool allZero = true;
        for (uint256 i = 0; i < 2; ++i) {
            if (amountsIn[i] > 0) {
                allZero = false;
                require(amountsIn[i] <= balances[i].mulDown(WeightedMath._MAX_IN_RATIO), "Exceeds max in ratio");
            }
        }
        if (allZero) return 0;

        // Compute new balances with full amountsIn
        uint256[] memory newBalances = new uint256[](2);
        for (uint256 i = 0; i < 2; ++i) {
            newBalances[i] = balances[i] + amountsIn[i];
        }

        // Compute invariants
        uint256 currentInvariant = WeightedMath.computeInvariantUp(normalizedWeights, balances);
        uint256 newInvariant = WeightedMath.computeInvariantDown(normalizedWeights, newBalances);

        // Compute invariant ratio
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);
        if (invariantRatio <= FixedPoint.ONE) return 0;
        require(invariantRatio <= WeightedMath._MAX_INVARIANT_RATIO, "Exceeds max invariant ratio");

        // Compute proportional balances, taxable amounts, and fees
        for (uint256 i = 0; i < 2; ++i) {
            uint256 proportionalBalance = balances[i].mulDown(invariantRatio);
            uint256 taxableAmount = newBalances[i] > proportionalBalance ? newBalances[i] - proportionalBalance : 0;
            uint256 swapFee = taxableAmount.mulUp(swapFeePercentage);
            newBalances[i] -= swapFee;
        }

        // Compute new invariant with fees applied
        uint256 invariantWithFeesApplied = WeightedMath.computeInvariantDown(normalizedWeights, newBalances);

        // BPT out = totalSupply * (invariantWithFeesApplied - currentInvariant) / currentInvariant
        return (totalSupply * (invariantWithFeesApplied - currentInvariant)) / currentInvariant;
    }

    /**
     * @notice Calculate BPT out for a proportional deposit.
     * @param balances Current pool balances [token0, token1].
     * @param normalizedWeights Normalized weights.
     * @param totalSupply Current total BPT supply.
     * @param amountsIn Proportional amounts of tokens to deposit.
     * @return bptOut BPT minted.
     */
    function calcBptOutGivenProportionalIn(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 totalSupply,
        uint256[] memory amountsIn
    ) internal pure returns (uint256 bptOut) {
        require(balances.length == 2 && amountsIn.length == 2 && normalizedWeights.length == 2, "80/20 pool only");
        require(normalizedWeights[0] + normalizedWeights[1] == FixedPoint.ONE, "weights must sum to 1e18");

        if (amountsIn[0] == 0 && amountsIn[1] == 0) return 0;

        uint256 DELTA = 1e9; // Tolerance for proportionality check

        if (totalSupply == 0) {
            // Initial deposit: amounts must be in weight ratio
            uint256 sizeFactor0 = amountsIn[0].divDown(normalizedWeights[0]);
            uint256 sizeFactor1 = amountsIn[1].divDown(normalizedWeights[1]);

            require(
                sizeFactor0 >= sizeFactor1 ? sizeFactor0 - sizeFactor1 <= DELTA : sizeFactor1 - sizeFactor0 <= DELTA,
                "Non-proportional amounts (initial)"
            );

            uint256[] memory postBalances = new uint256[](2);
            postBalances[0] = amountsIn[0];
            postBalances[1] = amountsIn[1];

            uint256 invariant = WeightedMath.computeInvariantDown(normalizedWeights, postBalances);
            bptOut = invariant > _POOL_MINIMUM_TOTAL_SUPPLY ? invariant - _POOL_MINIMUM_TOTAL_SUPPLY : 0;

            if (invariant == 0 || bptOut == 0) revert ZeroInvariant();
        } else {
            // Normal case: check proportionality
            require(balances[0] > 0 && balances[1] > 0, "Zero balance");

            uint256 ratio = amountsIn[0].divDown(balances[0]);
            uint256 ratioOther = amountsIn[1].divDown(balances[1]);

            require(
                ratio >= ratioOther ? ratio - ratioOther <= DELTA : ratioOther - ratio <= DELTA,
                "Non-proportional amounts"
            );

            require(ratio <= WeightedMath._MAX_IN_RATIO, "Exceeds max in ratio");

            bptOut = totalSupply.mulDown(ratio);
        }
    }

    /**
     * @notice Calculate minimal BPT to burn for proportional withdrawal.
     * @param balances Current pool balances.
     * @param totalSupply Current total BPT supply.
     * @param desiredTokenIndex Index of the token for which amount out is specified.
     * @param desiredAmountOut Desired minimum amount out.
     * @return bptIn Minimal BPT to burn.
     */
    function calcBptInGivenProportionalOut(
        uint256[] memory balances,
        uint256 totalSupply,
        uint256 desiredTokenIndex,
        uint256 desiredAmountOut
    ) internal pure returns (uint256 bptIn) {
        require(balances.length == 2, "80/20 pool only");
        require(totalSupply > 0, "Zero total supply");
        require(desiredTokenIndex < 2, "Invalid token index");
        if (desiredAmountOut == 0) return 0;

        uint256 balance = balances[desiredTokenIndex];
        require(balance > 0, "Zero balance for desired token");
        require(desiredAmountOut <= balance.mulDown(WeightedMath._MAX_OUT_RATIO), "Exceeds max out ratio");

        uint256 numerator = desiredAmountOut.mulDown(totalSupply) + balance - 1;
        bptIn = numerator / balance;

        if (bptIn > totalSupply) {
            bptIn = totalSupply;
        }
    }

    /**
     * @notice Calculate proportional amounts out given BPT in.
     * @param balances Current pool balances.
     * @param totalSupply Current total BPT supply.
     * @param bptIn Exact BPT burned.
     * @return amountsOut Proportional amounts out for each token.
     */
    function calcProportionalAmountsOutGivenBptIn(uint256[] memory balances, uint256 totalSupply, uint256 bptIn)
        internal
        pure
        returns (uint256[] memory amountsOut)
    {
        if (bptIn == 0) return new uint256[](balances.length);
        require(bptIn <= totalSupply, "Exceeds total supply");

        amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; ++i) {
            amountsOut[i] = (balances[i] * bptIn) / totalSupply;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                    Single-Sided Liquidity Functions                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculate BPT out for a single token deposit.
     * @param balances Current pool balances.
     * @param normalizedWeights Normalized weights.
     * @param tokenIndex Index of the deposited token.
     * @param amountIn Exact amount deposited.
     * @param totalSupply Current BPT total supply.
     * @param swapFeePercentage Pool swap fee.
     * @return BPT minted.
     */
    function calcBptOutGivenSingleIn(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 tokenIndex,
        uint256 amountIn,
        uint256 totalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        if (amountIn == 0) return 0;
        require(balances.length == 2 && normalizedWeights.length == 2, "80/20 pool only");
        require(amountIn <= balances[tokenIndex].mulDown(WeightedMath._MAX_IN_RATIO), "Exceeds max in ratio");

        uint256[] memory newBalances = new uint256[](2);
        for (uint256 i = 0; i < 2; ++i) {
            newBalances[i] = balances[i];
        }
        newBalances[tokenIndex] += amountIn;

        uint256 currentInvariant = WeightedMath.computeInvariantUp(normalizedWeights, balances);
        uint256 newInvariant = WeightedMath.computeInvariantDown(normalizedWeights, newBalances);

        uint256 invariantRatio = newInvariant.divDown(currentInvariant);
        if (invariantRatio <= FixedPoint.ONE) return 0;
        if (invariantRatio > WeightedMath._MAX_INVARIANT_RATIO) revert WeightedMath.MaxInRatio();

        uint256 proportionalTokenBalance = invariantRatio.mulDown(balances[tokenIndex]);
        uint256 taxableAmount =
            newBalances[tokenIndex] > proportionalTokenBalance ? newBalances[tokenIndex] - proportionalTokenBalance : 0;
        uint256 swapFee = taxableAmount.mulUp(swapFeePercentage);
        newBalances[tokenIndex] = newBalances[tokenIndex] - swapFee;

        uint256 invariantWithFeesApplied = WeightedMath.computeInvariantDown(normalizedWeights, newBalances);
        return (totalSupply * (invariantWithFeesApplied - currentInvariant)) / currentInvariant;
    }

    /**
     * @notice Calculate token out for a single token withdrawal.
     * @param balances Current pool balances.
     * @param normalizedWeights Normalized weights.
     * @param tokenIndex Index of the withdrawn token.
     * @param bptIn Exact BPT burned.
     * @param totalSupply Current BPT total supply.
     * @param swapFeePercentage Pool swap fee.
     * @return amountOut Token withdrawn.
     */
    function calcSingleOutGivenBptIn(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 tokenIndex,
        uint256 bptIn,
        uint256 totalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        if (bptIn == 0) return 0;
        require(balances.length == 2 && normalizedWeights.length == 2, "80/20 pool only");
        require(bptIn <= totalSupply, "Exceeds total supply");
        require(bptIn <= totalSupply.mulDown(WeightedMath._MAX_OUT_RATIO), "Exceeds max out ratio");

        uint256 newBalance;
        {
            uint256 invariantRatio = FixedPoint.divUp(totalSupply - bptIn, totalSupply);
            newBalance = WeightedMath.computeBalanceOutGivenInvariant(
                balances[tokenIndex], normalizedWeights[tokenIndex], invariantRatio
            );
        }

        uint256 amountOutBeforeFee = balances[tokenIndex] - newBalance;
        uint256 newSupply = totalSupply - bptIn;
        uint256 newBalanceBeforeTax = newSupply.mulDivUp(balances[tokenIndex], totalSupply);

        uint256 taxableAmount;
        unchecked {
            taxableAmount = newBalanceBeforeTax - newBalance;
        }

        uint256 swapFee = taxableAmount.mulUp(swapFeePercentage);
        uint256 amountOut = amountOutBeforeFee - swapFee;

        if (amountOut > balances[tokenIndex].mulDown(WeightedMath._MAX_OUT_RATIO)) {
            revert WeightedMath.MaxOutRatio();
        }

        return amountOut;
    }

    /* ---------------------------------------------------------------------- */
    /*                        Spot Price Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculate spot price (tokenA per tokenB) scaled to WAD.
     * @param balanceA Balance of tokenA in native decimals.
     * @param decimalsA Decimals of tokenA.
     * @param balanceB Balance of tokenB in native decimals.
     * @param decimalsB Decimals of tokenB.
     * @param weightA Normalized weight of tokenA (WAD).
     * @param weightB Normalized weight of tokenB (WAD).
     * @return spotPriceWad Spot price scaled to WAD.
     */
    function spotPriceAPerB(
        uint256 balanceA,
        uint8 decimalsA,
        uint256 balanceB,
        uint8 decimalsB,
        uint256 weightA,
        uint256 weightB
    ) internal pure returns (uint256) {
        uint256 normA = BetterMath._convertDecimalsFromTo(balanceA, decimalsA, 18);
        uint256 normB = BetterMath._convertDecimalsFromTo(balanceB, decimalsB, 18);
        require(normB > 0 && weightA > 0, "Division by zero");
        return (normA * weightB * WAD) / (normB * weightA);
    }

    /**
     * @notice Calculate spot price from reserves (simplified version).
     * @param baseCurrencyReserve Balance of base currency (scaled to 18 decimals).
     * @param quoteCurrencyReserve Balance of quote currency (scaled to 18 decimals).
     * @param baseCurrencyWeight Weight of base currency.
     * @param quoteCurrencyWeight Weight of quote currency.
     * @return Spot price scaled to WAD.
     */
    function priceFromReserves(
        uint256 baseCurrencyReserve,
        uint256 quoteCurrencyReserve,
        uint256 baseCurrencyWeight,
        uint256 quoteCurrencyWeight
    ) internal pure returns (uint256) {
        require(quoteCurrencyReserve > 0 && baseCurrencyWeight > 0, "Division by zero");
        return (baseCurrencyReserve * quoteCurrencyWeight * WAD) / (quoteCurrencyReserve * baseCurrencyWeight);
    }

    /**
     * @notice Calculate virtual spot price assuming virtual tokenA balance equals totalSupply.
     * @param totalSupply Virtual balance for tokenA.
     * @param decimalsA Decimals for the virtual tokenA.
     * @param balanceB Balance of tokenB in native decimals.
     * @param decimalsB Decimals of tokenB.
     * @param weightA Normalized weight of tokenA.
     * @param weightB Normalized weight of tokenB.
     * @return Virtual spot price scaled to WAD.
     */
    function virtualSpotPriceGivenTotalSupply(
        uint256 totalSupply,
        uint8 decimalsA,
        uint256 balanceB,
        uint8 decimalsB,
        uint256 weightA,
        uint256 weightB
    ) internal pure returns (uint256) {
        return spotPriceAPerB(totalSupply, decimalsA, balanceB, decimalsB, weightA, weightB);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Delta Calculation Functions                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Compute amount of tokenA to add to reach a target spot price.
     * @param balanceA Current balance of tokenA in native decimals.
     * @param decimalsA Decimals of tokenA.
     * @param balanceB Current balance of tokenB in native decimals.
     * @param decimalsB Decimals of tokenB.
     * @param weightA Normalized weight of tokenA.
     * @param weightB Normalized weight of tokenB.
     * @param targetPriceWad Target spot price (tokenA per tokenB) scaled to WAD.
     * @return deltaA Amount of tokenA to add.
     */
    function deltaAToReachTargetPrice(
        uint256 balanceA,
        uint8 decimalsA,
        uint256 balanceB,
        uint8 decimalsB,
        uint256 weightA,
        uint256 weightB,
        uint256 targetPriceWad
    ) internal pure returns (uint256) {
        uint256 normA = BetterMath._convertDecimalsFromTo(balanceA, decimalsA, 18);
        uint256 normB = BetterMath._convertDecimalsFromTo(balanceB, decimalsB, 18);
        uint256 currentPriceWad = spotPriceAPerB(balanceA, decimalsA, balanceB, decimalsB, weightA, weightB);
        if (targetPriceWad <= currentPriceWad) return 0;

        uint256 numerator = targetPriceWad * normB * weightA;
        uint256 denominator = weightB * WAD;
        uint256 targetNormA = numerator / denominator;
        if (targetNormA <= normA) return 0;

        uint256 normDeltaA = targetNormA - normA;
        return BetterMath._convertDecimalsFromTo(normDeltaA, 18, decimalsA);
    }

    /**
     * @notice Compute amount of tokenB to add to reach a target spot price.
     * @param balanceA Current balance of tokenA in native decimals.
     * @param decimalsA Decimals of tokenA.
     * @param balanceB Current balance of tokenB in native decimals.
     * @param decimalsB Decimals of tokenB.
     * @param weightA Normalized weight of tokenA.
     * @param weightB Normalized weight of tokenB.
     * @param targetPriceWad Target spot price (tokenA per tokenB) scaled to WAD.
     * @return deltaB Amount of tokenB to add.
     */
    function deltaBToReachTargetPrice(
        uint256 balanceA,
        uint8 decimalsA,
        uint256 balanceB,
        uint8 decimalsB,
        uint256 weightA,
        uint256 weightB,
        uint256 targetPriceWad
    ) internal pure returns (uint256) {
        uint256 normA = BetterMath._convertDecimalsFromTo(balanceA, decimalsA, 18);
        uint256 normB = BetterMath._convertDecimalsFromTo(balanceB, decimalsB, 18);
        uint256 currentPriceWad = spotPriceAPerB(balanceA, decimalsA, balanceB, decimalsB, weightA, weightB);
        if (targetPriceWad >= currentPriceWad) return 0;

        uint256 numerator = normA * weightB * WAD;
        uint256 denominator = targetPriceWad * weightA;
        uint256 targetNormB = numerator / denominator;
        if (targetNormB <= normB) return 0;

        uint256 normDeltaB = targetNormB - normB;
        return BetterMath._convertDecimalsFromTo(normDeltaB, 18, decimalsB);
    }

    /**
     * @notice Compute maximum single-token amount that can be deposited without exceeding max invariant ratio.
     * @param balances Current pool balances.
     * @param normalizedWeights Normalized weights array.
     * @param tokenIndex Index of the token being deposited.
     * @return maxAmountIn Maximum deposit amount.
     */
    function maxSingleInGivenMaxInvariantRatio(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        require(balances.length == 2 && normalizedWeights.length == 2, "80/20 pool only");

        uint256 currentInvariant = WeightedMath.computeInvariantUp(normalizedWeights, balances);
        uint256 perTokenMax = balances[tokenIndex].mulDown(WeightedMath._MAX_IN_RATIO);

        if (perTokenMax == 0) return 0;

        // Quick check: if full perTokenMax keeps invariant within limits, return it
        {
            uint256[] memory tmp = new uint256[](2);
            tmp[0] = balances[0];
            tmp[1] = balances[1];
            tmp[tokenIndex] += perTokenMax;
            uint256 newInvariant = WeightedMath.computeInvariantDown(normalizedWeights, tmp);
            uint256 invariantRatio = newInvariant.divDown(currentInvariant);
            if (invariantRatio <= WeightedMath._MAX_INVARIANT_RATIO) return perTokenMax;
        }

        // Binary search for max amount
        uint256 low = 0;
        uint256 high = perTokenMax;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;

            uint256[] memory tmp2 = new uint256[](2);
            tmp2[0] = balances[0];
            tmp2[1] = balances[1];
            tmp2[tokenIndex] += mid;

            uint256 newInvariant2 = WeightedMath.computeInvariantDown(normalizedWeights, tmp2);
            uint256 invariantRatio2 = newInvariant2.divDown(currentInvariant);

            if (invariantRatio2 <= WeightedMath._MAX_INVARIANT_RATIO) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        return low;
    }
}
