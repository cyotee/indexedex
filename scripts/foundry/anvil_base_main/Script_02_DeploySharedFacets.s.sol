// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/// @title Script_02_DeploySharedFacets
/// @notice Deploys all shared facets that are reused across packages
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_02_DeploySharedFacets.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_02_DeploySharedFacets is DeploymentBase {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;

    // Shared facets
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
        _loadConfig();
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
        // ERC20/Token facets
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();

        // ERC4626 vault facets
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();

        // Access/ownership facets
        multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        operableFacet = create3Factory.deployOperableFacet();

        // Diamond facets
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
