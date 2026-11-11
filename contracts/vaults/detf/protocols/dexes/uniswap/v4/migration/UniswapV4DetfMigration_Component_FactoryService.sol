// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV4Detf_Facet_FactoryService} from "../detf/UniswapV4Detf_Facet_FactoryService.sol";

/// @notice Artifact-backed CREATE3 components. Names bind salt and artifact without implementation imports.
library UniswapV4DetfMigration_Component_FactoryService {
    Vm internal constant vm = Vm(VM_ADDRESS);

    function deployFacet(ICreate3FactoryProxy factory_, string memory name_) internal returns (IFacet facet_) {
        facet_ = factory_.deployFacet(
            ArtifactCreationCode.creationCode(factory_, string.concat(name_, ".sol:", name_)),
            ArtifactCreationCode.releaseSalt(keccak256(abi.encode(name_)))
        );
        vm.label(address(facet_), name_);
    }

    function deployParentFacets(ICreate3FactoryProxy factory_) internal returns (IFacet[5] memory facets_) {
        facets_[0] = deployFacet(factory_, "UniswapV4DetfMigrationExchangeFacet");
        facets_[1] = deployFacet(factory_, "UniswapV4DetfMigrationBondFacet");
        facets_[2] = deployFacet(factory_, "UniswapV4DetfMigrationMaintenanceFacet");
        facets_[3] = UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfClaimFacet(factory_);
        facets_[4] = deployFacet(factory_, "UniswapV4DetfMigrationQueryFacet");
    }
}
