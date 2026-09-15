// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Same-transaction preparation for explicitly funded push inputs.
interface IStandardExchangePretransfer {
    error InvalidPretransfer();
    error PretransferPending();
    error PretransferNotPrepared();
    error PretransferCallMismatch();
    error PretransferAmountMismatch(address token, uint256 expected, uint256 actual);
    error PretransferNotConsumed();

    /// @notice Snapshot local custody before sending tokens, then execute the committed call.
    /// @dev The same caller must prepare, transfer and call in one transaction. Maximum two
    /// distinct pool tokens or the vault share. callHash is keccak256 of the complete exchange
    /// calldata (including recipient, limits, pretransferred flag and deadline).
    function preparePretransfer(address[] calldata tokens, uint256[] calldata amounts, bytes32 callHash) external;
}
