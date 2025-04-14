// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";

contract IndexedexTest is CraneTest {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;

    address owner;

    IFacet multiStepOwnableFacet;

    // IFacet operableFacet;

    // IFacet reentrancyLockFacet;

    // IFacet erc165Facet;

    // IFacet diamondLoupeFacet;

    IFacet diamondCutFacet;

    IFacet feeCollectorManagerFacet;

    IFacet feeCollectorSingleTokenPushFacet;

    IFeeCollectorDFPkg feeCollectorDFPkg;

    IFeeCollectorProxy feeCollector;

    IFacet vaultFeeOracleQueryFacet;

    IFacet vaultFeeOracleManagerFacet;

    IFacet vaultRegistryDeploymentFacet;

    IFacet vaultRegistryVaultManagerFacet;

    IFacet vaultRegistryVaultPackageManagerFacet;

    IFacet vaultRegistryVaultPackageQueryFacet;

    IFacet vaultRegistryVaultQueryFacet;

    IIndexedexManagerDFPkg indexedexManagerDFPkg;

    IIndexedexManagerProxy indexedexManager;

    function setUp() public virtual override {
        CraneTest.setUp();

        if (address(owner) == address(0)) {
            owner = makeAddr("owner");
            multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
            vm.label(address(multiStepOwnableFacet), "multiStepOwnableFacet");
            diamondCutFacet = create3Factory.deployDiamondCutFacet();
            vm.label(address(diamondCutFacet), "diamondCutFacet");
            feeCollectorManagerFacet = create3Factory.deployFeeCollectorManagerFacet();
            vm.label(address(feeCollectorManagerFacet), "feeCollectorManagerFacet");
            feeCollectorSingleTokenPushFacet = create3Factory.deployFeeCollectorSingleTokenPushFacet();
            vm.label(address(feeCollectorSingleTokenPushFacet), "feeCollectorSingleTokenPushFacet");
            feeCollectorDFPkg = create3Factory.deployFeeCollectorDFPkg(
                diamondCutFacet, multiStepOwnableFacet, feeCollectorSingleTokenPushFacet, feeCollectorManagerFacet
            );
            vm.label(address(feeCollectorDFPkg), "feeCollectorDFPkg");
            feeCollector = diamondPackageFactory.deployFeeCollector(
                // IDiamondPackageCallBackFactory diamondFactory,
                // IFeeCollectorDFPkg feeCollectorDFPkg,
                feeCollectorDFPkg,
                // address owner
                owner
            );
            vm.label(address(feeCollector), "feeCollector");

            vaultFeeOracleQueryFacet = create3Factory.deployVaultFeeOracleQueryFacet();
            vm.label(address(vaultFeeOracleQueryFacet), "vaultFeeOracleQueryFacet");
            vaultFeeOracleManagerFacet = create3Factory.deployVaultFeeOracleManagerFacet();
            vm.label(address(vaultFeeOracleManagerFacet), "vaultFeeOracleManagerFacet");
            vaultRegistryDeploymentFacet = create3Factory.deployVaultRegistryDeploymentFacet();
            vm.label(address(vaultRegistryDeploymentFacet), "vaultRegistryDeploymentFacet");
            vaultRegistryVaultManagerFacet = create3Factory.deployVaultRegistryVaultManagerFacet();
            vm.label(address(vaultRegistryVaultManagerFacet), "vaultRegistryVaultManagerFacet");
            vaultRegistryVaultPackageManagerFacet = create3Factory.deployVaultRegistryVaultPackageManagerFacet();
            vm.label(address(vaultRegistryVaultPackageManagerFacet), "vaultRegistryVaultPackageManagerFacet");
            vaultRegistryVaultPackageQueryFacet = create3Factory.deployVaultRegistryVaultPackageQueryFacet();
            vm.label(address(vaultRegistryVaultPackageQueryFacet), "vaultRegistryVaultPackageQueryFacet");
            vaultRegistryVaultQueryFacet = create3Factory.deployVaultRegistryVaultQueryFacet();
            vm.label(address(vaultRegistryVaultQueryFacet), "vaultRegistryVaultQueryFacet");
            // deploy operableFacet and include it in the manager package so operator tests use the real operable implementation
            IFacet operableFacet = create3Factory.deployOperableFacet();
            vm.label(address(operableFacet), "operableFacet");

            indexedexManagerDFPkg = create3Factory.deployIndexedexManagerDFPkg(
                // ICreate3FactoryProxy create3Factory,
                // IFacet diamondCutFacet,
                diamondCutFacet,
                // IFacet multiStepOwnableFacet,
                multiStepOwnableFacet,
                // IFacet vaultFeeOracleQueryFacet,
                vaultFeeOracleQueryFacet,
                // IFacet vaultFeeOracleManagerFacet,
                vaultFeeOracleManagerFacet,
                // IFacet operableFacet,
                operableFacet,
                // IFacet vaultRegistryDeploymentFacet,
                vaultRegistryDeploymentFacet,
                // IFacet vaultRegistryVaultManagerFacet,
                vaultRegistryVaultManagerFacet,
                // IFacet vaultRegistryVaultPackageManagerFacet,
                vaultRegistryVaultPackageManagerFacet,
                // IFacet vaultRegistryVaultPackageQueryFacet,
                vaultRegistryVaultPackageQueryFacet,
                // IFacet vaultRegistryVaultQueryFacet
                vaultRegistryVaultQueryFacet
            );
            vm.label(address(indexedexManagerDFPkg), "indexedexManagerDFPkg");
            indexedexManager = diamondPackageFactory.deployIndexedexManager(
                create3Factory, indexedexManagerDFPkg, owner, feeCollector
            );
            vm.label(address(indexedexManager), "indexedexManager");
            // Register IndexedexManager as an operator on Create3Factory so it can deploy packages
            IOperable(address(create3Factory)).setOperator(address(indexedexManager), true);
        }

        // operableFacet = create3Factory.deployOperableFacet();
        // reentrancyLockFacet = create3Factory.deployReentrancyLockFacet();
        // erc165Facet = create3Factory.deployERC165Facet();
        // diamondLoupeFacet = create3Factory.deployDiamondLoupeFacet();
    }
}
