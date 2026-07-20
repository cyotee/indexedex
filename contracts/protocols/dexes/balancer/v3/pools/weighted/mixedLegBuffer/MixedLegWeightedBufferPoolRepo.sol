// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegWeightedBufferPoolRepo
 * @notice Storage for mixed unpaired + buffered-pair weighted pool (max 8 tokens).
 */
library MixedLegWeightedBufferPoolRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.weighted.mixedLegBuffer");

    uint8 internal constant MAX_UNPAIRED = 8;
    uint8 internal constant MAX_PAIRS = 4;
    uint8 internal constant MAX_TOKENS = 8;

    struct Storage {
        uint8 unpairedCount;
        uint8 pairCount;
        address expectedFactory;
        // Unpaired legs (physical math balances).
        IERC20[MAX_UNPAIRED] unpairedTokens;
        IRateProvider[MAX_UNPAIRED] unpairedRateProviders;
        uint8[MAX_UNPAIRED] unpairedIndices;
        // Pairs (buffer virtual + derived share).
        IERC20[MAX_PAIRS] bufferTokens;
        IERC20[MAX_PAIRS] shareTokens;
        IStandardExchange[MAX_PAIRS] standardExchangeVaults;
        IRateProvider[MAX_PAIRS] pairRateProviders;
        uint8[MAX_PAIRS] bufferIndices;
        uint8[MAX_PAIRS] shareIndices;
        uint256[MAX_TOKENS] weights;
        uint256[MAX_PAIRS] virtualBuffers;
        int256[MAX_PAIRS] hookShareDeltas;
        uint8 pendingPreSeatPair;
        uint256 pendingPreSeatS;
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

    function _pairCount() internal view returns (uint8) {
        return _layout().pairCount;
    }

    function _tokenCount() internal view returns (uint256) {
        Storage storage l = _layout();
        return uint256(l.unpairedCount) + uint256(l.pairCount) * 2;
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

    function _bufferToken(uint256 i) internal view returns (IERC20) {
        return _layout().bufferTokens[i];
    }

    function _shareToken(uint256 i) internal view returns (IERC20) {
        return _layout().shareTokens[i];
    }

    function _standardExchangeVault(uint256 i) internal view returns (IStandardExchange) {
        return _layout().standardExchangeVaults[i];
    }

    function _pairRateProvider(uint256 i) internal view returns (IRateProvider) {
        return _layout().pairRateProviders[i];
    }

    function _bufferIndex(uint256 i) internal view returns (uint256) {
        return _layout().bufferIndices[i];
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

    function _virtualBuffer(uint256 i) internal view returns (uint256) {
        return _layout().virtualBuffers[i];
    }

    function _setVirtualBuffer(uint256 i, uint256 v) internal {
        _layout().virtualBuffers[i] = v;
    }

    function _hookShareDelta(uint256 i) internal view returns (int256) {
        return _layout().hookShareDeltas[i];
    }

    function _setHookShareDelta(uint256 i, int256 v) internal {
        _layout().hookShareDeltas[i] = v;
    }

    function _setPendingPreSeat(uint8 pairIndex, uint256 s) internal {
        Storage storage l = _layout();
        l.pendingPreSeatPair = pairIndex;
        l.pendingPreSeatS = s;
    }

    function _clearPendingPreSeat() internal {
        Storage storage l = _layout();
        l.pendingPreSeatPair = 0;
        l.pendingPreSeatS = 0;
    }

    function _resolveToken(address token)
        internal
        view
        returns (IMixedLegWeightedBufferPool.TokenKind kind, uint256 legIndex)
    {
        Storage storage l = _layout();
        uint8 u = l.unpairedCount;
        for (uint256 i; i < u; ++i) {
            if (address(l.unpairedTokens[i]) == token) {
                return (IMixedLegWeightedBufferPool.TokenKind.Unpaired, i);
            }
        }
        uint8 p = l.pairCount;
        for (uint256 i; i < p; ++i) {
            if (address(l.bufferTokens[i]) == token) {
                return (IMixedLegWeightedBufferPool.TokenKind.Buffer, i);
            }
            if (address(l.shareTokens[i]) == token) {
                return (IMixedLegWeightedBufferPool.TokenKind.Share, i);
            }
        }
        revert IMixedLegWeightedBufferPool.UnknownPoolToken(token);
    }

    function _resolveTokenIndex(uint256 tokenIndex)
        internal
        view
        returns (IMixedLegWeightedBufferPool.TokenKind kind, uint256 legIndex)
    {
        Storage storage l = _layout();
        uint8 u = l.unpairedCount;
        for (uint256 i; i < u; ++i) {
            if (uint256(l.unpairedIndices[i]) == tokenIndex) {
                return (IMixedLegWeightedBufferPool.TokenKind.Unpaired, i);
            }
        }
        uint8 p = l.pairCount;
        for (uint256 i; i < p; ++i) {
            if (uint256(l.bufferIndices[i]) == tokenIndex) {
                return (IMixedLegWeightedBufferPool.TokenKind.Buffer, i);
            }
            if (uint256(l.shareIndices[i]) == tokenIndex) {
                return (IMixedLegWeightedBufferPool.TokenKind.Share, i);
            }
        }
        revert IMixedLegWeightedBufferPool.UnknownPoolToken(address(uint160(tokenIndex)));
    }

    /// @dev Bundled init args to avoid stack-too-deep (viaIR disabled).
    struct InitParams {
        uint8 unpairedCount;
        uint8 pairCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRps;
        uint8[] unpairedIndices;
        IERC20[] bufferTokens;
        IERC20[] shareTokens;
        IStandardExchange[] vaults;
        IRateProvider[] pairRps;
        uint8[] bufferIndices;
        uint8[] shareIndices;
        uint256[] weights;
        address expectedFactory;
    }

    function _initialize(InitParams memory p) internal {
        Storage storage l = _layout();
        l.unpairedCount = p.unpairedCount;
        l.pairCount = p.pairCount;
        l.expectedFactory = p.expectedFactory;
        uint8 u = p.unpairedCount;
        for (uint256 i; i < u; ++i) {
            l.unpairedTokens[i] = p.unpairedTokens[i];
            l.unpairedRateProviders[i] = p.unpairedRps[i];
            l.unpairedIndices[i] = p.unpairedIndices[i];
        }
        uint8 pc = p.pairCount;
        for (uint256 i; i < pc; ++i) {
            l.bufferTokens[i] = p.bufferTokens[i];
            l.shareTokens[i] = p.shareTokens[i];
            l.standardExchangeVaults[i] = p.vaults[i];
            l.pairRateProviders[i] = p.pairRps[i];
            l.bufferIndices[i] = p.bufferIndices[i];
            l.shareIndices[i] = p.shareIndices[i];
        }
        uint256 n = uint256(u) + uint256(pc) * 2;
        for (uint256 t; t < n; ++t) {
            l.weights[t] = p.weights[t];
        }
    }
}
