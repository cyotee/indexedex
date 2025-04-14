// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";

abstract contract VaultRegistryVaultManagerTarget is MultiStepOwnableModifiers, IVaultRegistryVaultManager {
    function registerVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig)
        public
        onlyOwner
        returns (bool)
    {
        VaultRegistryVaultRepo._registerVault(vault, pkg, vaultConfig);
        return true;
    }

    function unregisterVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig)
        public
        onlyOwner
        returns (bool)
    {
        VaultRegistryVaultRepo._removeVault(vault, pkg, vaultConfig);
        return true;
    }
}
