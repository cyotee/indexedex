// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_ComposedFundedRoutes} from "contracts/test/bases/TestBase_ComposedFundedRoutes.sol";
import {
    ComposedStableCommonDetfRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    IComposedStableCommonDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol";

contract ComposedStableCommonDetfDFPkg_Deploy_Test is TestBase_ComposedFundedRoutes {
    function test_packageMetadata_matchesExpectedFacets() public view {
        (, bytes4[] memory interfaces_, address[] memory facets_) = composedPkg.packageMetadata();
        assertEq(interfaces_.length, 9);
        assertEq(facets_.length, 9);
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertGt(facets_[i_].code.length, 0);
            bytes4[] memory selectors_ = IFacet(facets_[i_]).facetFuncs();
            for (uint256 j_; j_ < selectors_.length; ++j_) {
                assertEq(IDiamondLoupe(composedDetf).facetAddress(selectors_[j_]), facets_[i_]);
            }
        }
    }

    function test_deployVault_initializesReservePoolReference() public view {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(composedDetf));
        assertEq(IERC20Metadata(composedDetf).decimals(), 9);
        assertEq(_bondNft().detf(), composedDetf);
        assertEq(address(_bondNft().lpToken()), composedInfo.reservePool());
        assertEq(_staked().detf(), composedDetf);
        assertFalse(composedInfo.isReserveLive());
    }

    function test_deployVault_rejectsMissingOpeningConfiguration() public {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_ = _composedArgs(0, 0, 0);
        args_.openingDetfPrices[0] = 0;
        vm.prank(owner);
        vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector);
        composedPkg.deployVault(args_);
        args_.openingDetfPrices[0] = 1e18;
        args_.reserveSeedAmounts[1] = 0;
        vm.prank(owner);
        vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector);
        composedPkg.deployVault(args_);
    }
}
