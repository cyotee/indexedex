// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

/// @title ISeigniorageSetter
/// @notice Minimal interface exposing the seigniorage setter used by tests and packages
interface ISeigniorageSetter {
    /// @notice Set the global seigniorage amount
    /// @param _amount new seigniorage value (protocol-specific units)
    function setSeigniorage(uint256 _amount) external;

    // @dev selector constant for `setSeigniorage(uint256)` — available for inline use
    // bytes4(keccak256("setSeigniorage(uint256)")) == 0x00000000 (placeholder computed at compile-time via selector)
}
