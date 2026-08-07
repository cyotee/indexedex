// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Facet_FactoryService as FacetFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Facet_FactoryService.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Pkg_FactoryService as PkgFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Pkg_FactoryService.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @title UniswapV4StandardExchangeWeightedDETF_Component_FactoryService
/// @notice Typed deploy helpers for CREATE3 facets + manager-registry DFPkg.
library UniswapV4StandardExchangeWeightedDETF_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeWeightedDETFFacet(create3Factory);
    }

    function deployInfoFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeWeightedDETFInfoFacet(create3Factory);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeWeightedDETDFPkg pkg) {
        return PkgFS.deployUniswapV4StandardExchangeWeightedDETDFPkg(vaultRegistry_, pkgInit_);
    }
}
