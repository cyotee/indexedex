// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

/// @title Phase_06_Stage_02_RebasingClaimPkg
/// @notice Rebasing claim DFPkg + claim facet.
library Phase_06_Stage_02_RebasingClaimPkg {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
        IFacet claimFacet_ = s.create3Factory.deployRebasingClaimTokenFacet();
        s.rebasingClaimTokenPkg = address(
            s.create3Factory.deployRebasingClaimTokenDFPkg(
                DetfComponentFactoryService.buildRICHIRPkgInit(
                    s.erc20Facet, s.erc5267Facet, s.erc2612Facet, claimFacet_, s.diamondPackageFactory
                )
            )
        );
    }
}
