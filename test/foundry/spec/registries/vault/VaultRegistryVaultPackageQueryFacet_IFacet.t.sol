// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {VaultRegistryVaultPackageQueryFacet} from "contracts/registries/vault/VaultRegistryVaultPackageQueryFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultRegistryVaultPackageQueryFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for package query surface.
 */
contract VaultRegistryVaultPackageQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultRegistryVaultPackageQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultRegistryVaultPackageQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultRegistryVaultPackageQuery).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](10);
        controlFuncs[0] = IVaultRegistryVaultPackageQuery.vaultPackages.selector;
        controlFuncs[1] = IVaultRegistryVaultPackageQuery.isPackage.selector;
        controlFuncs[2] = IVaultRegistryVaultPackageQuery.vaultTypeIds.selector;
        controlFuncs[3] = IVaultRegistryVaultPackageQuery.vaultUsageFeeTypeIds.selector;
        controlFuncs[4] = IVaultRegistryVaultPackageQuery.vaultDexFeeTypeIds.selector;
        controlFuncs[5] = IVaultRegistryVaultPackageQuery.vaultBondFeeTypeIds.selector;
        controlFuncs[6] = IVaultRegistryVaultPackageQuery.vaultLendingFeeTypeIds.selector;
        controlFuncs[7] = IVaultRegistryVaultPackageQuery.packageName.selector;
        controlFuncs[8] = IVaultRegistryVaultPackageQuery.packageFeeTypeIds.selector;
        controlFuncs[9] = IVaultRegistryVaultPackageQuery.packagesOfTypeId.selector;
    }
}
