// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";

library VaultRegistryDisableRepo {
    using AddressSetRepo for AddressSet;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.registry.vault.disable");

    struct Storage {
        AddressSet disabledVaults;
        AddressSet disabledPackages;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    /* ----------------------------- Vault address ---------------------------- */

    function _isVaultAddressDisabled(Storage storage layoutStruct, address vault_) internal view returns (bool) {
        return layoutStruct.disabledVaults._contains(vault_);
    }

    function _isVaultAddressDisabled(address vault_) internal view returns (bool) {
        return _isVaultAddressDisabled(_layoutStruct(), vault_);
    }

    function _setVaultAddressDisabled(Storage storage layoutStruct, address vault_, bool disabled_)
        internal
        returns (bool changed)
    {
        bool currently = layoutStruct.disabledVaults._contains(vault_);
        if (disabled_ == currently) {
            return false;
        }
        if (disabled_) {
            layoutStruct.disabledVaults._add(vault_);
        } else {
            layoutStruct.disabledVaults._remove(vault_);
        }
        return true;
    }

    function _setVaultAddressDisabled(address vault_, bool disabled_) internal returns (bool changed) {
        return _setVaultAddressDisabled(_layoutStruct(), vault_, disabled_);
    }

    function _disabledVaults(Storage storage layoutStruct) internal view returns (address[] memory) {
        return layoutStruct.disabledVaults._values();
    }

    function _disabledVaults() internal view returns (address[] memory) {
        return _disabledVaults(_layoutStruct());
    }

    /* ------------------------------- Package -------------------------------- */

    function _isPackageDisabled(Storage storage layoutStruct, address pkg_) internal view returns (bool) {
        return layoutStruct.disabledPackages._contains(pkg_);
    }

    function _isPackageDisabled(address pkg_) internal view returns (bool) {
        return _isPackageDisabled(_layoutStruct(), pkg_);
    }

    function _setPackageDisabled(Storage storage layoutStruct, address pkg_, bool disabled_)
        internal
        returns (bool changed)
    {
        bool currently = layoutStruct.disabledPackages._contains(pkg_);
        if (disabled_ == currently) {
            return false;
        }
        if (disabled_) {
            layoutStruct.disabledPackages._add(pkg_);
        } else {
            layoutStruct.disabledPackages._remove(pkg_);
        }
        return true;
    }

    function _setPackageDisabled(address pkg_, bool disabled_) internal returns (bool changed) {
        return _setPackageDisabled(_layoutStruct(), pkg_, disabled_);
    }

    function _disabledPackages(Storage storage layoutStruct) internal view returns (address[] memory) {
        return layoutStruct.disabledPackages._values();
    }

    function _disabledPackages() internal view returns (address[] memory) {
        return _disabledPackages(_layoutStruct());
    }

    /* ------------------------------ Resolution ------------------------------ */

    function _isDisabled(Storage storage layoutStruct, address vault_) internal view returns (bool) {
        if (layoutStruct.disabledVaults._contains(vault_)) {
            return true;
        }
        address pkg = VaultRegistryVaultRepo._packageOfVault(vault_);
        if (pkg != address(0) && layoutStruct.disabledPackages._contains(pkg)) {
            return true;
        }
        return false;
    }

    function _isDisabled(address vault_) internal view returns (bool) {
        return _isDisabled(_layoutStruct(), vault_);
    }

    function _isDisabledDetailed(Storage storage layoutStruct, address vault_)
        internal
        view
        returns (bool disabled, bool byVault, bool byPackage)
    {
        byVault = layoutStruct.disabledVaults._contains(vault_);
        address pkg = VaultRegistryVaultRepo._packageOfVault(vault_);
        byPackage = pkg != address(0) && layoutStruct.disabledPackages._contains(pkg);
        disabled = byVault || byPackage;
    }

    function _isDisabledDetailed(address vault_)
        internal
        view
        returns (bool disabled, bool byVault, bool byPackage)
    {
        return _isDisabledDetailed(_layoutStruct(), vault_);
    }
}
