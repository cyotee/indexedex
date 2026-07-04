// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Verifies the Vault-Registry-only deployment contract of the package using the real
///         production package from TestBase (no makeAddr protocol fakes). Covers registry enforcement
///         and package metadata; end-to-end registration of the vault instance is covered by
///         ProductionDeploy.
contract DualLiquidityLinkedCrossVersionUniswapVaultDFPkg_Registry is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal stranger = makeAddr("stranger");

    /* --------------------- Registry-only deployment ----------------------- */

    function test_processArgs_revertsForNonRegistryCaller() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.NotCalledByRegistry.selector, stranger
            )
        );
        linkedVaultPkg.processArgs("");
    }

    function test_processArgs_passesForRegistry() public {
        // The Vault Registry is the Indexedex manager in production wiring.
        vm.prank(address(indexedexManager));
        bytes memory out = linkedVaultPkg.processArgs(hex"1234");
        assertEq(out, hex"1234", "registry call returns args unchanged");
    }

    /* ---------------------- IStandardVaultPkg surface --------------------- */

    function test_vaultDeclaration_isCorrect() public view {
        IStandardVaultPkg.VaultPkgDeclaration memory decl = linkedVaultPkg.vaultDeclaration();
        assertEq(decl.name, linkedVaultPkg.packageName(), "declaration name == package name");
        assertEq(decl.name, "DualLiquidityLinkedCrossVersionUniswapVaultDFPkg", "package name");
        assertTrue(decl.vaultFeeTypeIds != bytes32(0), "usage fee type registered");
        assertEq(decl.vaultTypes.length, 8, "vault types == facet interfaces");
    }

    function test_vaultTypes_matchFacetInterfaces() public view {
        bytes4[] memory types_ = linkedVaultPkg.vaultTypes();
        bytes4[] memory ifaces_ = linkedVaultPkg.facetInterfaces();
        assertEq(types_.length, ifaces_.length, "vaultTypes == facetInterfaces length");
        for (uint256 i = 0; i < types_.length; i++) {
            assertEq(types_[i], ifaces_[i], "type matches interface");
        }
    }

    /* ------------------------- Facet configuration ------------------------ */

    function test_facetCuts_installsNineFacets_noDiamondCut() public view {
        IDiamond.FacetCut[] memory cuts = linkedVaultPkg.facetCuts();
        assertEq(cuts.length, 9, "9 facets: erc20 + erc5267 + erc2612 + 2 vault + 4 exchange");
        assertEq(linkedVaultPkg.facetInterfaces().length, 8, "8 advertised interfaces");

        // Immutability: no facet exposes the diamondCut selector (0x1f931c1c).
        for (uint256 i = 0; i < cuts.length; i++) {
            for (uint256 j = 0; j < cuts[i].functionSelectors.length; j++) {
                assertTrue(cuts[i].functionSelectors[j] != bytes4(0x1f931c1c), "no diamondCut selector");
            }
        }
    }
}
