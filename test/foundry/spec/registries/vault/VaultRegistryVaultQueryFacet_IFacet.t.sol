// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {VaultRegistryVaultQueryFacet} from "contracts/registries/vault/VaultRegistryVaultQueryFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultRegistryVaultQueryFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for vault query (includes vaultSeigniorageTermsTypeId).
 */
contract VaultRegistryVaultQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultRegistryVaultQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultRegistryVaultQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultRegistryVaultQuery).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](22);
        controlFuncs[0] = IVaultRegistryVaultQuery.vaults.selector;
        controlFuncs[1] = IVaultRegistryVaultQuery.isVault.selector;
        controlFuncs[2] = IVaultRegistryVaultQuery.vaultTokens.selector;
        controlFuncs[3] = IVaultRegistryVaultQuery.isContainedToken.selector;
        controlFuncs[4] = IVaultRegistryVaultQuery.vaultsOfToken.selector;
        controlFuncs[5] = IVaultRegistryVaultQuery.vaultsOfTokens.selector;
        controlFuncs[6] = IVaultRegistryVaultQuery.calcContentsId.selector;
        controlFuncs[7] = IVaultRegistryVaultQuery.contentsIds.selector;
        controlFuncs[8] = IVaultRegistryVaultQuery.vaultsOfContentsId.selector;
        controlFuncs[9] = IVaultRegistryVaultQuery.vaultsOfType.selector;
        controlFuncs[10] = IVaultRegistryVaultQuery.vaultsOfTypeOfToken.selector;
        controlFuncs[11] = IVaultRegistryVaultQuery.vaultsOfTypeOfTokens.selector;
        controlFuncs[12] = IVaultRegistryVaultQuery.vaultsOfTypeOfContentsId.selector;
        controlFuncs[13] = IVaultRegistryVaultQuery.vaultsOfPackage.selector;
        controlFuncs[14] = IVaultRegistryVaultQuery.vaultsOfPkgOfToken.selector;
        controlFuncs[15] = IVaultRegistryVaultQuery.vaultsOfPkgOfTokens.selector;
        controlFuncs[16] = IVaultRegistryVaultQuery.vaultsOfPkgOfContentsId.selector;
        controlFuncs[17] = IVaultRegistryVaultQuery.vaultUsageFeeTypeId.selector;
        controlFuncs[18] = IVaultRegistryVaultQuery.vaultDexTermsTypeId.selector;
        controlFuncs[19] = IVaultRegistryVaultQuery.vaultBondTermsTypeId.selector;
        controlFuncs[20] = IVaultRegistryVaultQuery.vaultSeigniorageTermsTypeId.selector;
        controlFuncs[21] = IVaultRegistryVaultQuery.vaultLendingTermsTypeId.selector;
    }
}
