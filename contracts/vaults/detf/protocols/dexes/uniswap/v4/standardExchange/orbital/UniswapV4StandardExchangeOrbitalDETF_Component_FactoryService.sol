// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Facet_FactoryService as FacetFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Facet_FactoryService.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Pkg_FactoryService as PkgFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Pkg_FactoryService.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService
/// @notice Typed deploy helpers for CREATE3 facets + manager-registry DFPkg.
library UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeOrbitalDETFFacet(create3Factory);
    }

    function deployInfoFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeOrbitalDETFInfoFacet(create3Factory);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeOrbitalDETDFPkg pkg) {
        return PkgFS.deployUniswapV4StandardExchangeOrbitalDETDFPkg(vaultRegistry_, pkgInit_);
    }
}
