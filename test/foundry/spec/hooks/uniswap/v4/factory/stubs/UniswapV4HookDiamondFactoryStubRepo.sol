// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

library UniswapV4HookDiamondFactoryStubRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.hooks.uniswap.v4.factory.stub"))) - 1);

    struct Storage {
        uint256 value;
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _set(uint256 value) internal {
        _layoutStruct().value = value;
    }

    function _value() internal view returns (uint256) {
        return _layoutStruct().value;
    }
}
