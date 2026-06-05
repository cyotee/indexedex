// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";

import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";

contract Script_03_DeployCoreProxies is DeploymentBase {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IFacet private multiStepOwnableFacet;
    IFacet private diamondCutFacet;

    IFeeCollectorProxy private feeCollector;
    IIndexedexManagerProxy private indexedexManager;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 3: Deploy Core Proxies");

        vm.startBroadcast();

        _deployFeeCollector();
        _deployIndexedexManager();
        _configureOperators();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));
        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");

        multiStepOwnableFacet = IFacet(_readAddress("02_shared_facets.json", "multiStepOwnableFacet"));
        diamondCutFacet = IFacet(_readAddress("02_shared_facets.json", "diamondCutFacet"));
        require(address(multiStepOwnableFacet) != address(0), "MultiStepOwnableFacet not found");
        require(address(diamondCutFacet) != address(0), "DiamondCutFacet not found");
    }

    function _deployFeeCollector() internal {
        IFacet feeCollectorManagerFacet = create3Factory.deployFeeCollectorManagerFacet();
        IFacet feeCollectorSingleTokenPushFacet = create3Factory.deployFeeCollectorSingleTokenPushFacet();

        IFeeCollectorDFPkg feeCollectorDFPkg = create3Factory.deployFeeCollectorDFPkg(
            diamondCutFacet,
            multiStepOwnableFacet,
            feeCollectorSingleTokenPushFacet,
            feeCollectorManagerFacet
        );

        feeCollector = diamondPackageFactory.deployFeeCollector(feeCollectorDFPkg, owner);
    }

    function _deployIndexedexManager() internal {
        IFacet vaultFeeOracleQueryFacet = create3Factory.deployVaultFeeOracleQueryFacet();
        IFacet vaultFeeOracleManagerFacet = create3Factory.deployVaultFeeOracleManagerFacet();
        IFacet operableFacet = create3Factory.deployOperableFacet();
        IFacet vaultRegistryDeploymentFacet = create3Factory.deployVaultRegistryDeploymentFacet();
        IFacet vaultRegistryVaultManagerFacet = create3Factory.deployVaultRegistryVaultManagerFacet();
        IFacet vaultRegistryVaultPackageManagerFacet = create3Factory.deployVaultRegistryVaultPackageManagerFacet();
        IFacet vaultRegistryVaultPackageQueryFacet = create3Factory.deployVaultRegistryVaultPackageQueryFacet();
        IFacet vaultRegistryVaultQueryFacet = create3Factory.deployVaultRegistryVaultQueryFacet();

        IIndexedexManagerDFPkg indexedexManagerDFPkg = create3Factory.deployIndexedexManagerDFPkg(
            diamondCutFacet,
            multiStepOwnableFacet,
            vaultFeeOracleQueryFacet,
            vaultFeeOracleManagerFacet,
            operableFacet,
            vaultRegistryDeploymentFacet,
            vaultRegistryVaultManagerFacet,
            vaultRegistryVaultPackageManagerFacet,
            vaultRegistryVaultPackageQueryFacet,
            vaultRegistryVaultQueryFacet
        );

        indexedexManager = diamondPackageFactory.deployIndexedexManager(
            create3Factory,
            indexedexManagerDFPkg,
            owner,
            feeCollector
        );
    }

    function _configureOperators() internal {
        IOperable(address(create3Factory)).setOperator(address(indexedexManager), true);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("core", "feeCollector", address(feeCollector));
        json = vm.serializeAddress("core", "indexedexManager", address(indexedexManager));
        json = vm.serializeAddress("core", "vaultRegistry", address(indexedexManager));
        json = vm.serializeAddress("core", "vaultFeeOracle", address(indexedexManager));
        _writeJson(json, "03_core_proxies.json");
    }

    function _logResults() internal view {
        _logAddress("FeeCollector:", address(feeCollector));
        _logAddress("IndexedexManager:", address(indexedexManager));
        _logComplete("Stage 3");
    }
}
