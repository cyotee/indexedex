// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IVaultRegistryDisableQuery
 * @notice Read-side kill-switch for vaults and DETFs.
 * @notice Effective disable is OR of vault-address set and the vault's package set.
 * @notice Vaults should call only `isDisabled(address(this))`.
 * @dev Single-call resolution (fee-oracle style). No vault-type-ID axis.
 */
interface IVaultRegistryDisableQuery {
    /// @notice Thrown when a vault/DETF is effectively disabled and a mutation is attempted.
    error VaultDisabled(address vault);

    /// @notice Thrown when deploying a vault from a disabled package.
    error DisabledPackage(address pkg);

    /**
     * @notice Whether `vault` is effectively disabled.
     * @dev True if vault ∈ disabledVaults
     *      OR packageOfVault(vault) ∈ disabledPackages (when pkg != address(0)).
     */
    function isDisabled(address vault) external view returns (bool disabled);

    /**
     * @notice Effective disable plus which axes contributed (UI / operators).
     */
    function isDisabledDetailed(address vault)
        external
        view
        returns (bool disabled, bool byVault, bool byPackage);

    /// @notice `disabledVaults` membership only.
    function isVaultAddressDisabled(address vault) external view returns (bool);

    /// @notice `disabledPackages` membership only.
    function isPackageDisabled(address pkg) external view returns (bool);

    /// @notice Package recorded at registration (`address(0)` if unregistered / unknown).
    function packageOfVault(address vault) external view returns (address pkg);

    /// @notice Enumerate disable sets (off-chain / admin; not for hot vault paths).
    function disabledVaults() external view returns (address[] memory);

    function disabledPackages() external view returns (address[] memory);
}
