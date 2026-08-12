// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";

import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

/// @title Script_02_DeployIndexedexCore
/// @notice Deploys the local-testing Indexedex core proxies and registry surface
contract Script_02_DeployIndexedexCore is LocalTestingDeploymentBase {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant ARTIFACT_FILE = "02_indexedex_core.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IFacet private multiStepOwnableFacet;
    IFacet private diamondCutFacet;

    IFeeCollectorProxy private feeCollector;
    IIndexedexManagerProxy private indexedexManager;

    function run() external {
        _loadConfig();
        _loadCraneFoundation();

        _logHeader("Stage 02: Deploy Indexedex Core");

        if (_loadExistingCore()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();

        _deployFeeCollector();
        _deployIndexedexManager();
        _configureOperators();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadCraneFoundation() internal {
        address create3FactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "create3Factory");
        address diamondPackageFactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory");
        address multiStepOwnableFacetAddr = _readAddress(CRANE_FOUNDATION_FILE, "multiStepOwnableFacet");
        address diamondCutFacetAddr = _readAddress(CRANE_FOUNDATION_FILE, "diamondCutFacet");

        require(create3FactoryAddr != address(0), "Create3Factory not found - run Script_01 first");
        require(diamondPackageFactoryAddr != address(0), "DiamondPackageFactory not found - run Script_01 first");
        require(multiStepOwnableFacetAddr != address(0), "MultiStepOwnableFacet not found - run Script_01 first");
        require(diamondCutFacetAddr != address(0), "DiamondCutFacet not found - run Script_01 first");

        create3Factory = ICreate3FactoryProxy(create3FactoryAddr);
        diamondPackageFactory = IDiamondPackageCallBackFactory(diamondPackageFactoryAddr);
        multiStepOwnableFacet = IFacet(multiStepOwnableFacetAddr);
        diamondCutFacet = IFacet(diamondCutFacetAddr);
    }

    function _loadExistingCore() internal returns (bool) {
        (address feeCollectorAddr, bool hasFeeCollector) = _readAddressSafe(ARTIFACT_FILE, "feeCollector");
        (address indexedexManagerAddr, bool hasIndexedexManager) = _readAddressSafe(ARTIFACT_FILE, "indexedexManager");

        if (!hasFeeCollector || !hasIndexedexManager) {
            return false;
        }

        if (feeCollectorAddr.code.length == 0 || indexedexManagerAddr.code.length == 0) {
            return false;
        }

        feeCollector = IFeeCollectorProxy(feeCollectorAddr);
        indexedexManager = IIndexedexManagerProxy(indexedexManagerAddr);
        return true;
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

        IFacet vaultRegistryDisableQueryFacet = create3Factory.deployVaultRegistryDisableQueryFacet();

        IFacet vaultRegistryDisableManagerFacet = create3Factory.deployVaultRegistryDisableManagerFacet();

        IIndexedexManagerDFPkg indexedexManagerDFPkg = create3Factory.deployIndexedexManagerDFPkg(
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
                vaultRegistryVaultQueryFacet: vaultRegistryVaultQueryFacet,
                vaultRegistryDisableQueryFacet: vaultRegistryDisableQueryFacet,
                vaultRegistryDisableManagerFacet: vaultRegistryDisableManagerFacet
            })
            );

        indexedexManager =
            diamondPackageFactory.deployIndexedexManager(create3Factory, indexedexManagerDFPkg, owner, feeCollector);
    }

    function _configureOperators() internal {
        IOperable(address(create3Factory)).setOperator(address(indexedexManager), true);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("indexedexCore", "feeCollector", address(feeCollector));
        json = vm.serializeAddress("indexedexCore", "indexedexManager", address(indexedexManager));
        json = vm.serializeAddress("indexedexCore", "vaultRegistry", address(indexedexManager));
        json = vm.serializeAddress("indexedexCore", "vaultFeeOracle", address(indexedexManager));
        json = vm.serializeAddress("indexedexCore", "owner", owner);
        json = vm.serializeAddress("indexedexCore", "deployer", deployer);
        json = vm.serializeUint("indexedexCore", "chainId", block.chainid);
        json = vm.serializeString("indexedexCore", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("FeeCollector:", address(feeCollector));
        _logAddress("IndexedexManager:", address(indexedexManager));
        _logAddress("Owner:", owner);
        _logAddress("Deployer:", deployer);
        _logUint("ChainId:", block.chainid);
        _logComplete("Stage 02");
    }
}