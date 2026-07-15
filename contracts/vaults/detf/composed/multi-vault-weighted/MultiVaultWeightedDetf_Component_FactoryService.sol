// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    MultiVaultWeightedDetf_Facet_FactoryService
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Facet_FactoryService.sol";
import {
    MultiVaultWeightedDetf_Pkg_FactoryService
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Pkg_FactoryService.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";

library MultiVaultWeightedDetf_Component_FactoryService {
    function deployExchangeInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet facet_) {
        facet_ = MultiVaultWeightedDetf_Facet_FactoryService.deployMultiVaultWeightedDetfExchangeInFacet(factory_);
    }

    function deployPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IMultiVaultWeightedDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IMultiVaultWeightedDetfDFPkg instance_) {
        instance_ = MultiVaultWeightedDetf_Pkg_FactoryService.deployMultiVaultWeightedDetfDFPkg(vaultRegistry_, pkgInit_);
    }
}
