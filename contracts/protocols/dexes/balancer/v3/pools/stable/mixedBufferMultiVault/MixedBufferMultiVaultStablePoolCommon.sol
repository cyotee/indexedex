// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    MixedBufferMultiVaultStablePoolRepo as Repo
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolRepo.sol";

/**
 * @title MixedBufferMultiVaultStablePoolCommon
 * @notice Math balances (unpaired physical + virtualBuffer + derived shares) + depth-only ranking.
 */
abstract contract MixedBufferMultiVaultStablePoolCommon {
    function _vaultTokenRateAndScale(uint256 tokenIndex) internal view returns (uint256 rate, uint256 scalingFactor) {
        (uint256[] memory scalingFactors, uint256[] memory rates) =
            IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault())).getPoolTokenRates(address(this));
        rate = rates[tokenIndex];
        scalingFactor = scalingFactors[tokenIndex];
        if (rate == 0) revert IMixedBufferMultiVaultStablePool.RateProviderZero();
    }

    function _liftToScaled18Rated(uint256 rawAmount, uint256 tokenIndex) internal view returns (uint256) {
        if (rawAmount == 0) return 0;
        (uint256 rate, uint256 scalingFactor) = _vaultTokenRateAndScale(tokenIndex);
        return Math.mulDiv(rawAmount * scalingFactor, rate, 1e18);
    }

    function _derivedShareDepth(uint256 vaultIndex, uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (uint256)
    {
        uint256 sharesIdx = Repo._shareIndex(vaultIndex);
        int256 h = Repo._hookShareDelta(vaultIndex);
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

    function _mathBalances(uint256[] memory balancesLiveScaled18) internal view returns (uint256[] memory balances) {
        uint256 n = Repo._tokenCount();
        balances = new uint256[](n);
        uint8 u = Repo._unpairedCount();
        for (uint256 i; i < u; ++i) {
            uint256 idx = Repo._unpairedIndex(i);
            balances[idx] = balancesLiveScaled18[idx];
        }
        balances[Repo._bufferIndex()] = Repo._virtualBuffer();
        uint8 vc = Repo._vaultCount();
        for (uint256 i; i < vc; ++i) {
            balances[Repo._shareIndex(i)] = _derivedShareDepth(i, balancesLiveScaled18);
        }
    }

    function _mathBalanceAt(uint256 tokenIndex, uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        (IMixedBufferMultiVaultStablePool.TokenKind kind, uint256 leg) = Repo._resolveTokenIndex(tokenIndex);
        if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired) {
            return balancesLiveScaled18[tokenIndex];
        }
        if (kind == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
            return Repo._virtualBuffer();
        }
        return _derivedShareDepth(leg, balancesLiveScaled18);
    }

    /// @dev Score = derived depth only (no weights).
    function _score(uint256 vaultIndex, uint256[] memory balancesLiveScaled18) internal view returns (uint256) {
        return _derivedShareDepth(vaultIndex, balancesLiveScaled18);
    }

    function _betterForDeposit(uint256 a, uint256 b, uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (bool)
    {
        uint256 sa = _score(a, balancesLiveScaled18);
        uint256 sb = _score(b, balancesLiveScaled18);
        if (sa < sb) return true;
        if (sa > sb) return false;
        return a < b;
    }

    function _betterForRedeem(uint256 a, uint256 b, uint256[] memory balancesLiveScaled18)
        internal
        view
        returns (bool)
    {
        uint256 sa = _score(a, balancesLiveScaled18);
        uint256 sb = _score(b, balancesLiveScaled18);
        if (sa > sb) return true;
        if (sa < sb) return false;
        return a < b;
    }

    function _rankDeposit(uint256[] memory balancesLiveScaled18) internal view returns (uint8[] memory order) {
        uint8 n = Repo._vaultCount();
        order = new uint8[](n);
        for (uint8 i; i < n; ++i) {
            order[i] = i;
        }
        for (uint256 i = 1; i < n; ++i) {
            uint8 key = order[i];
            uint256 j = i;
            while (j > 0 && _betterForDeposit(key, order[j - 1], balancesLiveScaled18)) {
                order[j] = order[j - 1];
                unchecked {
                    --j;
                }
            }
            order[j] = key;
        }
    }

    function _rankRedeem(uint256[] memory balancesLiveScaled18) internal view returns (uint8[] memory order) {
        uint8 n = Repo._vaultCount();
        order = new uint8[](n);
        for (uint8 i; i < n; ++i) {
            order[i] = i;
        }
        for (uint256 i = 1; i < n; ++i) {
            uint8 key = order[i];
            uint256 j = i;
            while (j > 0 && _betterForRedeem(key, order[j - 1], balancesLiveScaled18)) {
                order[j] = order[j - 1];
                unchecked {
                    --j;
                }
            }
            order[j] = key;
        }
    }

    function _liveBalances() internal view returns (uint256[] memory) {
        return IVault(address(BalancerV3VaultAwareRepo._balancerV3Vault())).getCurrentLiveBalances(address(this));
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
