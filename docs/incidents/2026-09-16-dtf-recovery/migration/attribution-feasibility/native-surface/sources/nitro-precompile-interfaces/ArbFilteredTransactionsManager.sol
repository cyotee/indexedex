// Copyright 2025, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.4.21 <0.9.0;

/**
 * @title Enables ability to filter transactions by authorized callers.
 * @notice Authorized callers are added/removed through ArbOwner precompile.
 *         Available in ArbOS version 60 and above
 */
interface ArbFilteredTransactionsManager {
    /// @notice Emitted when a transaction hash is added to the filtered transactions list.
    event FilteredTransactionAdded(bytes32 indexed txHash);

    /// @notice Emitted when a transaction hash is removed from the filtered transactions list.
    event FilteredTransactionDeleted(bytes32 indexed txHash);

    /// @notice Marks the given transaction hash as filtered
    /// @param txHash The transaction hash to filter
    function addFilteredTransaction(
        bytes32 txHash
    ) external;

    /// @notice Removes filtering mark for the given transaction hash
    /// @param txHash The transaction hash to unfilter
    function deleteFilteredTransaction(
        bytes32 txHash
    ) external;

    /// @notice Checks whether the given transaction hash is filtered
    /// @param txHash The transaction hash to check
    /// @return True if filtered, false otherwise
    function isTransactionFiltered(
        bytes32 txHash
    ) external view returns (bool);
}
