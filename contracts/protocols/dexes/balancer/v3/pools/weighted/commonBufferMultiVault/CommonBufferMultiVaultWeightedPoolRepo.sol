// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";

/**
 * @title CommonBufferMultiVaultWeightedPoolRepo
 * @notice Diamond storage: U unpaired + 1 buffer + N vault shares.
 */
library CommonBufferMultiVaultWeightedPoolRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.weighted.commonBufferMultiVault");

    uint8 internal constant MAX_UNPAIRED = 6;
    uint8 internal constant MAX_VAULTS = 7;
    uint8 internal constant MAX_TOKENS = 8;

    struct Storage {
        uint8 unpairedCount;
        uint8 vaultCount;
        address expectedFactory;
        IERC20[MAX_UNPAIRED] unpairedTokens;
        IRateProvider[MAX_UNPAIRED] unpairedRateProviders;
        uint8[MAX_UNPAIRED] unpairedIndices;
        IERC20 bufferToken;
        uint8 bufferIndex;
        IERC20[MAX_VAULTS] shareTokens;
        IStandardExchange[MAX_VAULTS] standardExchangeVaults;
        IRateProvider[MAX_VAULTS] vaultShareRateProviders;
        uint8[MAX_VAULTS] shareIndices;
        uint256[MAX_TOKENS] weights;
        uint256 virtualBuffer;
        int256[MAX_VAULTS] hookShareDeltas;
        uint8 pendingPreSeatVault;
        uint256 pendingPreSeatS;
        bool pendingPreSeatActive;
    }

    function _layout() internal pure returns (Storage storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _unpairedCount() internal view returns (uint8) {
        return _layout().unpairedCount;
    }

    function _vaultCount() internal view returns (uint8) {
        return _layout().vaultCount;
    }

    function _tokenCount() internal view returns (uint256) {
        Storage storage l = _layout();
        return uint256(l.unpairedCount) + 1 + uint256(l.vaultCount);
    }

    function _expectedFactory() internal view returns (address) {
        return _layout().expectedFactory;
    }

    function _unpairedToken(uint256 i) internal view returns (IERC20) {
        return _layout().unpairedTokens[i];
    }

    function _unpairedRateProvider(uint256 i) internal view returns (IRateProvider) {
        return _layout().unpairedRateProviders[i];
    }

    function _unpairedIndex(uint256 i) internal view returns (uint256) {
        return _layout().unpairedIndices[i];
    }

    function _bufferToken() internal view returns (IERC20) {
        return _layout().bufferToken;
    }

    function _bufferIndex() internal view returns (uint256) {
        return _layout().bufferIndex;
    }

    function _shareToken(uint256 i) internal view returns (IERC20) {
        return _layout().shareTokens[i];
    }

    function _standardExchangeVault(uint256 i) internal view returns (IStandardExchange) {
        return _layout().standardExchangeVaults[i];
    }

    function _vaultShareRateProvider(uint256 i) internal view returns (IRateProvider) {
        return _layout().vaultShareRateProviders[i];
    }

    function _shareIndex(uint256 i) internal view returns (uint256) {
        return _layout().shareIndices[i];
    }

    function _weight(uint256 tokenIndex) internal view returns (uint256) {
        return _layout().weights[tokenIndex];
    }

    function _weightsMemory() internal view returns (uint256[] memory w) {
        uint256 n = _tokenCount();
        w = new uint256[](n);
        Storage storage l = _layout();
        for (uint256 i; i < n; ++i) {
            w[i] = l.weights[i];
        }
    }

    function _virtualBuffer() internal view returns (uint256) {
        return _layout().virtualBuffer;
    }

    function _setVirtualBuffer(uint256 v) internal {
        _layout().virtualBuffer = v;
    }

    function _hookShareDelta(uint256 i) internal view returns (int256) {
        return _layout().hookShareDeltas[i];
    }

    function _setHookShareDelta(uint256 i, int256 v) internal {
        _layout().hookShareDeltas[i] = v;
    }

    function _setPendingPreSeat(uint8 vaultIndex, uint256 s) internal {
        Storage storage l = _layout();
        l.pendingPreSeatVault = vaultIndex;
        l.pendingPreSeatS = s;
        l.pendingPreSeatActive = true;
    }

    function _clearPendingPreSeat() internal {
        Storage storage l = _layout();
        l.pendingPreSeatVault = 0;
        l.pendingPreSeatS = 0;
        l.pendingPreSeatActive = false;
    }

    function _resolveToken(address token)
        internal
        view
        returns (ICommonBufferMultiVaultWeightedPool.TokenKind kind, uint256 legIndex)
    {
        Storage storage l = _layout();
        if (address(l.bufferToken) == token) {
            return (ICommonBufferMultiVaultWeightedPool.TokenKind.Buffer, 0);
        }
        uint8 u = l.unpairedCount;
        for (uint256 i; i < u; ++i) {
            if (address(l.unpairedTokens[i]) == token) {
                return (ICommonBufferMultiVaultWeightedPool.TokenKind.Unpaired, i);
            }
        }
        uint8 n = l.vaultCount;
        for (uint256 i; i < n; ++i) {
            if (address(l.shareTokens[i]) == token) {
                return (ICommonBufferMultiVaultWeightedPool.TokenKind.Share, i);
            }
        }
        revert ICommonBufferMultiVaultWeightedPool.UnknownPoolToken(token);
    }

    function _resolveTokenIndex(uint256 tokenIndex)
        internal
        view
        returns (ICommonBufferMultiVaultWeightedPool.TokenKind kind, uint256 legIndex)
    {
        Storage storage l = _layout();
        if (uint256(l.bufferIndex) == tokenIndex) {
            return (ICommonBufferMultiVaultWeightedPool.TokenKind.Buffer, 0);
        }
        uint8 u = l.unpairedCount;
        for (uint256 i; i < u; ++i) {
            if (uint256(l.unpairedIndices[i]) == tokenIndex) {
                return (ICommonBufferMultiVaultWeightedPool.TokenKind.Unpaired, i);
            }
        }
        uint8 n = l.vaultCount;
        for (uint256 i; i < n; ++i) {
            if (uint256(l.shareIndices[i]) == tokenIndex) {
                return (ICommonBufferMultiVaultWeightedPool.TokenKind.Share, i);
            }
        }
        revert ICommonBufferMultiVaultWeightedPool.UnknownPoolToken(address(uint160(tokenIndex)));
    }

    struct InitParams {
        uint8 unpairedCount;
        uint8 vaultCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRps;
        uint8[] unpairedIndices;
        IERC20 bufferToken;
        uint8 bufferIndex;
        IERC20[] shareTokens;
        IStandardExchange[] vaults;
        IRateProvider[] vaultShareRps;
        uint8[] shareIndices;
        uint256[] weights;
        address expectedFactory;
    }

    function _initialize(InitParams memory p) internal {
        Storage storage l = _layout();
        l.unpairedCount = p.unpairedCount;
        l.vaultCount = p.vaultCount;
        l.expectedFactory = p.expectedFactory;
        l.bufferToken = p.bufferToken;
        l.bufferIndex = p.bufferIndex;
        uint8 u = p.unpairedCount;
        for (uint256 i; i < u; ++i) {
            l.unpairedTokens[i] = p.unpairedTokens[i];
            l.unpairedRateProviders[i] = p.unpairedRps[i];
            l.unpairedIndices[i] = p.unpairedIndices[i];
        }
        uint8 n = p.vaultCount;
        for (uint256 i; i < n; ++i) {
            l.shareTokens[i] = p.shareTokens[i];
            l.standardExchangeVaults[i] = p.vaults[i];
            l.vaultShareRateProviders[i] = p.vaultShareRps[i];
            l.shareIndices[i] = p.shareIndices[i];
        }
        uint256 t = uint256(u) + 1 + uint256(n);
        for (uint256 i; i < t; ++i) {
            l.weights[i] = p.weights[i];
        }
    }
}
