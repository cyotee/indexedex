// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title UniswapV4HookFlagsRepo
 * @notice Diamond storage for required Uniswap V4 hook permission flags on hook instances.
 */
library UniswapV4HookFlagsRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.hooks.uniswap.v4.flags"))) - 1);

    struct Storage {
        uint160 requiredHookFlags;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _set(uint160 flags) internal {
        _layoutStruct().requiredHookFlags = flags;
    }

    function _requiredHookFlags() internal view returns (uint160) {
        return _layoutStruct().requiredHookFlags;
    }
}
