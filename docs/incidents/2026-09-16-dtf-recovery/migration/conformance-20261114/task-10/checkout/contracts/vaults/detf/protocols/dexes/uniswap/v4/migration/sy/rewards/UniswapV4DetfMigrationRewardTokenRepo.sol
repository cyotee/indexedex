// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Fixed RT bindings and local phase; canonical ERC20Repo owns native balances and supply.
library UniswapV4DetfMigrationRewardTokenRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.reward.token"))) - 1);
    uint256 internal constant GONS_PER_UNIT = 1e18;

    error AlreadyInitialized();
    error InvalidRewardTokenBinding();

    struct Storage {
        address parent;
        address receipt;
        uint8 phase;
    }

    /// @notice Resolve fixed bindings at an explicit slot.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    /// @notice Resolve the canonical RT namespace.
    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    /// @notice Bind once, before any RT exists.
    function _initialize(Storage storage layoutStruct_, address parent_, address receipt_) internal {
        if (layoutStruct_.parent != address(0)) revert AlreadyInitialized();
        if (parent_ == address(0) || receipt_ == address(0) || parent_ == receipt_) {
            revert InvalidRewardTokenBinding();
        }
        layoutStruct_.parent = parent_;
        layoutStruct_.receipt = receipt_;
    }

    /// @notice Initialize the canonical bindings.
    function _initialize(address parent_, address receipt_) internal {
        _initialize(_layoutStruct(), parent_, receipt_);
    }
}
