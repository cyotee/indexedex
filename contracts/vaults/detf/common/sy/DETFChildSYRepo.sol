// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title DETFChildSYRepo
/// @notice Immutable discovery of the two registered SY wrappers of a DETF.
library DETFChildSYRepo {
    bytes32 internal constant STORAGE_SLOT = bytes32(uint256(keccak256("indexedex.detf.child.sy")) - 1);

    struct Storage {
        address rawSY;
        address stakingSY;
    }

    error InvalidInitialization();

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly { layoutStruct_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) { return _layoutStruct(STORAGE_SLOT); }

    function _initialize(Storage storage s_, address raw_, address staking_) internal {
        if (s_.rawSY != address(0) || raw_ == address(0) || staking_ == address(0) || raw_ == staking_) {
            revert InvalidInitialization();
        }
        s_.rawSY = raw_;
        s_.stakingSY = staking_;
    }

    function _initialize(address raw_, address staking_) internal {
        _initialize(_layoutStruct(), raw_, staking_);
    }
}
