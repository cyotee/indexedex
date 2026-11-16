// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IVaultRegistryDisableManager
 * @notice Owner-controlled kill-switch writers.
 * @notice Access: onlyOwner (not operator).
 * @notice Axes: vault address and package only — no vault type IDs.
 */
interface IVaultRegistryDisableManager {
    event VaultAddressDisabled(address indexed vault, bool disabled);
    event PackageDisabled(address indexed package, bool disabled);

    /**
     * @notice Disable or re-enable a single vault instance.
     * @param disabled True → add to disabledVaults; false → remove (active by absence).
     *        Package disable may still keep the vault effectively disabled.
     */
    function setVaultAddressDisabled(address vault, bool disabled) external returns (bool success);

    /**
     * @notice Disable or re-enable all vaults registered under package `pkg`
     *         (via pkgOfVault → disabledPackages membership at query time).
     */
    function setPackageDisabled(address pkg, bool disabled) external returns (bool success);
}
