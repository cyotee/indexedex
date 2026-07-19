// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairStandardExchangeBufferPoolRepo
 * @notice Diamond storage for multi-pair weighted SE buffer pool.
 * @dev Max 4 pairs (8 Balancer tokens). Weights are stored in Balancer address-sorted token order.
 */
library MultiPairStandardExchangeBufferPoolRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.weighted.multiPairBuffer");

    uint8 internal constant MAX_PAIRS = 4;
    uint8 internal constant MAX_TOKENS = 8;

    struct Storage {
        uint8 pairCount;
        address expectedFactory;
        // Per-pair immutable config (indices 0..pairCount-1).
        IERC20[MAX_PAIRS] bufferTokens;
        IERC20[MAX_PAIRS] shareTokens;
        IStandardExchange[MAX_PAIRS] standardExchangeVaults;
        IRateProvider[MAX_PAIRS] rateProviders;
        uint8[MAX_PAIRS] bufferIndices;
        uint8[MAX_PAIRS] shareIndices;
        // Balancer-sorted weights for tokenCount = 2*pairCount slots.
        uint256[MAX_TOKENS] weights;
        // Live state.
        uint256[MAX_PAIRS] virtualBuffers;
        int256[MAX_PAIRS] hookShareDeltas;
        // Pre-seat scratch: pair whose buffer is being seated; zero flag in pendingPreSeatS.
        uint8 pendingPreSeatPair;
        uint256 pendingPreSeatS;
        // Reverse maps: token address => pair+1 (0 = unknown), and isBuffer flag via separate set.
        // Compact: pairOfToken stores pairIndex+1; isBufferToken bitmap not needed if we compare addresses.
    }

    function _layout() internal pure returns (Storage storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _pairCount() internal view returns (uint8) {
        return _layout().pairCount;
    }

    function _tokenCount() internal view returns (uint256) {
        return uint256(_layout().pairCount) * 2;
    }

    function _expectedFactory() internal view returns (address) {
        return _layout().expectedFactory;
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

    function _rateProvider(uint256 i) internal view returns (IRateProvider) {
        return _layout().rateProviders[i];
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

    function _pendingPreSeatPair() internal view returns (uint8) {
        return _layout().pendingPreSeatPair;
    }

    function _pendingPreSeatS() internal view returns (uint256) {
        return _layout().pendingPreSeatS;
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

    /**
     * @dev Resolve pool token address to (pairIndex, isBuffer). Reverts UnknownPoolToken.
     */
    function _resolveToken(address token)
        internal
        view
        returns (uint256 pairIndex, bool isBuffer)
    {
        Storage storage l = _layout();
        uint8 p = l.pairCount;
        for (uint256 i; i < p; ++i) {
            if (address(l.bufferTokens[i]) == token) return (i, true);
            if (address(l.shareTokens[i]) == token) return (i, false);
        }
        revert IMultiPairStandardExchangeBufferPool.UnknownPoolToken(token);
    }

    /**
     * @dev Resolve Balancer token index to (pairIndex, isBuffer).
     */
    function _resolveTokenIndex(uint256 tokenIndex)
        internal
        view
        returns (uint256 pairIndex, bool isBuffer)
    {
        Storage storage l = _layout();
        uint8 p = l.pairCount;
        for (uint256 i; i < p; ++i) {
            if (uint256(l.bufferIndices[i]) == tokenIndex) return (i, true);
            if (uint256(l.shareIndices[i]) == tokenIndex) return (i, false);
        }
        revert IMultiPairStandardExchangeBufferPool.UnknownPoolToken(address(uint160(tokenIndex)));
    }

    function _initialize(
        uint8 pairCount_,
        IERC20[] memory bufferTokens_,
        IERC20[] memory shareTokens_,
        IStandardExchange[] memory vaults_,
        IRateProvider[] memory rateProviders_,
        uint8[] memory bufferIndices_,
        uint8[] memory shareIndices_,
        uint256[] memory weights_,
        address expectedFactory_
    ) internal {
        Storage storage l = _layout();
        l.pairCount = pairCount_;
        l.expectedFactory = expectedFactory_;
        uint256 n = uint256(pairCount_) * 2;
        for (uint256 i; i < pairCount_; ++i) {
            l.bufferTokens[i] = bufferTokens_[i];
            l.shareTokens[i] = shareTokens_[i];
            l.standardExchangeVaults[i] = vaults_[i];
            l.rateProviders[i] = rateProviders_[i];
            l.bufferIndices[i] = bufferIndices_[i];
            l.shareIndices[i] = shareIndices_[i];
        }
        for (uint256 t; t < n; ++t) {
            l.weights[t] = weights_[t];
        }
    }
}
