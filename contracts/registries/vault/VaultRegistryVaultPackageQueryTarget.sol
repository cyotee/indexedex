// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {VaultRegistryVaultPackageRepo} from "contracts/registries/vault/VaultRegistryVaultPackageRepo.sol";

// abstract
contract VaultRegistryVaultPackageQueryTarget is IVaultRegistryVaultPackageQuery {
    /* ------------------- IVaultRegistryVaultPackageQuery ------------------ */

    function vaultPackages() external view returns (address[] memory pkgs_) {
        return VaultRegistryVaultPackageRepo._vaultPkgs();
    }

    function isPackage(address pkg) external view returns (bool isPackage_) {
        return VaultRegistryVaultPackageRepo._isPkg(pkg);
    }

    function vaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultTypeIds();
    }

    function vaultUsageFeeTypeIds() external view returns (bytes4[] memory vaultUsageFeeTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultUsageFeeTypeIds();
    }

    function vaultDexFeeTypeIds() external view returns (bytes4[] memory vaultDexFeeTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultDexFeeTypeIds();
    }

    function vaultBondFeeTypeIds() external view returns (bytes4[] memory vaultBondFeeTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultBondFeeTypeIds();
    }

    function vaultLendingFeeTypeIds() external view returns (bytes4[] memory vaultLendingFeeTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultLendingFeeTypeIds();
    }

    function packageName(address pkg) external view returns (string memory pkgName_) {
        return VaultRegistryVaultPackageRepo._pkgName(pkg);
    }

    function packageFeeTypeIds(address pkg) external view returns (bytes32 feeTypeIds_) {
        return VaultRegistryVaultPackageRepo._packageFeeTypeIds(pkg);
    }

    function packagesOfTypeId(bytes4 typeId) external view returns (address[] memory pkgs_) {
        return VaultRegistryVaultPackageRepo._packagesOfTypeId(typeId);
    }
}
