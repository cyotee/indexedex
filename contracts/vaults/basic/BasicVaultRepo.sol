// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterArrays} from "@crane/contracts/utils/collections/BetterArrays.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

// tag:BasicVaultRepo[]
library BasicVaultRepo {
    /* ------------------------------ LIBRARIES ----------------------------- */

    using AddressSetRepo for AddressSet;

    /* -------------------------- STORAGE CONSTANTS ------------------------- */

    bytes32 private constant STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"));

    // tag::Storage[]
    struct Storage {
        AddressSet vaultTokens;
        mapping(address token => uint256 balance) reserveOfToken;
    }

    // end::Storage[]

    /* ------------------------------- Errors ------------------------------- */

    // tag::_layout(bytes32)[]
    /**
     * @dev "Binds" this struct to a storage slot.
     * @param slot The first slot to use in the range of slots used by the struct.
     * @return layout A struct from a Repo library bound to the provided slot.
     */
    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }
    // end::_layout(bytes32)[]

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, address[] memory tokens) internal {
        layout.vaultTokens._add(tokens);
    }

    function _initialize(address[] memory tokens) internal {
        _initialize(_layout(), tokens);
    }

    function _vaultTokens(Storage storage layout) internal view returns (address[] memory tokens_) {
        return layout.vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory tokens_) {
        return _vaultTokens(_layout());
    }

    function _addVaultToken(Storage storage layout, address token) internal {
        layout.vaultTokens._add(token);
    }

    function _addVaultToken(address token) internal {
        _addVaultToken(_layout(), token);
    }

    function _addVaultTokens(Storage storage layout, address[] memory tokens) internal {
        layout.vaultTokens._add(tokens);
    }

    function _addVaultTokens(address[] memory tokens) internal {
        _addVaultTokens(_layout(), tokens);
    }

    function _reserveOfToken(Storage storage layout, address token) internal view returns (uint256 reserve_) {
        return layout.reserveOfToken[address(token)];
    }

    function _reserveOfToken(address token) internal view returns (uint256 reserve_) {
        return _reserveOfToken(_layout(), token);
    }

    function _updateReserve(Storage storage layout, IERC20 token, uint256 newReserve) internal {
        layout.reserveOfToken[address(token)] = newReserve;
    }

    function _updateReserve(IERC20 token, uint256 newReserve) internal {
        _updateReserve(_layout(), token, newReserve);
    }

    function _reserves(Storage storage layout) internal view returns (uint256[] memory reserves_) {
        uint256 tokenCount = layout.vaultTokens._length();
        reserves_ = new uint256[](tokenCount);
        for (uint256 cursor = 0; cursor < tokenCount; ++cursor) {
            address token = layout.vaultTokens._index(cursor);
            reserves_[cursor] = layout.reserveOfToken[token];
        }
    }

    function _reserves() internal view returns (uint256[] memory reserves_) {
        return _reserves(_layout());
    }
}
// end::BasicVaultRepo[]
