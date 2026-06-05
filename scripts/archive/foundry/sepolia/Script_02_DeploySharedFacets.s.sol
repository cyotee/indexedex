// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

contract Script_02_DeploySharedFacets is DeploymentBase {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;
    IFacet private multiStepOwnableFacet;
    IFacet private operableFacet;
    IFacet private diamondCutFacet;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 2: Deploy Shared Facets");

        vm.startBroadcast();

        _deploySharedFacets();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        require(address(create3Factory) != address(0), "Create3Factory not found - run Script_01 first");
    }

    function _deploySharedFacets() internal {
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();

        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();

        multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        operableFacet = create3Factory.deployOperableFacet();

        diamondCutFacet = create3Factory.deployDiamondCutFacet();
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("facets", "erc20Facet", address(erc20Facet));
        json = vm.serializeAddress("facets", "erc2612Facet", address(erc2612Facet));
        json = vm.serializeAddress("facets", "erc5267Facet", address(erc5267Facet));
        json = vm.serializeAddress("facets", "erc4626Facet", address(erc4626Facet));
        json = vm.serializeAddress("facets", "erc4626BasicVaultFacet", address(erc4626BasicVaultFacet));
        json = vm.serializeAddress("facets", "erc4626StandardVaultFacet", address(erc4626StandardVaultFacet));
        json = vm.serializeAddress("facets", "multiStepOwnableFacet", address(multiStepOwnableFacet));
        json = vm.serializeAddress("facets", "operableFacet", address(operableFacet));
        json = vm.serializeAddress("facets", "diamondCutFacet", address(diamondCutFacet));
        _writeJson(json, "02_shared_facets.json");
    }

    function _logResults() internal view {
        _logAddress("ERC20Facet:", address(erc20Facet));
        _logAddress("ERC2612Facet:", address(erc2612Facet));
        _logAddress("ERC5267Facet:", address(erc5267Facet));
        _logAddress("ERC4626Facet:", address(erc4626Facet));
        _logAddress("ERC4626BasicVaultFacet:", address(erc4626BasicVaultFacet));
        _logAddress("ERC4626StandardVaultFacet:", address(erc4626StandardVaultFacet));
        _logAddress("MultiStepOwnableFacet:", address(multiStepOwnableFacet));
        _logAddress("OperableFacet:", address(operableFacet));
        _logAddress("DiamondCutFacet:", address(diamondCutFacet));
        _logComplete("Stage 2");
    }
}
