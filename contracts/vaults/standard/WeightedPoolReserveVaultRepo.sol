// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

library WeightedPoolReserveVaultRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.weightedPoolReserve"));

    struct Storage {
        IWeightedPool reservePool;
        mapping(address token => uint256 indexInReservePool) indexInReservePoolOfToken;
        mapping(address token => uint256 weightInReservePool) weightInReservePoolOfToken;
        AddressSet reserveAssetContents;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout_) {
        return _layout(STORAGE_SLOT);
    }

    function _setReservePool(Storage storage layout_, IWeightedPool reservePool_) internal {
        layout_.reservePool = reservePool_;
    }

    function _reservePool(Storage storage layout_) internal view returns (IWeightedPool reservePool_) {
        return layout_.reservePool;
    }

    function _reservePool() internal view returns (IWeightedPool reservePool_) {
        return _reservePool(_layout());
    }

    function _setIndexInReservePool(Storage storage layout_, address token_, uint256 indexInReservePool_) internal {
        layout_.indexInReservePoolOfToken[token_] = indexInReservePool_;
    }

    function _indexInReservePool(Storage storage layout_, address token_)
        internal
        view
        returns (uint256 indexInReservePool_)
    {
        return layout_.indexInReservePoolOfToken[token_];
    }

    function _indexInReservePool(address token_) internal view returns (uint256 indexInReservePool_) {
        return _indexInReservePool(_layout(), token_);
    }

    function _setWeightInReservePool(Storage storage layout_, address token_, uint256 weightInReservePool_) internal {
        layout_.weightInReservePoolOfToken[token_] = weightInReservePool_;
    }

    function _weightInReservePool(Storage storage layout_, address token_)
        internal
        view
        returns (uint256 weightInReservePool_)
    {
        return layout_.weightInReservePoolOfToken[token_];
    }

    function _weightInReservePool(address token_) internal view returns (uint256 weightInReservePool_) {
        return _weightInReservePool(_layout(), token_);
    }

    function _isReserveAssetContents(Storage storage layout_, address token_) internal view returns (bool) {
        return layout_.reserveAssetContents._contains(token_);
    }

    function _isReserveAssetContents(address token_) internal view returns (bool) {
        return _isReserveAssetContents(_layout(), token_);
    }
}
