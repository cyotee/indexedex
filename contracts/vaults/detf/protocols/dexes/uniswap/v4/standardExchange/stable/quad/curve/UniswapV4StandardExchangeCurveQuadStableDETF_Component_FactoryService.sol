// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETF_Facet_FactoryService as FacetFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Facet_FactoryService.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETF_Pkg_FactoryService as PkgFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Pkg_FactoryService.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService
/// @notice Typed deploy helpers for CREATE3 facets + manager-registry DFPkg.
library UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeCurveQuadStableDETFExchangeFacet(create3Factory);
    }

    function deployBondingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeCurveQuadStableDETFFacet(create3Factory);
    }

    function deployCompoundFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeCurveQuadStableDETFCompoundFacet(create3Factory);
    }

    function deployInfoFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4StandardExchangeCurveQuadStableDETFInfoFacet(create3Factory);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg pkg) {
        return PkgFS.deployUniswapV4StandardExchangeCurveQuadStableDETDFPkg(vaultRegistry_, pkgInit_);
    }
}
