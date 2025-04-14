// SPDX-License-Identifier: BUSL-1.1
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
    struct BasicVaultLayout {
        AddressSet _vaultTokens;
        mapping(address token => uint256 balance) _reserveOfToken;
    }

    // end::struct[]

    /* ------------------------------- Errors ------------------------------- */

    // tag::_layout(bytes32)[]
    /**
     * @dev "Binds" this struct to a storage slot.
     * @param slot_ The first slot to use in the range of slots used by the struct.
     * @return layout_ A struct from a Layout library bound to the provided slot.
     */
    function _layout(bytes32 slot_) internal pure returns (BasicVaultLayout storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }
    // end::_layout(bytes32)[]

    function _layout() internal pure returns (BasicVaultLayout storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(BasicVaultLayout storage layout_, address[] memory tokens) internal {
        layout_._vaultTokens._add(tokens);
    }

    function _initialize(address[] memory tokens) internal {
        _initialize(_layout(), tokens);
    }

    function _vaultTokens(BasicVaultLayout storage layout_) internal view returns (address[] memory tokens_) {
        return layout_._vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory tokens_) {
        return _vaultTokens(_layout());
    }

    function _addVaultToken(BasicVaultLayout storage layout_, address token) internal {
        layout_._vaultTokens._add(token);
    }

    function _addVaultToken(address token) internal {
        _addVaultToken(_layout(), token);
    }

    function _addVaultTokens(BasicVaultLayout storage layout_, address[] memory tokens) internal {
        layout_._vaultTokens._add(tokens);
    }

    function _addVaultTokens(address[] memory tokens) internal {
        _addVaultTokens(_layout(), tokens);
    }

    function _reserveOfToken(BasicVaultLayout storage layout_, address token) internal view returns (uint256 reserve_) {
        return layout_._reserveOfToken[address(token)];
    }

    function _reserveOfToken(address token) internal view returns (uint256 reserve_) {
        return _reserveOfToken(_layout(), token);
    }

    function _updateReserve(BasicVaultLayout storage layout_, IERC20 token, uint256 newReserve) internal {
        layout_._reserveOfToken[address(token)] = newReserve;
    }

    function _updateReserve(IERC20 token, uint256 newReserve) internal {
        _updateReserve(_layout(), token, newReserve);
    }

    function _reserves(BasicVaultLayout storage layout_) internal view returns (uint256[] memory reserves_) {
        uint256 tokenCount = layout_._vaultTokens._length();
        reserves_ = new uint256[](tokenCount);
        for (uint256 cursor = 0; cursor < tokenCount; ++cursor) {
            address token = layout_._vaultTokens._index(cursor);
            reserves_[cursor] = layout_._reserveOfToken[token];
        }
    }

    function _reserves() internal view returns (uint256[] memory reserves_) {
        return _reserves(_layout());
    }
}
// end::BasicVaultRepo[]
