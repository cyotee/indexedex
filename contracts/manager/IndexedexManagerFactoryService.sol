// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
// import {DeployedAddressesRepo} from "@crane/contracts/script/DeployedAddressesRepo.sol";
// import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

import {VaultFeeOracleQueryFacet} from "contracts/oracles/fee/VaultFeeOracleQueryFacet.sol";
import {VaultFeeOracleManagerFacet} from "contracts/oracles/fee/VaultFeeOracleManagerFacet.sol";
import {VaultRegistryDeploymentFacet} from "contracts/registries/vault/VaultRegistryDeploymentFacet.sol";
import {VaultRegistryVaultManagerFacet} from "contracts/registries/vault/VaultRegistryVaultManagerFacet.sol";
import {
    VaultRegistryVaultPackageManagerFacet
} from "contracts/registries/vault/VaultRegistryVaultPackageManagerFacet.sol";
import {VaultRegistryVaultPackageQueryFacet} from "contracts/registries/vault/VaultRegistryVaultPackageQueryFacet.sol";
import {VaultRegistryVaultQueryFacet} from "contracts/registries/vault/VaultRegistryVaultQueryFacet.sol";
import {IIndexedexManagerDFPkg, IndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";

library IndexedexManagerFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployVaultFeeOracleQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultFeeOracleQueryFacet)
    {
        vaultFeeOracleQueryFacet = create3Factory.deployFacet(
            type(VaultFeeOracleQueryFacet).creationCode, abi.encode(type(VaultFeeOracleQueryFacet).name)._hash()
        );
        vm.label(address(vaultFeeOracleQueryFacet), type(VaultFeeOracleQueryFacet).name);
    }

    function deployVaultFeeOracleManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultFeeOracleManagerFacet)
    {
        vaultFeeOracleManagerFacet = create3Factory.deployFacet(
            type(VaultFeeOracleManagerFacet).creationCode, abi.encode(type(VaultFeeOracleManagerFacet).name)._hash()
        );
        vm.label(address(vaultFeeOracleManagerFacet), type(VaultFeeOracleManagerFacet).name);
    }

    function deployVaultRegistryDeploymentFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryDeploymentFacet)
    {
        vaultRegistryDeploymentFacet = create3Factory.deployFacet(
            type(VaultRegistryDeploymentFacet).creationCode, abi.encode(type(VaultRegistryDeploymentFacet).name)._hash()
        );
        vm.label(address(vaultRegistryDeploymentFacet), type(VaultRegistryDeploymentFacet).name);
    }

    function deployVaultRegistryVaultManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultManagerFacet)
    {
        vaultRegistryVaultManagerFacet = create3Factory.deployFacet(
            type(VaultRegistryVaultManagerFacet).creationCode,
            abi.encode(type(VaultRegistryVaultManagerFacet).name)._hash()
        );
        vm.label(address(vaultRegistryVaultManagerFacet), type(VaultRegistryVaultManagerFacet).name);
    }

    function deployVaultRegistryVaultPackageManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultPackageManagerFacet)
    {
        vaultRegistryVaultPackageManagerFacet = create3Factory.deployFacet(
            type(VaultRegistryVaultPackageManagerFacet).creationCode,
            abi.encode(type(VaultRegistryVaultPackageManagerFacet).name)._hash()
        );
        vm.label(address(vaultRegistryVaultPackageManagerFacet), type(VaultRegistryVaultPackageManagerFacet).name);
    }

    function deployVaultRegistryVaultPackageQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultPackageQueryFacet)
    {
        vaultRegistryVaultPackageQueryFacet = create3Factory.deployFacet(
            type(VaultRegistryVaultPackageQueryFacet).creationCode,
            abi.encode(type(VaultRegistryVaultPackageQueryFacet).name)._hash()
        );
        vm.label(address(vaultRegistryVaultPackageQueryFacet), type(VaultRegistryVaultPackageQueryFacet).name);
    }

    function deployVaultRegistryVaultQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultQueryFacet)
    {
        vaultRegistryVaultQueryFacet = create3Factory.deployFacet(
            type(VaultRegistryVaultQueryFacet).creationCode, abi.encode(type(VaultRegistryVaultQueryFacet).name)._hash()
        );
        vm.label(address(vaultRegistryVaultQueryFacet), type(VaultRegistryVaultQueryFacet).name);
    }

    function deployIndexedexManagerDFPkg(
        ICreate3FactoryProxy create3Factory,
        IFacet diamondCutFacet,
        IFacet multiStepOwnableFacet,
        IFacet vaultFeeOracleQueryFacet,
        IFacet vaultFeeOracleManagerFacet,
        IFacet operableFacet,
        IFacet vaultRegistryDeploymentFacet,
        IFacet vaultRegistryVaultManagerFacet,
        IFacet vaultRegistryVaultPackageManagerFacet,
        IFacet vaultRegistryVaultPackageQueryFacet,
        IFacet vaultRegistryVaultQueryFacet
    ) internal returns (IIndexedexManagerDFPkg indexedexManagerDFPkg) {
        indexedexManagerDFPkg = IIndexedexManagerDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(IndexedexManagerDFPkg).creationCode,
                    abi.encode(
                        IIndexedexManagerDFPkg.PkgInit({
                            diamondCutFacet: diamondCutFacet,
                            multiStepOwnableFacet: multiStepOwnableFacet,
                            vaultFeeQueryFacet: vaultFeeOracleQueryFacet,
                            vaultFeeManagerFacet: vaultFeeOracleManagerFacet,
                            operableFacet: operableFacet,
                            vaultRegistryDeploymentFacet: vaultRegistryDeploymentFacet,
                            vaultRegistryVaultManagerFacet: vaultRegistryVaultManagerFacet,
                            vaultRegistryVaultPackageManagerFacet: vaultRegistryVaultPackageManagerFacet,
                            vaultRegistryVaultPackageQueryFacet: vaultRegistryVaultPackageQueryFacet,
                            vaultRegistryVaultQueryFacet: vaultRegistryVaultQueryFacet
                        })
                    ),
                    abi.encode(type(IndexedexManagerDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(indexedexManagerDFPkg), type(IndexedexManagerDFPkg).name);
    }

    function deployIndexedexManager(
        IDiamondPackageCallBackFactory diamondFactory,
        ICreate3FactoryProxy create3Factory,
        IIndexedexManagerDFPkg indexedexManagerDFPkg,
        address owner,
        IFeeCollectorProxy feeTo
    ) internal returns (IIndexedexManagerProxy indexedexManager) {
        IIndexedexManagerDFPkg.PkgArgs memory pkgArgs = IIndexedexManagerDFPkg.PkgArgs({
            owner: owner, feeTo: feeTo, create3Factory: create3Factory, diamondPackageFactory: diamondFactory
        });

        indexedexManager = IIndexedexManagerProxy(diamondFactory.deploy(indexedexManagerDFPkg, abi.encode(pkgArgs)));
        vm.label(address(indexedexManager), "IndexedexManager");
    }
}
