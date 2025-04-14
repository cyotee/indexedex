// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IBaseProtocolDETFRichirRedeem
 * @notice Interface for restricted RICHIR→RICH redemption route management.
 * @dev Functions to add/remove addresses from the allowed list for local RICHIR redemption.
 */
interface IBaseProtocolDETFRichirRedeem {
    /// @notice Add an address to the allowed list for RICHIR→RICH redemption
    /// @param addr Address to add
    function addAllowedRichirRedeemAddress(address addr) external;

    /// @notice Remove an address from the allowed list for RICHIR→RICH redemption
    /// @param addr Address to remove
    function removeAllowedRichirRedeemAddress(address addr) external;

    /// @notice Check if an address is allowed to use the RICHIR→RICH route
    /// @param addr Address to check
    /// @return bool True if allowed
    function isAllowedRichirRedeemAddress(address addr) external view returns (bool);
}
