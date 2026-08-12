// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    SingleStandardExchangeDETF_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Facet_FactoryService.sol";
import {
    SingleStandardExchangeDETF_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Pkg_FactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";

library SingleStandardExchangeDETF_Component_FactoryService {
    using SingleStandardExchangeDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Pkg_FactoryService for IVaultRegistryDeployment;

    function deployExchangeInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet facet_) {
        facet_ = factory_.deploySingleStandardExchangeDETFExchangeInFacet();
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (ISingleStandardExchangeDETDFPkg instance_) {
        instance_ = vaultRegistry_.deploySingleStandardExchangeDETDFPkg(pkgInit_);
    }
}
