// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {Bytes4Set, Bytes4SetRepo} from "@crane/contracts/utils/collections/sets/Bytes4SetRepo.sol";
import {Bytes32Set, Bytes32SetRepo} from "@crane/contracts/utils/collections/sets/Bytes32SetRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {

    // BondTerms,
    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";

library VaultRegistryVaultPackageRepo {
    using BetterEfficientHashLib for bytes;

    using AddressSetRepo for address[];
    using AddressSetRepo for AddressSet;
    using Bytes4SetRepo for Bytes4Set;
    using Bytes32SetRepo for Bytes32Set;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.registry.vault.vaultpkg");

    struct Storage {
        // Set of all vault packages.
        AddressSet packages;
        // Set of all vault types.
        Bytes4Set vaultTypeIds;
        // mapping of all vault package names.
        mapping(address pkg => string name) pkgNames;
        // Mapping of package vault fee type IDs.
        mapping(address pkg => bytes32 vaultFeeTypeIds) pkgFeeTypeIds;
        // Mapping of all vault pages of a type.
        mapping(bytes4 typeId => AddressSet pkgs) pkgsOfType;
        // Set of a vault usage fee type IDs.
        Bytes4Set usageVaultTypeIds;
        // Set of all DEX term vault type IDs.
        Bytes4Set dexVaultTypeIds;
        // Set of all bond term vault type IDs.
        Bytes4Set bondVaultTypeIds;
        Bytes4Set seigniorageVaultTypeIds;
        // Set of all lending term vault type IDs.
        Bytes4Set lendingVaultTypeIds;
        // Bytes4Set tbdVaultTypeIds0;
        // Bytes4Set tbdVaultTypeIds1;
        // Bytes4Set tbdVaultTypeIds2;
        // Bytes4Set tbdVaultTypeIds3;
    }

    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(STORAGE_SLOT);
    }

    function _registerPkg(Storage storage layoutStruct, address pkg, IStandardVaultPkg.VaultPkgDeclaration memory dec)
        internal
    {
        // Storage.packages
        layoutStruct.packages._add(pkg);
        // Storage.pkgNames
        layoutStruct.pkgNames[pkg] = dec.name;
        // Storage.pkgFeeTypeIds
        layoutStruct.pkgFeeTypeIds[pkg] = dec.vaultFeeTypeIds;
        // Decode packed vault fee type IDs.
        VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(dec.vaultFeeTypeIds);
        // Storage.usageVaultTypeIds
        layoutStruct.usageVaultTypeIds._add(feeTypeIds_.usage);
        // Storage.dexVaultTypeIds
        layoutStruct.dexVaultTypeIds._add(feeTypeIds_.dex);
        // Storage.bondVaultTypeIds
        layoutStruct.bondVaultTypeIds._add(feeTypeIds_.bond);
        // Storage.lendingVaultTypeIds
        layoutStruct.lendingVaultTypeIds._add(feeTypeIds_.lending);
        layoutStruct.seigniorageVaultTypeIds._add(feeTypeIds_.seigniorage);
        // _vaultRegistry().tbdVaultTypeIds0._add(feeTypeIds_.tbd0);
        // _vaultRegistry().tbdVaultTypeIds1._add(feeTypeIds_.tbd1);
        // _vaultRegistry().tbdVaultTypeIds2._add(feeTypeIds_.tbd2);
        // _vaultRegistry().tbdVaultTypeIds3._add(feeTypeIds_.tbd3);
        // VaultRegistrylayoutStruct.typeIds
        emit IVaultRegistryEvents.NewPackage(pkg, dec.name, dec.vaultFeeTypeIds, dec.vaultTypes);
        for (uint256 typesCursor; typesCursor < dec.vaultTypes.length; typesCursor++) {
            // VaultRegistryLayout.typeIds
            layoutStruct.vaultTypeIds._add(dec.vaultTypes[typesCursor]);
            // VaultRegistryLayout.pkgsOfType
            layoutStruct.pkgsOfType[dec.vaultTypes[typesCursor]]._add(pkg);
            emit IVaultRegistryEvents.NewPackageOfType(pkg, dec.vaultTypes[typesCursor]);
        }
    }

    function _registerPkg(address pkg, IStandardVaultPkg.VaultPkgDeclaration memory dec) internal {
        _registerPkg(_layoutStruct(), pkg, dec);
    }

    function _removePkg(Storage storage layoutStruct, address pkg) internal {
        // Storage.packages
        layoutStruct.packages._remove(pkg);
        // Storage.pkgNames
        delete layoutStruct.pkgNames[pkg];
        // Storage.pkgFeeTypeIds
        delete layoutStruct.pkgFeeTypeIds[pkg];
        // Decode packed vault fee type IDs.
        // VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(dec.vaultFeeTypeIds);
        // Storage.usageVaultTypeIds
        // layoutStruct.usageVaultTypeIds._add(feeTypeIds_.usage);
        // // Storage.dexVaultTypeIds
        // layoutStruct.dexVaultTypeIds._add(feeTypeIds_.dex);
        // // Storage.bondVaultTypeIdse
        // layoutStruct.bondVaultTypeIds._add(feeTypeIds_.bond);
        // // Storage.lendingVaultTypeIds
        // layoutStruct.lendingVaultTypeIds._add(feeTypeIds_.lending);
        // layoutStruct.seigniorageVaultTypeIds._add(feeTypeIds_.seigniorage);
        // _vaultRegistry().tbdVaultTypeIds0._add(feeTypeIds_.tbd0);
        // _vaultRegistry().tbdVaultTypeIds1._add(feeTypeIds_.tbd1);
        // _vaultRegistry().tbdVaultTypeIds2._add(feeTypeIds_.tbd2);
        // _vaultRegistry().tbdVaultTypeIds3._add(feeTypeIds_.tbd3);
        // VaultRegistryLayout.typeIds
        // emit IVaultRegistryEvents.NewPackage(pkg, dec.name, dec.vaultFeeTypeIds, dec.vaultTypes);
        // for (uint256 typesCursor; typesCursor < dec.vaultTypes.length; typesCursor++) {
        //     // VaultRegistryLayout.typeIds
        //     layoutStruct.vaultTypeIds._add(dec.vaultTypes[typesCursor]);
        //     // VaultRegistryLayout.pkgsOfType
        //     layoutStruct.pkgsOfType[dec.vaultTypes[typesCursor]]._add(pkg);
        //     emit IVaultRegistryEvents.NewPackageOfType(pkg, dec.vaultTypes[typesCursor]);
        // }
    }

    function _removePkg(address pkg) internal {
        _removePkg(_layoutStruct(), pkg);
    }

    function _isPkg(Storage storage layoutStruct, address pkg) internal view returns (bool) {
        return layoutStruct.packages._contains(pkg);
    }

    function _isPkg(address pkg) internal view returns (bool) {
        return _isPkg(_layoutStruct(), pkg);
    }

    function _vaultPkgs(Storage storage layoutStruct) internal view returns (address[] memory pkgs_) {
        return layoutStruct.packages._values();
    }

    function _vaultPkgs() internal view returns (address[] memory pkgs_) {
        return _vaultPkgs(_layoutStruct());
    }

    function _vaultTypeIds(Storage storage layoutStruct) internal view returns (bytes4[] memory vaultTypeIds_) {
        return layoutStruct.vaultTypeIds._values();
    }

    function _vaultTypeIds() internal view returns (bytes4[] memory vaultTypeIds_) {
        return _vaultTypeIds(_layoutStruct());
    }

    function _vaultUsageFeeTypeIds(Storage storage layoutStruct) internal view returns (bytes4[] memory usageFeeTypeIds_) {
        return layoutStruct.usageVaultTypeIds._values();
    }

    function _vaultUsageFeeTypeIds() internal view returns (bytes4[] memory usageFeeTypeIds_) {
        return _vaultUsageFeeTypeIds(_layoutStruct());
    }

    function _vaultDexFeeTypeIds(Storage storage layoutStruct) internal view returns (bytes4[] memory dexFeeTypeIds_) {
        return layoutStruct.dexVaultTypeIds._values();
    }

    function _vaultDexFeeTypeIds() internal view returns (bytes4[] memory dexFeeTypeIds_) {
        return _vaultDexFeeTypeIds(_layoutStruct());
    }

    function _vaultBondFeeTypeIds(Storage storage layoutStruct) internal view returns (bytes4[] memory bondFeeTypeIds_) {
        return layoutStruct.bondVaultTypeIds._values();
    }

    function _vaultBondFeeTypeIds() internal view returns (bytes4[] memory bondFeeTypeIds_) {
        return _vaultBondFeeTypeIds(_layoutStruct());
    }

    function _vaultSeigniorageTypeIds(Storage storage layoutStruct)
        internal
        view
        returns (bytes4[] memory seigniorageTypeIds_)
    {
        return layoutStruct.seigniorageVaultTypeIds._values();
    }

    function _vaultSeigniorageTypeIds() internal view returns (bytes4[] memory seigniorageTypeIds_) {
        return _vaultSeigniorageTypeIds(_layoutStruct());
    }

    function _vaultLendingFeeTypeIds(Storage storage layoutStruct)
        internal
        view
        returns (bytes4[] memory lendingFeeTypeIds_)
    {
        return layoutStruct.lendingVaultTypeIds._values();
    }

    function _vaultLendingFeeTypeIds() internal view returns (bytes4[] memory lendingFeeTypeIds_) {
        return _vaultLendingFeeTypeIds(_layoutStruct());
    }

    function _pkgName(Storage storage layoutStruct, address pkg) internal view returns (string memory name_) {
        return layoutStruct.pkgNames[pkg];
    }

    function _pkgName(address pkg) internal view returns (string memory name_) {
        return _pkgName(_layoutStruct(), pkg);
    }

    function _packageFeeTypeIds(Storage storage layoutStruct, address pkg) internal view returns (bytes32 feeTypeIds_) {
        return layoutStruct.pkgFeeTypeIds[pkg];
    }

    function _packageFeeTypeIds(address pkg) internal view returns (bytes32 feeTypeIds_) {
        return _packageFeeTypeIds(_layoutStruct(), pkg);
    }

    function _packagesOfTypeId(Storage storage layoutStruct, bytes4 typeId) internal view returns (address[] memory pkgs_) {
        return layoutStruct.pkgsOfType[typeId]._values();
    }

    function _packagesOfTypeId(bytes4 typeId) internal view returns (address[] memory pkgs_) {
        return _packagesOfTypeId(_layoutStruct(), typeId);
    }
}
