// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {VaultRegistryDisableRepo} from "contracts/registries/vault/VaultRegistryDisableRepo.sol";
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";

abstract contract VaultRegistryDisableQueryTarget is IVaultRegistryDisableQuery {
    function isDisabled(address vault) public view returns (bool disabled) {
        return VaultRegistryDisableRepo._isDisabled(vault);
    }

    function isDisabledDetailed(address vault)
        public
        view
        returns (bool disabled, bool byVault, bool byPackage)
    {
        return VaultRegistryDisableRepo._isDisabledDetailed(vault);
    }

    function isVaultAddressDisabled(address vault) public view returns (bool) {
        return VaultRegistryDisableRepo._isVaultAddressDisabled(vault);
    }

    function isPackageDisabled(address pkg) public view returns (bool) {
        return VaultRegistryDisableRepo._isPackageDisabled(pkg);
    }

    function packageOfVault(address vault) public view returns (address pkg) {
        return VaultRegistryVaultRepo._packageOfVault(vault);
    }

    function disabledVaults() public view returns (address[] memory) {
        return VaultRegistryDisableRepo._disabledVaults();
    }

    function disabledPackages() public view returns (address[] memory) {
        return VaultRegistryDisableRepo._disabledPackages();
    }
}
