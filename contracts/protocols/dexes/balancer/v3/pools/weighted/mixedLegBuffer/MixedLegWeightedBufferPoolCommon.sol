// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {MixedLegWeightedBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";

/**
 * @title MixedLegWeightedBufferPoolCommon
 * @notice Math balances: unpaired = live Vault scaled; buffer = virtual; share = derived.
 */
abstract contract MixedLegWeightedBufferPoolCommon {
    function _vaultTokenRateAndScale(uint256 tokenIndex)
        internal
        view
        returns (uint256 rate, uint256 scalingFactor)
    {
        (uint256[] memory scalingFactors, uint256[] memory rates) =
            IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault())).getPoolTokenRates(address(this));
        rate = rates[tokenIndex];
        scalingFactor = scalingFactors[tokenIndex];
        if (rate == 0) revert IMixedLegWeightedBufferPool.RateProviderZero();
    }

    function _liftToScaled18Rated(uint256 rawAmount, uint256 tokenIndex) internal view returns (uint256) {
        if (rawAmount == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultTokenRateAndScale(tokenIndex);
        return Math.mulDiv(rawAmount * scalingFactor, rate, 1e18);
    }

    function _derivedShareDepth(uint256 pairIndex, uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (uint256)
    {
        uint256 sharesIdx = Repo._shareIndex(pairIndex);
        int256 h = Repo._hookShareDelta(pairIndex);
        uint256 actual = balancesLiveScaled18[sharesIdx];
        if (h <= 0) {
            unchecked {
                return actual + _liftToScaled18Rated(uint256(-h), sharesIdx);
            }
        }
        uint256 sub = _liftToScaled18Rated(uint256(h), sharesIdx);
        if (sub >= actual) return 0;
        unchecked {
            return actual - sub;
        }
    }

    function _mathBalances(uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (uint256[] memory balances)
    {
        uint256 n = Repo._tokenCount();
        balances = new uint256[](n);
        uint8 u = Repo._unpairedCount();
        for (uint256 i; i < u; ++i) {
            uint256 idx = Repo._unpairedIndex(i);
            balances[idx] = balancesLiveScaled18[idx];
        }
        uint8 p = Repo._pairCount();
        for (uint256 i; i < p; ++i) {
            balances[Repo._bufferIndex(i)] = Repo._virtualBuffer(i);
            balances[Repo._shareIndex(i)] = _derivedShareDepth(i, balancesLiveScaled18);
        }
    }

    function _mathBalanceAt(uint256 tokenIndex, uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (uint256)
    {
        (IMixedLegWeightedBufferPool.TokenKind kind, uint256 leg) = Repo._resolveTokenIndex(tokenIndex);
        if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) {
            return balancesLiveScaled18[tokenIndex];
        }
        if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
            return Repo._virtualBuffer(leg);
        }
        return _derivedShareDepth(leg, balancesLiveScaled18);
    }

    function _bv3SharesDonationRaw(uint256 desiredRaw, uint256 shareTokenIndex) internal view returns (uint256) {
        if (desiredRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultTokenRateAndScale(shareTokenIndex);
        uint256 denom = scalingFactor * rate;
        uint256 scaled = (desiredRaw * denom) / 1e18;
        return Math.mulDiv(scaled, 1e18, denom, Math.Rounding.Ceil);
    }

    function _bv3SharesRemoveOutRaw(uint256 sRaw, uint256 shareTokenIndex) internal view returns (uint256) {
        if (sRaw == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultTokenRateAndScale(shareTokenIndex);
        uint256 denom = scalingFactor * rate;
        uint256 scaled = Math.mulDiv(sRaw, denom, 1e18, Math.Rounding.Ceil);
        return (scaled * 1e18) / denom;
    }
}
