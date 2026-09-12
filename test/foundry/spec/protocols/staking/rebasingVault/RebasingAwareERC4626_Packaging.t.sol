// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@crane/contracts/introspection/ERC165/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

contract RebasingAwareERC4626_Packaging is TestBase_RebasingAwareERC4626 {
    uint256 constant MAX_RUNTIME = 24_576;

    function test_PKG03_registeredPackageAndVault() public view {
        assertTrue(IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(pkg)));
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(address(vault)));
        address[] memory ofToken = IVaultRegistryVaultQuery(address(indexedexManager)).vaultsOfToken(address(asset));
        bool found;
        for (uint256 i; i < ofToken.length; ++i) {
            if (ofToken[i] == address(vault)) found = true;
        }
        assertTrue(found);
    }

    function test_PKG02_proxySelectors() public view {
        assertEq(vault.asset(), address(asset));
        assertEq(IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(asset)), 0, IERC20(address(vault))), 0);
        assertEq(IStandardizedYield(address(vault)).yieldToken(), address(asset));
        assertEq(IBasicVault(address(vault)).vaultTokens().length, 1);
        assertEq(IStandardVault(address(vault)).vaultFeeTypeIds(), bytes32(0));
        (bytes memory state,) = IStandardExchangeTransitionQuote(address(vault)).quoteState(address(asset), alice);
        assertEq(state.length, 288);
    }

    function test_PKG02_loupeDestinations() public view {
        bytes4[4] memory selectors = [
            IERC4626.deposit.selector,
            IStandardExchangeIn.exchangeIn.selector,
            IStandardizedYield.deposit.selector,
            IStandardExchangeTransitionQuote.quoteState.selector
        ];
        address[4] memory facets = [
            address(rebasingAwareErc4626Facet),
            address(standardExchangeFacet),
            address(standardYieldFacet),
            address(transitionQuoteFacet)
        ];
        for (uint256 i; i < selectors.length; ++i) {
            assertEq(IDiamondLoupe(address(vault)).facetAddress(selectors[i]), facets[i]);
        }
        assertEq(
            IDiamondLoupe(address(vault)).facetAddress(IERC20Metadata.name.selector),
            address(erc20Facet)
        );
    }

    function test_PKG02_erc165() public view {
        assertTrue(IERC165(address(vault)).supportsInterface(type(IERC4626).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeOut).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardizedYield).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardExchangeExternalQuote).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IBasicVault).interfaceId));
        assertTrue(IERC165(address(vault)).supportsInterface(type(IStandardVault).interfaceId));
    }

    function test_runtimeSizes() public view {
        assertLe(address(rebasingAwareErc4626Facet).code.length, MAX_RUNTIME);
        assertLe(address(standardExchangeFacet).code.length, MAX_RUNTIME);
        assertLe(address(standardYieldFacet).code.length, MAX_RUNTIME);
        assertLe(address(vaultMetadataFacet).code.length, MAX_RUNTIME);
        assertLe(address(transitionQuoteFacet).code.length, MAX_RUNTIME);
        assertLe(address(pkg).code.length, MAX_RUNTIME);
        assertLe(address(vault).code.length, MAX_RUNTIME);
    }

    function test_disableInboundLeavesExits() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(15e18, alice);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault))
        );
        vault.deposit(1e18, alice);
        vm.prank(alice);
        uint256 out = vault.redeem(shares / 2, alice, alice);
        assertGt(out, 0);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares / 4);
        vm.prank(alice);
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)),
            shares / 8,
            IERC20(address(asset)),
            0,
            alice,
            true,
            block.timestamp
        );
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares / 16);
        vm.prank(bob);
        IStandardizedYield(address(vault)).redeem(bob, shares / 16, address(asset), 0, true);
    }

    function test_releaseIdentifier() public view {
        assertEq(pkg.releaseIdentifier(), "indexedex.rebasing-aware-erc4626.sy-se.v1");
        assertEq(pkg.name(), "RebasingAwareERC4626");
        assertEq(pkg.vaultFeeTypeIds(), bytes32(0));
    }

    function test_create3ReplaySameAddress() public {
        vm.prank(owner);
        address again = address(
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
                indexedexManager, _pkgInit()
            )
        );
        assertEq(again, address(pkg));
    }

    function test_legacyErc4626StillWorksOnEnhancedDiamond() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(8e18, alice);
        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        assertGt(assets, 0);
    }

    function test_F13_feeOracleUpdateStillZeroWrapperFees() public {
        IVaultFeeOracleManager feeMgr = IVaultFeeOracleManager(address(indexedexManager));
        vm.prank(owner);
        feeMgr.setDefaultUsageFee(1e16);
        vm.prank(owner);
        feeMgr.setUsageFeeOfVault(address(vault), 1e16);
        uint256 collectorBefore = asset.balanceOf(address(feeCollector));
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        vm.prank(alice);
        uint256 shares = vault.deposit(10e18, alice);
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares);
        assertEq(asset.balanceOf(address(vault)), 10e18);
        assertEq(asset.balanceOf(address(feeCollector)), collectorBefore);
        assertEq(IStandardVault(address(vault)).vaultFeeTypeIds(), bytes32(0));
    }

    function test_PKG03_packageDisableBlocksInboundNotExit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(4e18, alice);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(pkg), true);
        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1e18, alice);
        vm.prank(alice);
        uint256 out = vault.redeem(shares, alice, alice);
        assertGt(out, 0);
    }

    function test_wrongFacetPkgCannotDeployVault() public {
        IRebasingAwareERC4626DFPkg.PkgInit memory bad = _pkgInit();
        bad.standardExchangeFacet = erc20Facet;
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg badPkg =
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
                indexedexManager, bad
            );
        vm.expectRevert();
        badPkg.deployVault(IERC20Metadata(address(asset)), 10, bytes32(uint256(77)));
    }
}
