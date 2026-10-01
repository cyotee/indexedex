// SPDX-License-Identifier: BSL-1.1
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
        // To only be used for locally held token reserves, not for external accounting. For example, if a vault integrates with a DEX, this mapping would be used to store the locally held LP token balance, NOT the owned shares of deployed liquidity reserves in the DEX.
        // The primary usage for this mapping is to facilitate pretransfer and checks that pass-through operations did not change reserves.
        mapping(address token => uint256 balance) reserveOfToken;
    }

    // end::Storage[]

    /* ------------------------------- Errors ------------------------------- */

    // tag::_layoutStruct(bytes32)[]
    /**
     * @dev "Binds" this struct to a storage slot.
     * @param slot The first slot to use in the range of slots used by the struct.
     * @return layoutStruct A struct from a Repo library bound to the provided slot.
     */
    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }
    // end::_layoutStruct(bytes32)[]

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _initialize(Storage storage layoutStruct, address[] memory tokens) internal {
        layoutStruct.vaultTokens._add(tokens);
    }

    function _initialize(address[] memory tokens) internal {
        _initialize(_layoutStruct(), tokens);
    }

    function _vaultTokens(Storage storage layoutStruct) internal view returns (address[] memory tokens_) {
        return layoutStruct.vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory tokens_) {
        return _vaultTokens(_layoutStruct());
    }

    function _addVaultToken(Storage storage layoutStruct, address token) internal {
        layoutStruct.vaultTokens._add(token);
    }

    function _addVaultToken(address token) internal {
        _addVaultToken(_layoutStruct(), token);
    }

    function _addVaultTokens(Storage storage layoutStruct, address[] memory tokens) internal {
        layoutStruct.vaultTokens._add(tokens);
    }

    function _addVaultTokens(address[] memory tokens) internal {
        _addVaultTokens(_layoutStruct(), tokens);
    }

    function _reserveOfToken(Storage storage layoutStruct, address token) internal view returns (uint256 reserve_) {
        return layoutStruct.reserveOfToken[address(token)];
    }

    function _reserveOfToken(address token) internal view returns (uint256 reserve_) {
        return _reserveOfToken(_layoutStruct(), token);
    }

    /**
     * @dev Updates the locally held reserve of a token. This is only to be used for locally held token reserves, not for external accounting. For example, if a vault integrates with a DEX, this function would be used to store the locally held LP token balance, NOT the owned shares of deployed liquidity reserves in the DEX.
     * @param layoutStruct The storage struct to update.
     * @param token The token to update the reserve for.
     * @param newReserve The new reserve amount to set for the token.
     * @notice This function is intended to be used in conjunction with pretransfer and posttransfer checks to ensure that pass-through operations do not change the locally held reserves of tokens. It is important
     */
    function _updateReserve(Storage storage layoutStruct, IERC20 token, uint256 newReserve) internal {
        layoutStruct.reserveOfToken[address(token)] = newReserve;
    }

    /**
     * @dev Updates the locally held reserve of a token. This is only to be used for locally held token reserves, not for external accounting. For example, if a vault integrates with a DEX, this function would be used to store the locally held LP token balance, NOT the owned shares of deployed liquidity reserves in the DEX.
     * @param token The token to update the reserve for.
     * @param newReserve The new reserve amount to set for the token.
     * @notice This function is intended to be used in conjunction with pretransfer and posttransfer checks to ensure that pass-through operations do not change the locally held reserves of tokens. It is important
     */
    function _updateReserve(IERC20 token, uint256 newReserve) internal {
        _updateReserve(_layoutStruct(), token, newReserve);
    }

    /**
     * @dev Returns the locally held reserves of all vault tokens. This is only to be used for locally held token reserves, not for external accounting. For example, if a vault integrates with a DEX, this function would be used to return the locally held LP token balances, NOT the owned shares of deployed liquidity reserves in the DEX.
     * @param layoutStruct The storage struct to read from.
     * @return reserves_ An array of reserves corresponding to the vault tokens in the order they were stored in layoutStruct.vaultTokens.
     * @notice This function is intended to be used in conjunction with pretransfer and posttransfer checks to ensure that pass-through operations do not change the locally held reserves of tokens. It is important
     */
    function _reserves(Storage storage layoutStruct) internal view returns (uint256[] memory reserves_) {
        uint256 tokenCount = layoutStruct.vaultTokens._length();
        reserves_ = new uint256[](tokenCount);
        for (uint256 cursor = 0; cursor < tokenCount; ++cursor) {
            address token = layoutStruct.vaultTokens._index(cursor);
            reserves_[cursor] = layoutStruct.reserveOfToken[token];
        }
    }

    /**
     * @dev Returns the locally held reserves of all vault tokens. This is only to be used for locally held token reserves, not for external accounting. For example, if a vault integrates with a DEX, this function would be used to return the locally held LP token balances, NOT the owned shares of deployed liquidity reserves in the DEX.
     * @return reserves_ An array of reserves corresponding to the vault tokens in the order they were stored in layoutStruct.vaultTokens.
     * @notice This function is intended to be used in conjunction with pretransfer and posttransfer checks to ensure that pass-through operations do not change the locally held reserves of tokens. It is important
     */
    function _reserves() internal view returns (uint256[] memory reserves_) {
        return _reserves(_layoutStruct());
    }
}
// end::BasicVaultRepo[]
