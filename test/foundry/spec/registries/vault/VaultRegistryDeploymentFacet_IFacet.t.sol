// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultRegistryDeploymentFacet} from "contracts/registries/vault/VaultRegistryDeploymentFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultRegistryDeploymentFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for vault/package/hook deployment entrypoints.
 */
contract VaultRegistryDeploymentFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultRegistryDeploymentFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultRegistryDeploymentFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultRegistryDeployment).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](5);
        controlFuncs[0] = IVaultRegistryDeployment.deployPkg.selector;
        controlFuncs[1] = IVaultRegistryDeployment.deployVault.selector;
        controlFuncs[2] = IVaultRegistryDeployment.deployHookVault.selector;
        controlFuncs[3] = IVaultRegistryDeployment.deployHookVaultAutoMine.selector;
        controlFuncs[4] = IVaultRegistryDeployment.setHookDiamondPackageFactory.selector;
    }
}
