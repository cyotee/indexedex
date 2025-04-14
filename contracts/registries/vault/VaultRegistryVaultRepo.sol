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
        // Bytes4Set tbdVaultTypeIds0;
        // Bytes4Set tbdVaultTypeIds1;
        // Bytes4Set tbdVaultTypeIds2;
        // Bytes4Set tbdVaultTypeIds3;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _registerVault(
        Storage storage layout,
        address vault,
        address pkg,
        IStandardVault.VaultConfig memory vaultConfig
    ) internal {
        // _registerVault(vault, pkg, vaultConfig.vaultTypes, vaultConfig.tokens);
        // VaultRegistryLayout.vaults
        layout.vaults._add(vault);
        // tokens = tokens._sort();
        // bytes32 contentsID = keccak256(abi.encode(tokens));
        /// forge-lint: disable-next-line(mixed-case-variable)
        // bytes32 contentsID = abi.encode(tokens).hash();
        // VaultRegistryLayout.contentsIds
        layout.contentsIds._add(vaultConfig.contentsId);
        // VaultRegistryLayout.vaultsOfPkg
        layout.vaultsOfPkg[pkg]._add(vault);
        // VaultRegistryLayout.vaultsOfContentsId
        layout.vaultsOfContentsId[vaultConfig.contentsId]._add(vault);
        // VaultRegistryLayout.vaultsOfContentsIdOfPkg
        layout.vaultsOfContentsIdOfPkg[pkg][vaultConfig.contentsId]._add(vault);
        layout.feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds;
        VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(vaultConfig.vaultFeeTypeIds);
        layout.usageFeeIdOfVault[vault] = feeTypeIds_.usage;
        layout.dexFeeIdOfVault[vault] = feeTypeIds_.dex;
        layout.bondFeeIdOfVault[vault] = feeTypeIds_.bond;
        layout.seigniorageIdOfVault[vault] = feeTypeIds_.seigniorage;
        layout.lendingFeeIdOfVault[vault] = feeTypeIds_.lending;
        // layout.tbdFeeIdOfVault0[vault] = feeTypeIds_.tbd0;
        // layout.tbdFeeIdOfVault1[vault] = feeTypeIds_.tbd1;
        // layout.tbdFeeIdOfVault2[vault] = feeTypeIds_.tbd2;
        // layout.tbdFeeIdOfVault3[vault] = feeTypeIds_.tbd3;
        emit IVaultRegistryEvents.NewVault(
            vault, pkg, vaultConfig.vaultFeeTypeIds, vaultConfig.contentsId, vaultConfig.vaultTypes, vaultConfig.tokens
        );
        for (uint256 typesCursor; typesCursor < vaultConfig.vaultTypes.length; typesCursor++) {
            // VaultRegistryLayout.vaultsOfType
            layout.vaultsOfType[vaultConfig.vaultTypes[typesCursor]]._add(vault);
            // VaultRegistryLayout.vaultsOfContentsIdOfTypeId
            layout.vaultsOfContentsIdOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.contentsId]._add(vault);
            emit IVaultRegistryEvents.NewVaultOfType(vault, pkg, vaultConfig.vaultTypes[typesCursor]);
            for (uint256 tokensCursor; tokensCursor < vaultConfig.tokens.length; tokensCursor++) {
                // VaultRegistryLayout.tokens
                layout.vaultTokens._add(vaultConfig.tokens[tokensCursor]);
                // VaultRegistryLayout.vaultsOfToken
                layout.vaultsOfToken[vaultConfig.tokens[tokensCursor]]._add(vault);
                // VaultRegistryLayout.vaultsOfTokenOfTypeId
                layout.vaultsOfTokenOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.tokens[tokensCursor]]._add(
                    vault
                );
                // VaultRegistryLayout.vaultsOfTokenOfPkg
                layout.vaultsOfTokenOfPkg[pkg][vaultConfig.tokens[tokensCursor]]._add(vault);
                emit IVaultRegistryEvents.NewVaultOfToken(vault, pkg, vaultConfig.tokens[tokensCursor]);
            }
        }
    }

    function _registerVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig) internal {
        _registerVault(_layout(), vault, pkg, vaultConfig);
    }

    function _removeVault(
        Storage storage layout,
        address vault,
        address pkg,
        IStandardVault.VaultConfig memory vaultConfig
    ) internal {
        // _registerVault(vault, pkg, vaultConfig.vaultTypes, vaultConfig.tokens);
        // VaultRegistryLayout.vaults
        layout.vaults._remove(vault);
        // tokens = tokens._sort();
        // bytes32 contentsID = keccak256(abi.encode(tokens));
        /// forge-lint: disable-next-line(mixed-case-variable)
        // bytes32 contentsID = abi.encode(tokens).hash();
        // VaultRegistryLayout.contentsIds
        // layout.contentsIds._add(vaultConfig.contentsId);
        // VaultRegistryLayout.vaultsOfPkg
        layout.vaultsOfPkg[pkg]._remove(vault);
        // VaultRegistryLayout.vaultsOfContentsId
        layout.vaultsOfContentsId[vaultConfig.contentsId]._remove(vault);
        // VaultRegistryLayout.vaultsOfContentsIdOfPkg
        layout.vaultsOfContentsIdOfPkg[pkg][vaultConfig.contentsId]._remove(vault);
        layout.feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds;
        // VaultFeeTypeIds memory feeTypeIds_ = VaultTypeUtils._decodeVaultFeeTypeIds(vaultConfig.vaultFeeTypeIds);
        delete layout.usageFeeIdOfVault[vault];
        delete layout.dexFeeIdOfVault[vault];
        delete layout.bondFeeIdOfVault[vault];
        delete layout.seigniorageIdOfVault[vault];
        delete layout.lendingFeeIdOfVault[vault];
        // layout.tbdFeeIdOfVault0[vault] = feeTypeIds_.tbd0;
        // layout.tbdFeeIdOfVault1[vault] = feeTypeIds_.tbd1;
        // layout.tbdFeeIdOfVault2[vault] = feeTypeIds_.tbd2;
        // layout.tbdFeeIdOfVault3[vault] = feeTypeIds_.tbd3;
        // emit IVaultRegistryEvents.NewVault(
        //     vault, pkg, vaultConfig.vaultFeeTypeIds, vaultConfig.contentsId, vaultConfig.vaultTypes, vaultConfig.tokens
        // );
        for (uint256 typesCursor; typesCursor < vaultConfig.vaultTypes.length; typesCursor++) {
            // VaultRegistryLayout.vaultsOfType
            layout.vaultsOfType[vaultConfig.vaultTypes[typesCursor]]._remove(vault);
            // VaultRegistryLayout.vaultsOfContentsIdOfTypeId
            layout.vaultsOfContentsIdOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.contentsId]._remove(
                vault
            );
            // emit IVaultRegistryEvents.NewVaultOfType(vault, pkg, vaultConfig.vaultTypes[typesCursor]);
            for (uint256 tokensCursor; tokensCursor < vaultConfig.tokens.length; tokensCursor++) {
                // VaultRegistryLayout.tokens
                // layout.vaultTokens._add(vaultConfig.tokens[tokensCursor]);
                // VaultRegistryLayout.vaultsOfToken
                layout.vaultsOfToken[vaultConfig.tokens[tokensCursor]]._remove(vault);
                // VaultRegistryLayout.vaultsOfTokenOfTypeId
                layout.vaultsOfTokenOfTypeId[vaultConfig.vaultTypes[typesCursor]][vaultConfig.tokens[tokensCursor]]._remove(
                    vault
                );
                // VaultRegistryLayout.vaultsOfTokenOfPkg
                layout.vaultsOfTokenOfPkg[pkg][vaultConfig.tokens[tokensCursor]]._remove(vault);
                // emit IVaultRegistryEvents.NewVaultOfToken(vault, pkg, vaultConfig.tokens[tokensCursor]);
            }
        }
    }

    function _removeVault(address vault, address pkg, IStandardVault.VaultConfig memory vaultConfig) internal {
        _removeVault(_layout(), vault, pkg, vaultConfig);
    }

    function _isVault(Storage storage layout, address vault) internal view returns (bool) {
        return layout.vaults._contains(vault);
    }

    function _isVault(address vault) internal view returns (bool) {
        return _isVault(_layout(), vault);
    }

    function _vaults(Storage storage layout) internal view returns (address[] memory vaults_) {
        return layout.vaults._values();
    }

    function _vaults() internal view returns (address[] memory vaults_) {
        return _vaults(_layout());
    }

    function _contentsIds(Storage storage layout) internal view returns (bytes32[] memory contentsIds_) {
        return layout.contentsIds._values();
    }

    function _contentsIds() internal view returns (bytes32[] memory contentsIds_) {
        return _contentsIds(_layout());
    }

    function _vaultTokens(Storage storage layout) internal view returns (address[] memory vaultTokens_) {
        return layout.vaultTokens._values();
    }

    function _vaultTokens() internal view returns (address[] memory vaultTokens_) {
        return _vaultTokens(_layout());
    }

    function _isContainedToken(Storage storage layout, address token) internal view returns (bool) {
        return layout.vaultTokens._contains(token);
    }

    function _isContainedToken(address token) internal view returns (bool) {
        return _isContainedToken(_layout(), token);
    }

    function _vaultFeeTypeIds(Storage storage layout, address vault) internal view returns (bytes32 feeTypeIds_) {
        return layout.feeTypeIdsOfVault[vault];
    }

    function _vaultFeeTypeIds(address vault) internal view returns (bytes32 feeTypeIds_) {
        return _vaultFeeTypeIds(_layout(), vault);
    }

    function _vaultsOfPkg(Storage storage layout, address pkg) internal view returns (address[] memory vaults_) {
        return layout.vaultsOfPkg[pkg]._values();
    }

    function _vaultsOfPkg(address pkg) internal view returns (address[] memory vaults_) {
        return _vaultsOfPkg(_layout(), pkg);
    }

    function _vaultsOfToken(Storage storage layout, address token) internal view returns (address[] memory vaults_) {
        return layout.vaultsOfToken[token]._values();
    }

    function _vaultsOfToken(address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfToken(_layout(), token);
    }

    function _vaultsOfContentsId(Storage storage layout, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layout.vaultsOfContentsId[contentsId]._values();
    }

    function _vaultsOfContentsId(bytes32 contentsId) internal view returns (address[] memory vaults_) {
        return _vaultsOfContentsId(_layout(), contentsId);
    }

    function _vaultsOfType(Storage storage layout, bytes4 typeId) internal view returns (address[] memory vaults_) {
        return layout.vaultsOfType[typeId]._values();
    }

    function _vaultsOfType(bytes4 typeId) internal view returns (address[] memory vaults_) {
        return _vaultsOfType(_layout(), typeId);
    }

    function _vaultsOfTokenOfTypeId(Storage storage layout, bytes4 typeId, address token)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layout.vaultsOfTokenOfTypeId[typeId][token]._values();
    }

    function _vaultsOfTokenOfTypeId(bytes4 typeId, address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfTokenOfTypeId(_layout(), typeId, token);
    }

    function _vaultsOfContentsIdOfTypeId(Storage storage layout, bytes4 typeId, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layout.vaultsOfContentsIdOfTypeId[typeId][contentsId]._values();
    }

    function _vaultsOfContentsIdOfTypeId(bytes4 typeId, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return _vaultsOfContentsIdOfTypeId(_layout(), typeId, contentsId);
    }

    function _vaultsOfTokenOfPkg(Storage storage layout, address pkg, address token)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layout.vaultsOfTokenOfPkg[pkg][token]._values();
    }

    function _vaultsOfTokenOfPkg(address pkg, address token) internal view returns (address[] memory vaults_) {
        return _vaultsOfTokenOfPkg(_layout(), pkg, token);
    }

    function _vaultsOfContentsIdOfPkg(Storage storage layout, address pkg, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return layout.vaultsOfContentsIdOfPkg[pkg][contentsId]._values();
    }

    function _vaultsOfContentsIdOfPkg(address pkg, bytes32 contentsId)
        internal
        view
        returns (address[] memory vaults_)
    {
        return _vaultsOfContentsIdOfPkg(_layout(), pkg, contentsId);
    }

    function _usageFeeIdOfVault(Storage storage layout, address vault) internal view returns (bytes4 usageFeeId_) {
        return layout.usageFeeIdOfVault[vault];
    }

    function _usageFeeIdOfVault(address vault) internal view returns (bytes4 usageFeeId_) {
        return _usageFeeIdOfVault(_layout(), vault);
    }

    function _dexFeeIdOfVault(Storage storage layout, address vault) internal view returns (bytes4 dexFeeId_) {
        return layout.dexFeeIdOfVault[vault];
    }

    function _dexFeeIdOfVault(address vault) internal view returns (bytes4 dexFeeId_) {
        return _dexFeeIdOfVault(_layout(), vault);
    }

    function _bondFeeIdOfVault(Storage storage layout, address vault) internal view returns (bytes4 bondFeeId_) {
        return layout.bondFeeIdOfVault[vault];
    }

    function _bondFeeIdOfVault(address vault) internal view returns (bytes4 bondFeeId_) {
        return _bondFeeIdOfVault(_layout(), vault);
    }

    function _seigniorageIncentiveIdOfVault(Storage storage layout, address vault)
        internal
        view
        returns (bytes4 seigniorageId_)
    {
        return layout.seigniorageIdOfVault[vault];
    }

    function _seigniorageIncentiveIdOfVault(address vault) internal view returns (bytes4 seigniorageId_) {
        return _seigniorageIncentiveIdOfVault(_layout(), vault);
    }

    function _lendingFeeIdOfVault(Storage storage layout, address vault) internal view returns (bytes4 lendingFeeId_) {
        return layout.lendingFeeIdOfVault[vault];
    }

    function _lendingFeeIdOfVault(address vault) internal view returns (bytes4 lendingFeeId_) {
        return _lendingFeeIdOfVault(_layout(), vault);
    }
}
