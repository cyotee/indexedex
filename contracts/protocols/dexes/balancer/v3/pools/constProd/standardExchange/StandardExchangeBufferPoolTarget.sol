// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferPoolTarget
 * @notice Constant-product AMM pool target where x = virtualTTA (virtual, from storage) and
 *         y is derived from the Vault-supplied live shares balance minus the hook's accumulated delta.
 * @dev Implements IBalancerV3Pool (computeInvariant, computeBalance, onSwap).
 *      The share side is NOT taken from balancesLiveScaled18 directly; instead it is computed as:
 *        y = max(0, balancesLiveScaled18[sharesIdx] - hookSharesDelta_scaled18_rated)
 *      This allows the buffer hook to pre-seat redemption liquidity without altering the swap math
 *      until the hook delta is explicitly cleared.
 */
contract StandardExchangeBufferPoolTarget is IBalancerV3Pool {

    /* ----- Derived y (in scaled18 + rated units) ----- */

    /**
     * @dev Returns the effective shares-side depth used in AMM math, derived from the live balance
     *      minus the hook's accumulated reshuffling offset (hookSharesDelta).
     */
    function _derivedY(uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        uint256 sharesIdx = StandardExchangeBufferPoolRepo._sharesIndex();
        int256 h = StandardExchangeBufferPoolRepo._hookSharesDelta();
        uint256 actualSharesScaled = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            // Negative delta means hook added shares — effective depth is larger.
            uint256 add = _liftSharesToScaled18Rated(uint256(-h));
            unchecked { return actualSharesScaled + add; }
        }
        // Positive delta means hook removed shares from the effective pool side.
        uint256 sub = _liftSharesToScaled18Rated(uint256(h));
        if (sub >= actualSharesScaled) return 0;
        unchecked { return actualSharesScaled - sub; }
    }

    /**
     * @dev Converts a raw shares amount to scaled18+rated units, matching the representation
     *      that the Vault uses in balancesLiveScaled18.
     */
    function _liftSharesToScaled18Rated(uint256 rawShares) internal view returns (uint256) {
        if (rawShares == 0) return 0;
        uint256 rate = StandardExchangeBufferPoolRepo._rateProvider().getRate();
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint8 decimals = IERC20Metadata(address(StandardExchangeBufferPoolRepo._shareToken())).decimals();
        uint256 scaleFactor = 10 ** (uint256(18) - uint256(decimals));
        return Math.mulDiv(rawShares * scaleFactor, rate, 1e18);
    }

    /* ----- IBalancerV3Pool ----- */

    /**
     * @notice Computes the pool invariant: sqrt(virtualTTA * derivedY).
     * @param balancesLiveScaled18 Token balances after decimal scaling and rates (from Vault).
     * @param rounding Rounding direction.
     * @return invariant The pool invariant, scaled to 18 decimals.
     */
    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public view virtual override returns (uint256 invariant)
    {
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(balancesLiveScaled18);
        invariant = Math.sqrt(x * y);
        if (rounding != Rounding.ROUND_DOWN) invariant += 1;
    }

    /**
     * @notice Computes the new balance of a token after an operation given an invariant ratio.
     * @param balancesLiveScaled18 Current live balances (from Vault).
     * @param tokenInIndex Index of the token whose new balance is being computed.
     * @param invariantRatio Ratio of the new invariant to the old (scaled to 1e18).
     * @return newBalance The new balance of the selected token.
     */
    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public view virtual override returns (uint256 newBalance)
    {
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(balancesLiveScaled18);
        uint256 newInvariant = Math.mulDiv(Math.sqrt(x * y), invariantRatio, 1e18);
        uint256 other = (tokenInIndex == StandardExchangeBufferPoolRepo._ttaIndex()) ? y : x;
        newBalance = Math.mulDiv(newInvariant, newInvariant, other, Math.Rounding.Ceil);
    }

    /**
     * @notice Execute a swap in the pool using x * y = k constant product where
     *         x = virtualTTA and y = derivedY (effective shares depth).
     * @param params Swap parameters including balancesScaled18 from the Vault.
     * @return amountCalculatedScaled18 The calculated swap output (EXACT_IN) or input (EXACT_OUT).
     */
    function onSwap(PoolSwapParams calldata params)
        public view virtual override returns (uint256 amountCalculatedScaled18)
    {
        uint256 ttaIdx = StandardExchangeBufferPoolRepo._ttaIndex();
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(params.balancesScaled18);
        if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();
        if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

        bool ttaIn = (params.indexIn == ttaIdx);
        uint256 inSide = ttaIn ? x : y;
        uint256 outSide = ttaIn ? y : x;

        if (params.kind == SwapKind.EXACT_IN) {
            // dy = (outSide * dx) / (inSide + dx)
            amountCalculatedScaled18 =
                Math.mulDiv(outSide, params.amountGivenScaled18, inSide + params.amountGivenScaled18);
        } else {
            // dx = (inSide * dy) / (outSide - dy)
            amountCalculatedScaled18 = Math.mulDiv(
                inSide, params.amountGivenScaled18, outSide - params.amountGivenScaled18, Math.Rounding.Ceil
            );
        }
    }
}
