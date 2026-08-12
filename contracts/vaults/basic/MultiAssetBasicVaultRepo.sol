// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterArrays} from "@crane/contracts/utils/collections/BetterArrays.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

// tag:BasicVaultRepo[]
library MultiAssetBasicVaultRepo {
    /* ------------------------------ LIBRARIES ----------------------------- */

    using AddressSetRepo for AddressSet;
    using MultiAssetBasicVaultRepo for bytes32;

    /* -------------------------- STORAGE CONSTANTS ------------------------- */

    bytes32 private constant STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"));

    // tag::struct[]
    struct Storage {
        AddressSet _vaultTokens;
        mapping(address token => uint256 balance) _reserveOfToken;
    }

    // end::struct[]

    /* ------------------------------- Errors ------------------------------- */

    // tag::_layoutStruct(bytes32)[]
    /**
     * @dev "Binds" this struct to a storage slot.
     * @param slot_ The first slot to use in the range of slots used by the struct.
     * @return layoutStruct_ A struct from a layoutStruct library bound to the provided slot.
     */
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }
    // end::_layoutStruct(bytes32)[]

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, address[] memory tokens) internal {
        layoutStruct._vaultTokens._add(tokens);
    }

    function _initialize(address[] memory tokens) internal {
        _initialize(_layoutStruct(), tokens);
    }

    function _vaultTokens(Storage storage layoutStruct) internal view returns (address[] memory tokens_) {
        return layoutStruct._vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory tokens_) {
        return _vaultTokens(_layoutStruct());
    }

    function _addVaultToken(Storage storage layoutStruct, address token) internal {
        layoutStruct._vaultTokens._add(token);
    }

    function _addVaultToken(address token) internal {
        _addVaultToken(_layoutStruct(), token);
    }

    function _addVaultTokens(Storage storage layoutStruct, address[] memory tokens) internal {
        layoutStruct._vaultTokens._add(tokens);
    }

    function _addVaultTokens(address[] memory tokens) internal {
        _addVaultTokens(_layoutStruct(), tokens);
    }

    function _reserveOfToken(Storage storage layoutStruct, address token) internal view returns (uint256 reserve_) {
        return layoutStruct._reserveOfToken[address(token)];
    }

    function _reserveOfToken(address token) internal view returns (uint256 reserve_) {
        return _reserveOfToken(_layoutStruct(), token);
    }

    function _updateReserve(Storage storage layoutStruct, IERC20 token, uint256 newReserve) internal {
        layoutStruct._reserveOfToken[address(token)] = newReserve;
    }

    function _updateReserve(IERC20 token, uint256 newReserve) internal {
        _updateReserve(_layoutStruct(), token, newReserve);
    }

    function _reserves(Storage storage layoutStruct) internal view returns (uint256[] memory reserves_) {
        uint256 tokenCount = layoutStruct._vaultTokens._length();
        reserves_ = new uint256[](tokenCount);
        for (uint256 cursor = 0; cursor < tokenCount; ++cursor) {
            address token = layoutStruct._vaultTokens._index(cursor);
            reserves_[cursor] = layoutStruct._reserveOfToken[token];
        }
    }

    function _reserves() internal view returns (uint256[] memory reserves_) {
        return _reserves(_layoutStruct());
    }
}
// end::BasicVaultRepo[]
