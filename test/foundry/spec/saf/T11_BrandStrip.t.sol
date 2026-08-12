// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";

/// @notice T11 / L-NAME-1: role-safe factory helper exists (buildRebasingClaimTokenPkgInit).
contract T11_BrandStrip_Test is Test {
    function test_buildRebasingClaimTokenPkgInit_exists() public pure {
        IRebasingClaimTokenDFPkg.PkgInit memory init = DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
            IFacet(address(1)),
            IFacet(address(2)),
            IFacet(address(3)),
            IFacet(address(4)),
            IDiamondPackageCallBackFactory(address(5))
        );
        assertEq(address(init.erc20Facet), address(1));
        assertEq(address(init.rebasingClaimTokenFacet), address(4));
    }

    function test_legacyAlias_stillWorks() public pure {
        IRebasingClaimTokenDFPkg.PkgInit memory init = DetfComponentFactoryService.buildRICHIRPkgInit(
            IFacet(address(1)),
            IFacet(address(2)),
            IFacet(address(3)),
            IFacet(address(4)),
            IDiamondPackageCallBackFactory(address(5))
        );
        assertEq(address(init.diamondFactory), address(5));
    }
}
