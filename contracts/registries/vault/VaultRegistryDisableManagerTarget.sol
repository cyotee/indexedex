// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {VaultRegistryDisableRepo} from "contracts/registries/vault/VaultRegistryDisableRepo.sol";

abstract contract VaultRegistryDisableManagerTarget is MultiStepOwnableModifiers, IVaultRegistryDisableManager {
    function setVaultAddressDisabled(address vault, bool disabled) public onlyOwner returns (bool success) {
        bool changed = VaultRegistryDisableRepo._setVaultAddressDisabled(vault, disabled);
        if (changed) {
            emit VaultAddressDisabled(vault, disabled);
        }
        return true;
    }

    function setPackageDisabled(address pkg, bool disabled) public onlyOwner returns (bool success) {
        bool changed = VaultRegistryDisableRepo._setPackageDisabled(pkg, disabled);
        if (changed) {
            emit PackageDisabled(pkg, disabled);
        }
        return true;
    }
}
