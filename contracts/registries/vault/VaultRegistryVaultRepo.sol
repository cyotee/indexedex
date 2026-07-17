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
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {

    // BondTerms,
    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";

library VaultRegistryVaultRepo {
    using BetterEfficientHashLib for bytes;

    using AddressSetRepo for address[];
    using AddressSetRepo for AddressSet;
    using Bytes4SetRepo for Bytes4Set;
    using Bytes32SetRepo for Bytes32Set;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.registry.vault.vault");

    struct Storage {
        // Set of all vault packages.
        // AddressSet packages;
        // Set of all vault types.
        // Bytes4Set typeIds;
        // mapping of all vault package names.
        // mapping(address pkg => string name) pkgNames;
        // mapping(address pkg => bytes32 vaultFeeTypeIds) pkgFeeTypeIds;
        // Mapping of all vault pages of a type.
        // mapping(bytes4 typeId => AddressSet pkgs) pkgsOfType;
        AddressSet vaults;
        Bytes32Set contentsIds;
        AddressSet vaultTokens;
        mapping(address vault => bytes32 vaultFeeTypeIds) feeTypeIdsOfVault;
        mapping(address pkg => AddressSet vaults) vaultsOfPkg;
        mapping(address token => AddressSet vaults) vaultsOfToken;
        mapping(bytes32 contentsId => AddressSet vaults) vaultsOfContentsId;
        mapping(bytes4 typeID => AddressSet vaults) vaultsOfType;
        /// forge-lint: disable-next-line(mixed-case-variable)
        mapping(bytes4 typeId => mapping(address token => AddressSet vaults)) vaultsOfTokenOfTypeId;
        /// forge-lint: disable-next-line(mixed-case-variable)
        mapping(bytes4 typeId => mapping(bytes32 contentsId => AddressSet vaults)) vaultsOfContentsIdOfTypeId;
        mapping(address pkg => mapping(address token => AddressSet vaults)) vaultsOfTokenOfPkg;
        /// forge-lint: disable-next-line(mixed-case-variable)
        mapping(address pkg => mapping(bytes32 contentsId => AddressSet vaults)) vaultsOfContentsIdOfPkg;
        // Placed at the bottom of the storage range so we can add new vault types.
        // Bytes4Set usageVaultTypeIds;
        mapping(address vault => bytes4 usageFeeId) usageFeeIdOfVault;
        // Bytes4Set dexVaultTypeIds;
        mapping(address vault => bytes4 dexFeeId) dexFeeIdOfVault;
        // Bytes4Set bondVaultTypeIds;
        mapping(address vault => bytes4 bondFeeId) bondFeeIdOfVault;
        mapping(address vault => bytes4 seigniorageId) seigniorageIdOfVault;
        // Bytes4Set lendingVaultTypeIds;
        mapping(address vault => bytes4 lendingFeeId) lendingFeeIdOfVault;
        // Reverse map: vault → package used at registration (for kill-switch O(1) package tier).
        mapping(address vault => address pkg) pkgOfVault;
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

    function _registerVault(
        Storage storage layoutStruct,
        address vault,
        address pkg,
        IStandardVault.VaultConfig memory vaultConfig
    ) internal {
        // _registerVault(vault, pkg, vaultConfig.vaultTypes, vaultConfig.tokens);
        // VaultRegistryLayout.vaults
        layoutStruct.vaults._add(vault);
        // tokens = tokens._sort();
        // bytes32 contentsID = keccak256(abi.encode(tokens));
        /// forge-lint: disable-next-line(mixed-case-variable)
        // bytes32 contentsID = abi.encode(tokens).hash();
        // VaultRegistryLayout.contentsIds
        layoutStruct.contentsIds._add(vaultConfig.contentsId);
        // Reverse package lookup for kill-switch
        layoutStruct.pkgOfVault[vault] = pkg;
        // VaultRegistryLayout.vaultsOfPkg
        layoutStruct.vaultsOfPkg[pkg]._add(vault);
        // VaultRegistryLayout.vaultsOfContentsId
        layoutStruct.vaultsOfContentsId[vaultConfig.contentsId]._add(vault);
        // VaultRegistryLayout.vaultsOfContentsIdOfPkg
        layoutStruct.vaultsOfContentsIdOfPkg[pkg][vaultConfig.contentsId]._add(vault);
        layoutStruct.feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds;
        VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(vaultConfig.vaultFeeTypeIds);
        layoutStruct.usageFeeIdOfVault[vault] = feeTypeIds_.usage;
        layoutStruct.dexFeeIdOfVault[vault] = feeTypeIds_.dex;
        layoutStruct.bondFeeIdOfVault[vault] = feeTypeIds_.bond;
        layoutStruct.seigniorageIdOfVault[vault] = feeTypeIds_.seigniorage;
        layoutStruct.lendingFeeIdOfVault[vault] = feeTypeIds_.lending;
        // layoutStruct.tbdFeeIdOfVault0[vault] = feeTypeIds_.tbd0;
        // layoutStruct.tbdFeeIdOfVault1[vault] = feeTypeIds_.tbd1;
        // layoutStruct.tbdFeeIdOfVault2[vault] = feeTypeIds_.tbd2;
        // layoutStruct.tbdFeeIdOfVault3[vault] = feeTypeIds_.tbd3;
        emit IVaultRegistryEvents.NewVault(
            vault, pkg, vaultConfig.vaultFeeTypeIds, vaultConfig.contentsId, vaultConfig.vaultTypes, vaultConfig.tokens
        );
        for (uint256 typesCursor; typesCursor < vaultConfig.vaultTypes.length; typesCursor++) {
            // VaultRegistryLayout.vaultsOfType
            layoutStruct.vaultsOfType[vaultConfig.vaultTypes[typesCursor]]._add(vault);
            // VaultRegistryLayout.vaultsOfContentsIdOfTypeId
            layoutStruct.vaultsOfContentsIdOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.contentsId]._add(vault);
            emit IVaultRegistryEvents.NewVaultOfType(vault, pkg, vaultConfig.vaultTypes[typesCursor]);
            for (uint256 tokensCursor; tokensCursor < vaultConfig.tokens.length; tokensCursor++) {
                // VaultRegistryLayout.tokens
                layoutStruct.vaultTokens._add(vaultConfig.tokens[tokensCursor]);
                // VaultRegistryLayout.vaultsOfToken
                layoutStruct.vaultsOfToken[vaultConfig.tokens[tokensCursor]]._add(vault);
                // VaultRegistryLayout.vaultsOfTokenOfTypeId
                layoutStruct.vaultsOfTokenOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.tokens[tokensCursor]]._add(
                    vault
                );
                // VaultRegistryLayout.vaultsOfTokenOfPkg
                layoutStruct.vaultsOfTokenOfPkg[pkg][vaultConfig.tokens[tokensCursor]]._add(vault);
                emit IVaultRegistryEvents.NewVaultOfToken(vault, pkg, vaultConfig.tokens[tokensCursor]);
            }
        }
    }

    function _registerVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig) internal {
        _registerVault(_layoutStruct(), vault, pkg, vaultConfig);
    }

    function _removeVault(
        Storage storage layoutStruct,
        address vault,
        address pkg,
        IStandardVault.VaultConfig memory vaultConfig
    ) internal {
        // _registerVault(vault, pkg, vaultConfig.vaultTypes, vaultConfig.tokens);
        // VaultRegistryLayout.vaults
        layoutStruct.vaults._remove(vault);
        // tokens = tokens._sort();
        // bytes32 contentsID = keccak256(abi.encode(tokens));
        /// forge-lint: disable-next-line(mixed-case-variable)
        // bytes32 contentsID = abi.encode(tokens).hash();
        // VaultRegistryLayout.contentsIds
        // layoutStruct.contentsIds._add(vaultConfig.contentsId);
        delete layoutStruct.pkgOfVault[vault];
        // VaultRegistryLayout.vaultsOfPkg
        layoutStruct.vaultsOfPkg[pkg]._remove(vault);
        // VaultRegistryLayout.vaultsOfContentsId
        layoutStruct.vaultsOfContentsId[vaultConfig.contentsId]._remove(vault);
        // VaultRegistryLayout.vaultsOfContentsIdOfPkg
        layoutStruct.vaultsOfContentsIdOfPkg[pkg][vaultConfig.contentsId]._remove(vault);
        layoutStruct.feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds;
        // VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(vaultConfig.vaultFeeTypeIds);
        delete layoutStruct.usageFeeIdOfVault[vault];
        delete layoutStruct.dexFeeIdOfVault[vault];
        delete layoutStruct.bondFeeIdOfVault[vault];
        delete layoutStruct.seigniorageIdOfVault[vault];
        delete layoutStruct.lendingFeeIdOfVault[vault];
        // layoutStruct.tbdFeeIdOfVault0[vault] = feeTypeIds_.tbd0;
        // layoutStruct.tbdFeeIdOfVault1[vault] = feeTypeIds_.tbd1;
        // layoutStruct.tbdFeeIdOfVault2[vault] = feeTypeIds_.tbd2;
        // layoutStruct.tbdFeeIdOfVault3[vault] = feeTypeIds_.tbd3;
        // emit IVaultRegistryEvents.NewVault(
        //     vault, pkg, vaultConfig.vaultFeeTypeIds, vaultConfig.contentsId, vaultConfig.vaultTypes, vaultConfig.tokens
        // );
        for (uint256 typesCursor; typesCursor < vaultConfig.vaultTypes.length; typesCursor++) {
            // VaultRegistryLayout.vaultsOfType
            layoutStruct.vaultsOfType[vaultConfig.vaultTypes[typesCursor]]._remove(vault);
            // VaultRegistryLayout.vaultsOfContentsIdOfTypeId
            layoutStruct.vaultsOfContentsIdOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.contentsId]._remove(
                vault
            );
            // emit IVaultRegistryEvents.NewVaultOfType(vault, pkg, vaultConfig.vaultTypes[typesCursor]);
            for (uint256 tokensCursor; tokensCursor < vaultConfig.tokens.length; tokensCursor++) {
                // VaultRegistryLayout.tokens
                // layoutStruct.vaultTokens._add(vaultConfig.tokens[tokensCursor]);
                // VaultRegistryLayout.vaultsOfToken
                layoutStruct.vaultsOfToken[vaultConfig.tokens[tokensCursor]]._remove(vault);
                // VaultRegistryLayout.vaultsOfTokenOfTypeId
                layoutStruct.vaultsOfTokenOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.tokens[tokensCursor]]._remove(
                    vault
                );
                // VaultRegistryLayout.vaultsOfTokenOfPkg
                layoutStruct.vaultsOfTokenOfPkg[pkg][vaultConfig.tokens[tokensCursor]]._remove(vault);
                // emit IVaultRegistryEvents.NewVaultOfToken(vault, pkg, vaultConfig.tokens[tokensCursor]);
            }
        }
    }

    function _removeVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig) internal {
        _removeVault(_layoutStruct(), vault, pkg, vaultConfig);
    }

    function _isVault(Storage storage layoutStruct, address vault) internal view returns (bool) {
        return layoutStruct.vaults._contains(vault);
    }

    function _isVault(address vault) internal view returns (bool) {
        return _isVault(_layoutStruct(), vault);
    }

    function _vaults(Storage storage layoutStruct) internal view returns (address[] memory vaults_) {
        return layoutStruct.vaults._values();
    }

    function _vaults() internal view returns (address[] memory vaults_) {
        return _vaults(_layoutStruct());
    }

    function _contentsIds(Storage storage layoutStruct) internal view returns (bytes32[] memory contentsIds_) {
        return layoutStruct.contentsIds._values();
    }

    function _contentsIds() internal view returns (bytes32[] memory contentsIds_) {
        return _contentsIds(_layoutStruct());
    }

    function _vaultTokens(Storage storage layoutStruct) internal view returns (address[] memory vaultTokens_) {
        return layoutStruct.vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory vaultTokens_) {
        return _vaultTokens(_layoutStruct());
    }

    function _isContainedToken(Storage storage layoutStruct, address token) internal view returns (bool) {
        return layoutStruct.vaultTokens._contains(token);
    }

    function _isContainedToken(address token) internal view returns (bool) {
        return _isContainedToken(_layoutStruct(), token);
    }

    function _vaultFeeTypeIds(Storage storage layoutStruct, address vault) internal view returns (bytes32 feeTypeIds_) {
        return layoutStruct.feeTypeIdsOfVault[vault];
    }

    function _vaultFeeTypeIds(address vault) internal view returns (bytes32 feeTypeIds_) {
        return _vaultFeeTypeIds(_layoutStruct(), vault);
    }

    function _vaultsOfPkg(Storage storage layoutStruct, address pkg) internal view returns (address[] memory vaults_) {
        return layoutStruct.vaultsOfPkg[pkg]._values();
    }

    function _vaultsOfPkg(address pkg) internal view returns (address[] memory vaults_) {
        return _vaultsOfPkg(_layoutStruct(), pkg);
    }

    function _vaultsOfToken(Storage storage layoutStruct, address token) internal view returns (address[] memory vaults_) {
        return layoutStruct.vaultsOfToken[token]._values();
    }

    function _vaultsOfToken(address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfToken(_layoutStruct(), token);
    }

    function _vaultsOfContentsId(Storage storage layoutStruct, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layoutStruct.vaultsOfContentsId[contentsId]._values();
    }

    function _vaultsOfContentsId(bytes32 contentsId) internal view returns (address[] memory vaults_) {
        return _vaultsOfContentsId(_layoutStruct(), contentsId);
    }

    function _vaultsOfType(Storage storage layoutStruct, bytes4 typeId) internal view returns (address[] memory vaults_) {
        return layoutStruct.vaultsOfType[typeId]._values();
    }

    function _vaultsOfType(bytes4 typeId) internal view returns (address[] memory vaults_) {
        return _vaultsOfType(_layoutStruct(), typeId);
    }

    function _vaultsOfTokenOfTypeId(Storage storage layoutStruct, bytes4 typeId, address token)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layoutStruct.vaultsOfTokenOfTypeId[typeId][token]._values();
    }

    function _vaultsOfTokenOfTypeId(bytes4 typeId, address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfTokenOfTypeId(_layoutStruct(), typeId, token);
    }

    function _vaultsOfContentsIdOfTypeId(Storage storage layoutStruct, bytes4 typeId, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layoutStruct.vaultsOfContentsIdOfTypeId[typeId][contentsId]._values();
    }

    function _vaultsOfContentsIdOfTypeId(bytes4 typeId, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return _vaultsOfContentsIdOfTypeId(_layoutStruct(), typeId, contentsId);
    }

    function _vaultsOfTokenOfPkg(Storage storage layoutStruct, address pkg, address token)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layoutStruct.vaultsOfTokenOfPkg[pkg][token]._values();
    }

    function _vaultsOfTokenOfPkg(address pkg, address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfTokenOfPkg(_layoutStruct(), pkg, token);
    }

    function _vaultsOfContentsIdOfPkg(Storage storage layoutStruct, address pkg, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layoutStruct.vaultsOfContentsIdOfPkg[pkg][contentsId]._values();
    }

    function _vaultsOfContentsIdOfPkg(address pkg, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return _vaultsOfContentsIdOfPkg(_layoutStruct(), pkg, contentsId);
    }

    function _usageFeeIdOfVault(Storage storage layoutStruct, address vault) internal view returns (bytes4 usageFeeId_) {
        return layoutStruct.usageFeeIdOfVault[vault];
    }

    function _usageFeeIdOfVault(address vault) internal view returns (bytes4 usageFeeId_) {
        return _usageFeeIdOfVault(_layoutStruct(), vault);
    }

    function _dexFeeIdOfVault(Storage storage layoutStruct, address vault) internal view returns (bytes4 dexFeeId_) {
        return layoutStruct.dexFeeIdOfVault[vault];
    }

    function _dexFeeIdOfVault(address vault) internal view returns (bytes4 dexFeeId_) {
        return _dexFeeIdOfVault(_layoutStruct(), vault);
    }

    function _bondFeeIdOfVault(Storage storage layoutStruct, address vault) internal view returns (bytes4 bondFeeId_) {
        return layoutStruct.bondFeeIdOfVault[vault];
    }

    function _bondFeeIdOfVault(address vault) internal view returns (bytes4 bondFeeId_) {
        return _bondFeeIdOfVault(_layoutStruct(), vault);
    }

    function _seigniorageIncentiveIdOfVault(Storage storage layoutStruct, address vault)
        internal
        view
        returns (bytes4 seigniorageId_)
    {
        return layoutStruct.seigniorageIdOfVault[vault];
    }

    function _seigniorageIncentiveIdOfVault(address vault) internal view returns (bytes4 seigniorageId_) {
        return _seigniorageIncentiveIdOfVault(_layoutStruct(), vault);
    }

    function _lendingFeeIdOfVault(Storage storage layoutStruct, address vault) internal view returns (bytes4 lendingFeeId_) {
        return layoutStruct.lendingFeeIdOfVault[vault];
    }

    function _lendingFeeIdOfVault(address vault) internal view returns (bytes4 lendingFeeId_) {
        return _lendingFeeIdOfVault(_layoutStruct(), vault);
    }

    function _packageOfVault(Storage storage layoutStruct, address vault) internal view returns (address pkg_) {
        return layoutStruct.pkgOfVault[vault];
    }

    function _packageOfVault(address vault) internal view returns (address pkg_) {
        return _packageOfVault(_layoutStruct(), vault);
    }
}
