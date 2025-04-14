// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";

/**
 * @title IVaultRegistryQuery - Interface for querying deployed vaults and pools.
 * @author cyotee doge <doge.cyotee>
 * @notice This registry considers liquidity pools to be a type of vault.
 * @custom:interfaceid 0xc6a03847
 */
interface IVaultRegistryVaultPackageQuery is IVaultRegistryEvents {
    /**
     * @notice Returns ALL registered packages.
     * @notice Packages are the addresses of the packages that deploy the vaults.
     * @return pkgs_ - An array of all registered packages.
     * @custom:selector 0xd0742235
     */
    function vaultPackages() external view returns (address[] memory pkgs_);

    function isPackage(address pkg) external view returns (bool isPackage_);

    function vaultTypeIds() external view returns (bytes4[] memory vaultTypeIds);

    function vaultUsageFeeTypeIds() external view returns (bytes4[] memory vaultUsageFeeTypeIds_);

    function vaultDexFeeTypeIds() external view returns (bytes4[] memory vaultDexFeeTypeIds);

    function vaultBondFeeTypeIds() external view returns (bytes4[] memory vaultBondFeeTypeIds);

    function vaultLendingFeeTypeIds() external view returns (bytes4[] memory vaultLendingFeeTypeIds_);

    function packageName(address pkg) external view returns (string memory pkgName_);

    function packageFeeTypeIds(address pkg) external view returns (bytes32 feeTypeIds_);

    function packagesOfTypeId(bytes4 typeId) external view returns (address[] memory pkgs_);
}
