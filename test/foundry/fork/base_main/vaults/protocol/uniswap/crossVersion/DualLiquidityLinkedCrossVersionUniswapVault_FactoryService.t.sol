// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice FactoryService helpers deploy facets and package through the registry.
contract DualLiquidityLinkedCrossVersionUniswapVault_FactoryService is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    using DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override {
        super.setUp();
    }

    function test_factoryService_deployExchangeFacets() public {
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.ExchangeFacets memory f =
            DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployExchangeFacets(create3Factory);
        assertTrue(address(f.exchangeInFacet) != address(0));
        assertTrue(address(f.exchangeInQueryFacet) != address(0));
        assertTrue(address(f.exchangeOutFacet) != address(0));
        assertTrue(address(f.exchangeOutQueryFacet) != address(0));
        assertTrue(bytes(f.exchangeInFacet.facetName()).length > 0);
    }

    function test_factoryService_pkgAlreadyDeployedInBase() public view {
        assertTrue(address(linkedVaultPkg) != address(0));
        assertEq(linkedVaultPkg.facetCuts().length, 9);
    }

    function test_factoryService_registryOnlyDeployPkg() public {
        address stranger = makeAddr("factoryStranger");
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.ExchangeFacets memory f =
            DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployExchangeFacets(create3Factory);

        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit = _pkgInit(f);

        vm.prank(stranger);
        vm.expectRevert();
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }

    function _pkgInit(
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.ExchangeFacets memory f
    ) internal view returns (IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit) {
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.exchangeInFacet = f.exchangeInFacet;
        pkgInit.exchangeInQueryFacet = f.exchangeInQueryFacet;
        pkgInit.exchangeOutFacet = f.exchangeOutFacet;
        pkgInit.exchangeOutQueryFacet = f.exchangeOutQueryFacet;
        pkgInit.feeOracle = _feeOracle();
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.balancerV3Router = seRouter;
        pkgInit.balancerV3Vault = vault;
        pkgInit.weightedPoolFactory = weightedPoolFactory;
        pkgInit.v4VaultPkg = v4VaultPkg;
        pkgInit.v2VaultPkg = v2VaultPkg;
        pkgInit.rateProviderPkg = rateProviderPkg;
        pkgInit.permit2 = permit2;
        pkgInit.diamondFactory = diamondPackageFactory;
    }
}
