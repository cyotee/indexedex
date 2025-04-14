// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Permit2ErrorSelectors
/// @notice Helper library exposing bytes4 selectors for common Permit2 revert/error
/// signatures so tests can assert exact revert selectors without duplicating raw
/// values.
library Permit2ErrorSelectors {
    // Common Permit2 / transfer related error selectors (canonical signatures)
    bytes4 internal constant Permit2_NotApproved = bytes4(keccak256("NotApproved(address)"));
    bytes4 internal constant Permit2_TransferFailed = bytes4(keccak256("TransferFailed()"));
    bytes4 internal constant Permit2_Permit2Failed = bytes4(keccak256("Permit2Failed()"));
    bytes4 internal constant Permit2_Permit2ApproveFailed = bytes4(keccak256("Permit2ApproveFailed()"));
    bytes4 internal constant Permit2_Permit2AmountOverflow = bytes4(keccak256("Permit2AmountOverflow()"));
}
