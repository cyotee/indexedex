// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Shared errors for delta-based secure token pulls (pretransfer / inventory credit).
/// @dev Packages must import this interface and revert with TransferDeltaInsufficient when
///      claimed > observed balance delta over the pull window. Do not invent a second algorithm.
interface ISecurePullErrors {
    /// @notice Claimed pull amount exceeds the observed balance increase in this call.
    /// @param claimed Amount the caller requested to credit.
    /// @param observedDelta `balanceAfter - balanceBefore` over the pull window.
    error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);
}
