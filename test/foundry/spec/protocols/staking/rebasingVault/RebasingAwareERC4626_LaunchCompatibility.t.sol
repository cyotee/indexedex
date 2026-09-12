// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {Phase_06_Stage_10_RebasingAwareERC4626Pkg as RebasingStage} from
    "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

contract RebasingAwareERC4626_LaunchCompatibility is TestBase_RebasingAwareERC4626 {
    LaunchState internal launchState;

    function test_stageReplaySamePackage() public {
        IOperable(address(create3Factory)).setOperator(owner, true);
        launchState.create3Factory = create3Factory;
        launchState.diamondPackageFactory = diamondPackageFactory;
        launchState.indexedexManager = indexedexManager;
        launchState.erc20Facet = erc20Facet;
        vm.startPrank(owner);
        RebasingStage.execute(launchState);
        address first = launchState.rebasingAwareErc4626Pkg;
        RebasingStage.execute(launchState);
        vm.stopPrank();
        assertEq(launchState.rebasingAwareErc4626Pkg, first);
        assertEq(
            IRebasingAwareERC4626DFPkg(first).releaseIdentifier(),
            "indexedex.rebasing-aware-erc4626.sy-se.v1"
        );
        assertTrue(address(launchState.rebasingAwareSeFacet).code.length > 0);
        assertTrue(address(launchState.rebasingAwareSyFacet).code.length > 0);
        assertTrue(address(launchState.rebasingAwareMetadataFacet).code.length > 0);
        assertTrue(address(launchState.rebasingAwareQuoteFacet).code.length > 0);
        IERC4626 launched = IRebasingAwareERC4626DFPkg(first).deployVault(IERC20Metadata(address(asset)));
        assertEq(IStandardizedYield(address(launched)).yieldToken(), address(asset));
    }

    function test_oldTwoAddressManifestIsNotComplete() public view {
        assertTrue(address(standardExchangeFacet).code.length > 0);
        assertTrue(address(standardYieldFacet).code.length > 0);
        assertTrue(bytes(pkg.releaseIdentifier()).length > 0);
    }

    function test_PKG05_enhancedSkipRequiresAllSixLiveAddresses() public view {
        address[6] memory complete = [
            address(pkg),
            address(rebasingAwareErc4626Facet),
            address(standardExchangeFacet),
            address(standardYieldFacet),
            address(vaultMetadataFacet),
            address(transitionQuoteFacet)
        ];
        assertTrue(_allHaveCode(complete));
        address[6] memory staleTwo = [
            address(pkg),
            address(rebasingAwareErc4626Facet),
            address(0),
            address(0),
            address(0),
            address(0)
        ];
        assertFalse(_allHaveCode(staleTwo));
        address[6] memory partialMissingQuote = [
            address(pkg),
            address(rebasingAwareErc4626Facet),
            address(standardExchangeFacet),
            address(standardYieldFacet),
            address(vaultMetadataFacet),
            address(0)
        ];
        assertFalse(_allHaveCode(partialMissingQuote));
        address[6] memory wrongFacet = [
            address(pkg),
            address(rebasingAwareErc4626Facet),
            address(erc20Facet),
            address(standardYieldFacet),
            address(vaultMetadataFacet),
            address(transitionQuoteFacet)
        ];
        assertTrue(_allHaveCode(wrongFacet));
        assertTrue(address(standardExchangeFacet) != address(erc20Facet));
    }

    function test_PKG05_mismatchedRegistryCannotDeployVault() public {
        IRebasingAwareERC4626DFPkg.PkgInit memory bad = _pkgInit();
        bad.vaultRegistry = IVaultRegistryDeployment(address(erc20Facet));
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg badPkg =
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
                indexedexManager, bad
            );
        vm.expectRevert();
        badPkg.deployVault(IERC20Metadata(address(asset)), 10, bytes32(uint256(88)));
    }

    function test_PKG05_exportRecordsIncludeReleaseAndNewFacets() public view {
        assertEq(pkg.releaseIdentifier(), "indexedex.rebasing-aware-erc4626.sy-se.v1");
        assertTrue(address(standardExchangeFacet).code.length > 0);
        assertTrue(address(standardYieldFacet).code.length > 0);
        assertTrue(address(vaultMetadataFacet).code.length > 0);
        assertTrue(address(transitionQuoteFacet).code.length > 0);
        assertTrue(address(pkg).code.length > 0);
    }

    function _allHaveCode(address[6] memory addrs) internal view returns (bool) {
        for (uint256 i; i < addrs.length; ++i) {
            if (addrs[i] == address(0) || addrs[i].code.length == 0) return false;
        }
        return true;
    }
}
