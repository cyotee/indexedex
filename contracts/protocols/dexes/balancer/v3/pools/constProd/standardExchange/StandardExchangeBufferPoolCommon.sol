// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferPoolCommon
 * @notice Shared helpers for the buffer pool target and hook target: Vault-sourced
 *         rate reads, rate-scaled effective weights, derived shares depth, and the
 *         Balancer V3 raw<->scaled18 round-trip mirrors.
 * @dev The share token's rate is ALWAYS read via `IVault.getPoolTokenRates(address(this))`
 *      so the pool math uses the exact rate the Vault applied when scaling balances and
 *      amounts. The pool never talks to the rate provider directly.
 */
abstract contract StandardExchangeBufferPoolCommon {

    /// @dev Minimum effective normalized weight (1%), mirroring Balancer weighted-pool bounds.
    uint256 internal constant _MIN_EFFECTIVE_WEIGHT = 1e16;

    /* ----- Vault-sourced rate ----- */

    /**
     * @dev Reads the share token's current rate and decimal scaling factor from the Vault —
     *      the same values the Vault used to build balancesLiveScaled18.
     *      Reverts RateProviderZero if the Vault reports a zero rate.
     */
    function _vaultSharesRateAndScale() internal view returns (uint256 rate, uint256 scalingFactor) {
        (uint256[] memory scalingFactors, uint256[] memory rates) =
            IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault())).getPoolTokenRates(address(this));
        uint256 sharesIdx = Repo._sharesIndex();
        rate = rates[sharesIdx];
        scalingFactor = scalingFactors[sharesIdx];
        if (rate == 0) revert IStandardExchangeBufferPool.RateProviderZero();
    }

    /* ----- Effective weights ----- */

    /**
     * @dev Normalized effective weights carrying the rate ratio:
     *        wShares/wTta = currentRate/baselineRate.
     *      At currentRate == baselineRate this is exactly 50/50 (the constant-product case).
     *      Marginal price identity: TTA per raw share = (wShares/wTta) * virtualTTA / parShares,
     *      i.e. the pool re-prices proportionally to the rate with no arbitrage flow.
     */
    function _effectiveWeights(uint256 currentRate, uint256 baselineRate_)
        internal pure returns (uint256 wTta, uint256 wShares)
    {
        uint256 rateRatio = Math.mulDiv(currentRate, 1e18, baselineRate_);
        wShares = Math.mulDiv(rateRatio, 1e18, rateRatio + 1e18);
        wTta = 1e18 - wShares;
        if (wTta < _MIN_EFFECTIVE_WEIGHT || wShares < _MIN_EFFECTIVE_WEIGHT) {
            revert IStandardExchangeBufferPool.EffectiveWeightOutOfBounds(wTta, wShares);
        }
    }

    /// @dev Effective weights for the pool's current state (Vault rate vs stored baseline).
    function _currentEffectiveWeights() internal view returns (uint256 wTta, uint256 wShares) {
        (uint256 rate, ) = _vaultSharesRateAndScale();
        return _effectiveWeights(rate, Repo._baselineRate());
    }

    /* ----- Derived shares depth (moved verbatim from the target/hook duplicates, with
             the rate read switched to the Vault) ----- */

    /**
     * @dev Effective shares-side depth used in AMM math: the live balance minus the
     *      hook's accumulated reshuffling offset (hookSharesDelta).
     */
    function _derivedY(uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        uint256 sharesIdx = Repo._sharesIndex();
        int256 h = Repo._hookSharesDelta();
        uint256 actualSharesScaled = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            uint256 add = _liftSharesToScaled18Rated(uint256(-h));
            unchecked { return actualSharesScaled + add; }
        }
        uint256 sub = _liftSharesToScaled18Rated(uint256(h));
        if (sub >= actualSharesScaled) return 0;
        unchecked { return actualSharesScaled - sub; }
    }

    /**
     * @dev Converts a raw shares amount to scaled18+rated units, matching the Vault's
     *      balancesLiveScaled18 representation (floor rounding, as the Vault's
     *      toScaled18ApplyRateRoundDown).
     */
    function _liftSharesToScaled18Rated(uint256 rawShares) internal view returns (uint256) {
        if (rawShares == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        return Math.mulDiv(rawShares * scalingFactor, rate, 1e18);
    }

    /* ----- Balancer V3 raw<->scaled18 round-trip mirrors (moved from the hook target,
             with the rate/decimals read switched to the Vault) ----- */

    /**
     * @dev Raw shares Balancer will charge as amountInRaw for a DONATION of `desiredRaw`:
     *        scaled      = floor(desiredRaw * scalingFactor * rate / 1e18)
     *        amountInRaw = ceil (scaled * 1e18 / (scalingFactor * rate))
     */
    function _bv3SharesDonationRaw(uint256 desiredRaw) internal view returns (uint256) {
        if (desiredRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        uint256 denom = scalingFactor * rate;
        uint256 scaled = (desiredRaw * denom) / 1e18;
        return Math.mulDiv(scaled, 1e18, denom, Math.Rounding.Ceil);
    }

    /**
     * @dev Raw shares Balancer will return as amountOutRaw for a removeLiquidity CUSTOM
     *      given `sRaw` as minAmountsOut:
     *        scaled       = ceil (sRaw * scalingFactor * rate / 1e18)
     *        amountOutRaw = floor(scaled * 1e18 / (scalingFactor * rate))
     */
    function _bv3SharesRemoveOutRaw(uint256 sRaw) internal view returns (uint256) {
        if (sRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultSharesRateAndScale();
        uint256 denom = scalingFactor * rate;
        uint256 scaled = Math.mulDiv(sRaw, denom, 1e18, Math.Rounding.Ceil);
        return (scaled * 1e18) / denom;
    }
}
