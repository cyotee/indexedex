// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    MixedBufferMultiVaultStableDetf_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Facet_FactoryService.sol";
import {
    MixedBufferMultiVaultStableDetf_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Pkg_FactoryService.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";

library MixedBufferMultiVaultStableDetf_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet facet_) {
        facet_ = MixedBufferMultiVaultStableDetf_Facet_FactoryService
            .deployMixedBufferMultiVaultStableDetfExchangeInFacet(factory_);
    }

    function deployBondingFacet(ICreate3FactoryProxy factory_) internal returns (IFacet facet_) {
        facet_ = MixedBufferMultiVaultStableDetf_Facet_FactoryService
            .deployMixedBufferMultiVaultStableDetfBondingFacet(factory_);
    }

    function deployInfoFacet(ICreate3FactoryProxy factory_) internal returns (IFacet facet_) {
        facet_ = MixedBufferMultiVaultStableDetf_Facet_FactoryService
            .deployMixedBufferMultiVaultStableDetfInfoFacet(factory_);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IMixedBufferMultiVaultStableDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IMixedBufferMultiVaultStableDetfDFPkg instance_) {
        instance_ = MixedBufferMultiVaultStableDetf_Pkg_FactoryService.deployMixedBufferMultiVaultStableDetfDFPkg(
            vaultRegistry_, pkgInit_
        );
    }
}
