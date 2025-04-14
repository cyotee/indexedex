// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/**
 * @title VaultRegistryPackage_Registration_Test
 * @notice US-IDXEX-038.2: Tests documenting package registration/unregistration behavior.
 * @dev These tests call registerPackage/unregisterPackage directly on the IndexedexManager
 *      Diamond proxy with synthetic VaultPkgDeclaration data.
 *
 *      Key behaviors documented:
 *      - registerPackage adds to packages, pkgNames, pkgFeeTypeIds, vaultTypeIds, pkgsOfType, fee-type sets
 *      - unregisterPackage removes from packages, clears pkgNames and pkgFeeTypeIds
 *      - unregisterPackage does NOT remove from pkgsOfType (stale entries remain)
 *      - unregisterPackage does NOT remove from vaultTypeIds or fee-type-id sets
 */
contract VaultRegistryPackage_Registration_Test is IndexedexTest {
    IVaultRegistryVaultPackageManager pkgManager;
    IVaultRegistryVaultPackageQuery pkgQuery;

    address pkg1;
    address pkg2;

    // Mock vault type IDs.
    bytes4 constant TYPE_DEX = bytes4(0xdeadbeef);
    bytes4 constant TYPE_LENDING = bytes4(0xcafebabe);
    bytes4 constant TYPE_BOND = bytes4(0x12345678);

    // Packed fee type IDs: [usage:4][dex:4][bond:4][seigniorage:4][lending:4][padding:12]
    bytes32 constant PKG_FEE_TYPE_IDS = bytes32(
        abi.encodePacked(
            bytes4(0xaaaa1111), // usage
            bytes4(0xbbbb2222), // dex
            bytes4(0xcccc3333), // bond
            bytes4(0xdddd4444), // seigniorage
            bytes4(0xeeee5555), // lending
            bytes12(0)
        )
    );

    IStandardVaultPkg.VaultPkgDeclaration dec1;

    function setUp() public virtual override {
        super.setUp();

        pkgManager = IVaultRegistryVaultPackageManager(address(indexedexManager));
        pkgQuery = IVaultRegistryVaultPackageQuery(address(indexedexManager));

        pkg1 = makeAddr("pkg1");
        pkg2 = makeAddr("pkg2");

        // Build declaration with 2 vault types.
        bytes4[] memory types = new bytes4[](2);
        types[0] = TYPE_DEX;
        types[1] = TYPE_LENDING;

        dec1 = IStandardVaultPkg.VaultPkgDeclaration({
            name: "TestPackage", vaultFeeTypeIds: PKG_FEE_TYPE_IDS, vaultTypes: types
        });
    }

    /* ---------------------------------------------------------------------- */
    /*             registerPackage: Adds to All Relevant Indexes              */
    /* ---------------------------------------------------------------------- */

    /// @notice registerPackage adds to packages set.
    function test_registerPackage_addsToPackagesSet() public {
        assertEq(pkgQuery.vaultPackages().length, 0, "packages should start empty");

        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        address[] memory pkgs = pkgQuery.vaultPackages();
        assertEq(pkgs.length, 1, "packages should have 1");
        assertEq(pkgs[0], pkg1);
        assertTrue(pkgQuery.isPackage(pkg1), "isPackage should return true");
    }

    /// @notice registerPackage stores the package name.
    function test_registerPackage_storesPkgName() public {
        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        assertEq(pkgQuery.packageName(pkg1), "TestPackage", "package name should match");
    }

    /// @notice registerPackage stores packed fee type IDs for the package.
    function test_registerPackage_storesFeeTypeIds() public {
        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        assertEq(pkgQuery.packageFeeTypeIds(pkg1), PKG_FEE_TYPE_IDS, "fee type IDs should match");
    }

    /// @notice registerPackage adds each vault type to the global vaultTypeIds set.
    function test_registerPackage_addsToVaultTypeIds() public {
        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        bytes4[] memory typeIds = pkgQuery.vaultTypeIds();
        assertEq(typeIds.length, 2, "vaultTypeIds should have 2");
    }

    /// @notice registerPackage adds to pkgsOfType for each vault type.
    function test_registerPackage_addsToPkgsOfType() public {
        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        address[] memory dexPkgs = pkgQuery.packagesOfTypeId(TYPE_DEX);
        address[] memory lendingPkgs = pkgQuery.packagesOfTypeId(TYPE_LENDING);
        assertEq(dexPkgs.length, 1, "pkgsOfType(DEX) should have 1");
        assertEq(dexPkgs[0], pkg1);
        assertEq(lendingPkgs.length, 1, "pkgsOfType(LENDING) should have 1");
        assertEq(lendingPkgs[0], pkg1);
    }

    /// @notice registerPackage adds fee type IDs to the per-category fee type sets.
    function test_registerPackage_addsFeeTypeSets() public {
        vm.prank(owner);
        pkgManager.registerPackage(pkg1, dec1);

        bytes4[] memory usageFees = pkgQuery.vaultUsageFeeTypeIds();
        bytes4[] memory dexFees = pkgQuery.vaultDexFeeTypeIds();
        bytes4[] memory bondFees = pkgQuery.vaultBondFeeTypeIds();
        bytes4[] memory lendingFees = pkgQuery.vaultLendingFeeTypeIds();

        assertEq(usageFees.length, 1, "usageFeeTypeIds should have 1");
        assertEq(usageFees[0], bytes4(0xaaaa1111));
        assertEq(dexFees.length, 1, "dexFeeTypeIds should have 1");
        assertEq(bondFees.length, 1, "bondFeeTypeIds should have 1");
        assertEq(lendingFees.length, 1, "lendingFeeTypeIds should have 1");
    }

    /// @notice registerPackage emits NewPackage and NewPackageOfType events.
    function test_registerPackage_emitsEvents() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVaultRegistryEvents.NewPackage(pkg1, "TestPackage", PKG_FEE_TYPE_IDS, dec1.vaultTypes);
        pkgManager.registerPackage(pkg1, dec1);
    }

    /* ---------------------------------------------------------------------- */
    /*          unregisterPackage: Removes from packages, clears names        */
    /* ---------------------------------------------------------------------- */

    /// @notice unregisterPackage removes from packages set.
    function test_unregisterPackage_removesFromPackagesSet() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        assertEq(pkgQuery.vaultPackages().length, 0, "packages should be empty");
        assertFalse(pkgQuery.isPackage(pkg1), "isPackage should return false");
    }

    /// @notice unregisterPackage clears the package name.
    function test_unregisterPackage_clearsPkgName() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        assertEq(pkgQuery.packageName(pkg1), "", "package name should be empty");
    }

    /// @notice unregisterPackage clears the packed fee type IDs.
    function test_unregisterPackage_clearsFeeTypeIds() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        assertEq(pkgQuery.packageFeeTypeIds(pkg1), bytes32(0), "fee type IDs should be cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*    unregisterPackage: Does NOT Remove from Append-Only Indexes         */
    /*    (Documents current behavior - these sets grow monotonically)         */
    /* ---------------------------------------------------------------------- */

    /// @notice BEHAVIOR: pkgsOfType is append-only. unregisterPackage does NOT remove from pkgsOfType.
    /// @dev This means packagesOfTypeId() will return stale package addresses after unregistration.
    ///      Callers should verify isPackage() for each result to filter out unregistered packages.
    function test_unregisterPackage_doesNotRemoveFromPkgsOfType() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        // pkgsOfType still contains pkg1 even though it was unregistered.
        address[] memory dexPkgs = pkgQuery.packagesOfTypeId(TYPE_DEX);
        assertEq(dexPkgs.length, 1, "pkgsOfType should still contain stale entry");
        assertEq(dexPkgs[0], pkg1, "stale pkg1 should remain in pkgsOfType");

        // But isPackage returns false.
        assertFalse(pkgQuery.isPackage(pkg1), "isPackage should return false despite stale pkgsOfType entry");
    }

    /// @notice BEHAVIOR: vaultTypeIds is append-only. unregisterPackage does NOT remove type IDs.
    /// @dev Type IDs added during registration persist even after the package is removed.
    function test_unregisterPackage_doesNotRemoveFromVaultTypeIds() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        bytes4[] memory typeIds = pkgQuery.vaultTypeIds();
        assertEq(typeIds.length, 2, "vaultTypeIds should still have 2 entries (append-only)");
    }

    /// @notice BEHAVIOR: Fee type ID sets are append-only. unregisterPackage does NOT remove fee type IDs.
    /// @dev usageVaultTypeIds, dexVaultTypeIds, bondVaultTypeIds, lendingVaultTypeIds all retain entries.
    function test_unregisterPackage_doesNotRemoveFromFeeTypeSets() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        assertEq(pkgQuery.vaultUsageFeeTypeIds().length, 1, "usage fee set should retain entry");
        assertEq(pkgQuery.vaultDexFeeTypeIds().length, 1, "dex fee set should retain entry");
        assertEq(pkgQuery.vaultBondFeeTypeIds().length, 1, "bond fee set should retain entry");
        assertEq(pkgQuery.vaultLendingFeeTypeIds().length, 1, "lending fee set should retain entry");
    }

    /* ---------------------------------------------------------------------- */
    /*                   Idempotence and Edge Cases                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Repeated registration of the same package is idempotent for sets.
    function test_registerPackage_repeated_isIdempotent() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.registerPackage(pkg1, dec1);
        vm.stopPrank();

        assertEq(pkgQuery.vaultPackages().length, 1, "repeated add should not duplicate");
        assertEq(pkgQuery.packagesOfTypeId(TYPE_DEX).length, 1, "repeated add should not duplicate in pkgsOfType");
    }

    /// @notice Unregistering a non-existent package is a no-op.
    function test_unregisterPackage_nonExistent_isNoOp() public {
        vm.prank(owner);
        pkgManager.unregisterPackage(pkg1);

        assertEq(pkgQuery.vaultPackages().length, 0, "packages should remain empty");
    }

    /// @notice Register two packages, unregister one - the other remains intact.
    function test_unregisterPackage_doesNotAffectOtherPackages() public {
        bytes4[] memory types2 = new bytes4[](1);
        types2[0] = TYPE_BOND;

        IStandardVaultPkg.VaultPkgDeclaration memory dec2 = IStandardVaultPkg.VaultPkgDeclaration({
            name: "Package2", vaultFeeTypeIds: PKG_FEE_TYPE_IDS, vaultTypes: types2
        });

        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.registerPackage(pkg2, dec2);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        assertEq(pkgQuery.vaultPackages().length, 1, "one package should remain");
        assertTrue(pkgQuery.isPackage(pkg2), "pkg2 should still be registered");
        assertFalse(pkgQuery.isPackage(pkg1), "pkg1 should be unregistered");
        assertEq(pkgQuery.packageName(pkg2), "Package2", "pkg2 name should remain");
    }

    /// @notice packagesOfTypeId returns stale entries after unregister.
    /// @dev Callers must cross-check with isPackage() to filter stale results.
    function test_packagesOfTypeId_afterUnregister_containsStaleEntry() public {
        vm.startPrank(owner);
        pkgManager.registerPackage(pkg1, dec1);
        pkgManager.unregisterPackage(pkg1);
        vm.stopPrank();

        address[] memory dexPkgs = pkgQuery.packagesOfTypeId(TYPE_DEX);
        assertEq(dexPkgs.length, 1, "packagesOfTypeId should return stale entry");

        // Demonstrate the recommended pattern: filter by isPackage.
        uint256 activeCount = 0;
        for (uint256 i; i < dexPkgs.length; i++) {
            if (pkgQuery.isPackage(dexPkgs[i])) {
                activeCount++;
            }
        }
        assertEq(activeCount, 0, "no active packages should remain after filtering");
    }
}
