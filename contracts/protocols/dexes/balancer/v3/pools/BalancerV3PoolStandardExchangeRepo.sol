// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Authentication for the native BPT standard-route Vault callback.
library BalancerV3PoolStandardExchangeRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.balancer.v3.pool.standard.exchange"))) - 1);

    struct Storage { bytes32 pendingLiquidity; }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }
    function _layoutStruct() internal pure returns (Storage storage s_) { return _layoutStruct(STORAGE_SLOT); }
    function _setPending(Storage storage s_, bytes32 hash_) internal { s_.pendingLiquidity = hash_; }
    function _setPending(bytes32 hash_) internal { _setPending(_layoutStruct(), hash_); }
}
