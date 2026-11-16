// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// tag::IStandardExchangeUnlockContextQuote[]
/// @notice Optional read-only context projection for an opaque transition snapshot.
/// @dev Separate from IStandardExchangeTransitionQuote: consumers discover support
/// independently. This changes quote context only, never live manager state or routes.
interface IStandardExchangeUnlockContextQuote {
    /// @notice Model a manager whose unlock will be unavailable during the operation.
    /// @param state A valid snapshot accepted by this exchange's transition decoder.
    /// @param manager The manager that the outer workflow will have in-session.
    /// @return projectedState The validated snapshot, with unlock unavailable only
    /// if manager matches the exchange's configured manager. A mismatch returns the
    /// original bytes; an already-blocked snapshot is never changed back to idle.
    function quoteStateWithUnavailableUnlock(bytes calldata state, address manager)
        external view returns (bytes memory projectedState);
}
// end::IStandardExchangeUnlockContextQuote[]
