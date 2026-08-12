// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {
    VaultRegistryVaultPackageManagerFacet
} from "contracts/registries/vault/VaultRegistryVaultPackageManagerFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultRegistryVaultPackageManagerFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for package register/unregister.
 */
contract VaultRegistryVaultPackageManagerFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultRegistryVaultPackageManagerFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultRegistryVaultPackageManagerFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultRegistryVaultPackageManager).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](2);
        controlFuncs[0] = IVaultRegistryVaultPackageManager.registerPackage.selector;
        controlFuncs[1] = IVaultRegistryVaultPackageManager.unregisterPackage.selector;
    }
}
