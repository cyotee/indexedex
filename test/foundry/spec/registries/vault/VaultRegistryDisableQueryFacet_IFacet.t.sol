// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {VaultRegistryDisableQueryFacet} from "contracts/registries/vault/VaultRegistryDisableQueryFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultRegistryDisableQueryFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for registry kill-switch reads.
 */
contract VaultRegistryDisableQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultRegistryDisableQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultRegistryDisableQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultRegistryDisableQuery).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](7);
        controlFuncs[0] = IVaultRegistryDisableQuery.isDisabled.selector;
        controlFuncs[1] = IVaultRegistryDisableQuery.isDisabledDetailed.selector;
        controlFuncs[2] = IVaultRegistryDisableQuery.isVaultAddressDisabled.selector;
        controlFuncs[3] = IVaultRegistryDisableQuery.isPackageDisabled.selector;
        controlFuncs[4] = IVaultRegistryDisableQuery.packageOfVault.selector;
        controlFuncs[5] = IVaultRegistryDisableQuery.disabledVaults.selector;
        controlFuncs[6] = IVaultRegistryDisableQuery.disabledPackages.selector;
    }
}
