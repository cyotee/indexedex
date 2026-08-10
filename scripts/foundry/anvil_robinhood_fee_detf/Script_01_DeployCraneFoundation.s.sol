// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/// @title Script_01_DeployCraneFoundation
/// @notice CREATE3 + diamond package factory + shared facets for later stages.
contract Script_01_DeployCraneFoundation is DeploymentBase {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    string internal constant ARTIFACT_FILE = "01_crane_foundation.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;
    IFacet private multiStepOwnableFacet;
    IFacet private operableFacet;
    IFacet private diamondCutFacet;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader("Stage 01: Deploy Crane Foundation");

        if (_loadExistingFoundation()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        (create3Factory, diamondPackageFactory) = InitDevService.initEnv(deployer);
        _deploySharedFacets();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _deploySharedFacets() internal {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        operableFacet = create3Factory.deployOperableFacet();
        diamondCutFacet = create3Factory.deployDiamondCutFacet();
    }

    function _loadExistingFoundation() internal returns (bool) {
        address loadedAddress;
        bool exists;

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "create3Factory");
        if (!exists || loadedAddress.code.length == 0) return false;
        create3Factory = ICreate3FactoryProxy(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "diamondPackageFactory");
        if (!exists || loadedAddress.code.length == 0) return false;
        diamondPackageFactory = IDiamondPackageCallBackFactory(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc20Facet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc20Facet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc2612Facet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc2612Facet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc5267Facet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc5267Facet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc4626Facet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc4626Facet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc4626BasicVaultFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc4626BasicVaultFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "erc4626StandardVaultFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        erc4626StandardVaultFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "multiAssetBasicVaultFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        multiAssetBasicVaultFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "multiAssetStandardVaultFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        multiAssetStandardVaultFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "multiStepOwnableFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        multiStepOwnableFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "operableFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        operableFacet = IFacet(loadedAddress);

        (loadedAddress, exists) = _readAddressSafe(ARTIFACT_FILE, "diamondCutFacet");
        if (!exists || loadedAddress.code.length == 0) return false;
        diamondCutFacet = IFacet(loadedAddress);

        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("craneFoundation", "create3Factory", address(create3Factory));
        json = vm.serializeAddress("craneFoundation", "diamondPackageFactory", address(diamondPackageFactory));
        json = vm.serializeAddress("craneFoundation", "erc20Facet", address(erc20Facet));
        json = vm.serializeAddress("craneFoundation", "erc2612Facet", address(erc2612Facet));
        json = vm.serializeAddress("craneFoundation", "erc5267Facet", address(erc5267Facet));
        json = vm.serializeAddress("craneFoundation", "erc4626Facet", address(erc4626Facet));
        json = vm.serializeAddress("craneFoundation", "erc4626BasicVaultFacet", address(erc4626BasicVaultFacet));
        json = vm.serializeAddress("craneFoundation", "erc4626StandardVaultFacet", address(erc4626StandardVaultFacet));
        json = vm.serializeAddress("craneFoundation", "multiAssetBasicVaultFacet", address(multiAssetBasicVaultFacet));
        json = vm.serializeAddress("craneFoundation", "multiAssetStandardVaultFacet", address(multiAssetStandardVaultFacet));
        json = vm.serializeAddress("craneFoundation", "multiStepOwnableFacet", address(multiStepOwnableFacet));
        json = vm.serializeAddress("craneFoundation", "operableFacet", address(operableFacet));
        json = vm.serializeAddress("craneFoundation", "diamondCutFacet", address(diamondCutFacet));
        json = vm.serializeAddress("craneFoundation", "owner", owner);
        json = vm.serializeAddress("craneFoundation", "deployer", deployer);
        json = vm.serializeUint("craneFoundation", "chainId", block.chainid);
        json = vm.serializeString("craneFoundation", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("Create3Factory:", address(create3Factory));
        _logAddress("DiamondPackageFactory:", address(diamondPackageFactory));
        _logComplete("Stage 01");
    }
}
