// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

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

import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";

library IndexedexManagerFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployVaultFeeOracleQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultFeeOracleQueryFacet)
    {
        vaultFeeOracleQueryFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultFeeOracleQueryFacet.sol:VaultFeeOracleQueryFacet"), abi.encode("VaultFeeOracleQueryFacet")._hash()
        );
        vm.label(address(vaultFeeOracleQueryFacet), "VaultFeeOracleQueryFacet");
    }

    function deployVaultFeeOracleManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultFeeOracleManagerFacet)
    {
        vaultFeeOracleManagerFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultFeeOracleManagerFacet.sol:VaultFeeOracleManagerFacet"), abi.encode("VaultFeeOracleManagerFacet")._hash()
        );
        vm.label(address(vaultFeeOracleManagerFacet), "VaultFeeOracleManagerFacet");
    }

    function deployVaultRegistryDeploymentFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryDeploymentFacet)
    {
        vaultRegistryDeploymentFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryDeploymentFacet.sol:VaultRegistryDeploymentFacet"), abi.encode("VaultRegistryDeploymentFacet")._hash()
        );
        vm.label(address(vaultRegistryDeploymentFacet), "VaultRegistryDeploymentFacet");
    }

    function deployVaultRegistryVaultManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultManagerFacet)
    {
        vaultRegistryVaultManagerFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryVaultManagerFacet.sol:VaultRegistryVaultManagerFacet"),
            abi.encode("VaultRegistryVaultManagerFacet")._hash()
        );
        vm.label(address(vaultRegistryVaultManagerFacet), "VaultRegistryVaultManagerFacet");
    }

    function deployVaultRegistryVaultPackageManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultPackageManagerFacet)
    {
        vaultRegistryVaultPackageManagerFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryVaultPackageManagerFacet.sol:VaultRegistryVaultPackageManagerFacet"),
            abi.encode("VaultRegistryVaultPackageManagerFacet")._hash()
        );
        vm.label(address(vaultRegistryVaultPackageManagerFacet), "VaultRegistryVaultPackageManagerFacet");
    }

    function deployVaultRegistryVaultPackageQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultPackageQueryFacet)
    {
        vaultRegistryVaultPackageQueryFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryVaultPackageQueryFacet.sol:VaultRegistryVaultPackageQueryFacet"),
            abi.encode("VaultRegistryVaultPackageQueryFacet")._hash()
        );
        vm.label(address(vaultRegistryVaultPackageQueryFacet), "VaultRegistryVaultPackageQueryFacet");
    }

    function deployVaultRegistryVaultQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryVaultQueryFacet)
    {
        vaultRegistryVaultQueryFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryVaultQueryFacet.sol:VaultRegistryVaultQueryFacet"), abi.encode("VaultRegistryVaultQueryFacet")._hash()
        );
        vm.label(address(vaultRegistryVaultQueryFacet), "VaultRegistryVaultQueryFacet");
    }

    function deployVaultRegistryDisableQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryDisableQueryFacet)
    {
        vaultRegistryDisableQueryFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryDisableQueryFacet.sol:VaultRegistryDisableQueryFacet"),
            abi.encode("VaultRegistryDisableQueryFacet")._hash()
        );
        vm.label(address(vaultRegistryDisableQueryFacet), "VaultRegistryDisableQueryFacet");
    }

    function deployVaultRegistryDisableManagerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet vaultRegistryDisableManagerFacet)
    {
        vaultRegistryDisableManagerFacet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("VaultRegistryDisableManagerFacet.sol:VaultRegistryDisableManagerFacet"),
            abi.encode("VaultRegistryDisableManagerFacet")._hash()
        );
        vm.label(address(vaultRegistryDisableManagerFacet), "VaultRegistryDisableManagerFacet");
    }

    function deployIndexedexManagerDFPkg(ICreate3FactoryProxy create3Factory, IIndexedexManagerDFPkg.PkgInit memory pkgInit)
        internal
        returns (IIndexedexManagerDFPkg indexedexManagerDFPkg)
    {
        indexedexManagerDFPkg = IIndexedexManagerDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode("IndexedexManagerDFPkg.sol:IndexedexManagerDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("IndexedexManagerDFPkg")._hash()
                )
            )
        );
        vm.label(address(indexedexManagerDFPkg), "IndexedexManagerDFPkg");
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
