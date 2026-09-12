// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice One authorized Vault callback, bound to the current DETF reserve operation.
library DETFBalancerReserveSwapRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("indexedex.detf.balancer.reserve-swap")) - 1);

    struct Storage { bytes32 pendingSwap; }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }
    function _layoutStruct() internal pure returns (Storage storage s_) {
        return _layoutStruct(STORAGE_SLOT);
    }
    function _setPending(Storage storage s_, bytes32 hash_) internal { s_.pendingSwap = hash_; }
    function _setPending(bytes32 hash_) internal { _setPending(_layoutStruct(), hash_); }
}

