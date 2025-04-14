// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {VaultRegistryVaultPackageRepo} from "contracts/registries/vault/VaultRegistryVaultPackageRepo.sol";

contract VaultRegistryVaultPackageManagerTarget is MultiStepOwnableModifiers, IVaultRegistryVaultPackageManager {
    function registerPackage(address pkg, IStandardVaultPkg.VaultPkgDeclaration memory dec)
        public
        onlyOwner
        returns (bool)
    {
        VaultRegistryVaultPackageRepo._registerPkg(pkg, dec);
        return true;
    }

    function unregisterPackage(address pkg) public onlyOwner returns (bool) {
        VaultRegistryVaultPackageRepo._removePkg(pkg);
        return true;
    }
}
