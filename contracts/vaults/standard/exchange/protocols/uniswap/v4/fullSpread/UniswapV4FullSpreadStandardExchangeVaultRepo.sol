// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

library UniswapV4FullSpreadStandardExchangeVaultRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1);

    struct Storage {
        uint256[2] booked;
        bytes32 callbackHash;
        uint256[2] reserved;
        bool guardHeld;
        bool initialized;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _booked(uint256 index_) internal view returns (uint256) {
        return _layoutStruct().booked[index_];
    }

    function _setBooked(uint256 index_, uint256 amount_) internal {
        _layoutStruct().booked[index_] = amount_;
    }

    function _reserved(uint256 index_) internal view returns (uint256) {
        return _layoutStruct().reserved[index_];
    }

    function _setReserved(uint256 index_, uint256 amount_) internal {
        _layoutStruct().reserved[index_] = amount_;
    }
}
