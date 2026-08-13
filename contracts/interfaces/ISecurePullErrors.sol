// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Shared errors for delta-based secure token pulls (pretransfer / inventory credit).
/// @dev Packages must import this interface and revert with TransferDeltaInsufficient when
///      claimed > observed inbound. Observed may be same-tx `balanceAfter - balanceBefore`
///      or durable unbooked surplus `U = balanceOf - reserveOfToken`. Do not invent a second
///      algorithm. Surplus refunds (E6) pay only this-call unused inbound, never booked `R`.
interface ISecurePullErrors {
    /// @notice Claimed pull amount exceeds the observed inbound (same-tx delta or durable `U`).
    /// @param claimed Amount the caller requested to credit.
    /// @param observedDelta Observed inbound: same-tx `balanceAfter - balanceBefore`, or durable `U`.
    error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);
}
