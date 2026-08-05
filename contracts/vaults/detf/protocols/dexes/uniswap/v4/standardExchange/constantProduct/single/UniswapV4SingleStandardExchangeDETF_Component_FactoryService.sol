// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Facet_FactoryService as FacetFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Facet_FactoryService.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Pkg_FactoryService as PkgFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Pkg_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @title UniswapV4SingleStandardExchangeDETF_Component_FactoryService
/// @notice Typed deploy helpers for CREATE3 facets + manager-registry DFPkg.
library UniswapV4SingleStandardExchangeDETF_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return FacetFS.deployUniswapV4SingleStandardExchangeDETFFacet(create3Factory);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4SingleStandardExchangeDETDFPkg pkg) {
        return PkgFS.deployUniswapV4SingleStandardExchangeDETDFPkg(vaultRegistry_, pkgInit_);
    }
}
