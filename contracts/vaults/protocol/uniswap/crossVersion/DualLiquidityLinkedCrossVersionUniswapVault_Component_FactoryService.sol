// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService.sol";

/// @notice Composite factory helpers: deploy all four exchange facets + the DFPkg via the registry.
library DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService {
    using DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService for ICreate3FactoryProxy;
    using DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService for IVaultRegistryDeployment;

    struct ExchangeFacets {
        IFacet exchangeInFacet;
        IFacet exchangeInQueryFacet;
        IFacet exchangeOutFacet;
        IFacet exchangeOutQueryFacet;
    }

    function deployExchangeFacets(ICreate3FactoryProxy create3Factory)
        internal
        returns (ExchangeFacets memory facets_)
    {
        facets_.exchangeInFacet = create3Factory.deployExchangeInFacet();
        facets_.exchangeInQueryFacet = create3Factory.deployExchangeInQueryFacet();
        facets_.exchangeOutFacet = create3Factory.deployExchangeOutFacet();
        facets_.exchangeOutQueryFacet = create3Factory.deployExchangeOutQueryFacet();
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg instance) {
        instance = vaultRegistry.deployDualLiquidityLinkedCrossVersionUniswapVaultDFPkg(pkgInit);
    }

    /// @notice Fills exchange facet slots on `pkgInit` from a fresh facet deploy, then deploys the package.
    function deployFacetsAndPkg(
        ICreate3FactoryProxy create3Factory,
        IVaultRegistryDeployment vaultRegistry,
        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg instance, ExchangeFacets memory facets_) {
        facets_ = deployExchangeFacets(create3Factory);
        pkgInit.exchangeInFacet = facets_.exchangeInFacet;
        pkgInit.exchangeInQueryFacet = facets_.exchangeInQueryFacet;
        pkgInit.exchangeOutFacet = facets_.exchangeOutFacet;
        pkgInit.exchangeOutQueryFacet = facets_.exchangeOutQueryFacet;
        instance = deployPkg(vaultRegistry, pkgInit);
    }
}
