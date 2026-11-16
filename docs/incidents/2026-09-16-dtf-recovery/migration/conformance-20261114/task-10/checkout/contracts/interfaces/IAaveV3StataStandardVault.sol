// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IAaveV3StataStandardVault
 * @notice Marker interface for Aave v3 Stata Token Standard Exchange Vaults.
 * @dev The interface ID of this interface is used as a vault fee type ID
 *      to allow per-type configuration of usage fees (e.g. set to 0 in production
 *      for Stata wrapper vaults).
 * @custom:interfaceid 0x... (to be computed)
 */
interface IAaveV3StataStandardVault {
    /**
     * @notice Returns the address of the underlying StataToken (ERC4626 wrapper
     *         over the Aave aToken) that backs this vault.
     * @return The StataToken address.
     */
    function stataToken() external view returns (address);
}
