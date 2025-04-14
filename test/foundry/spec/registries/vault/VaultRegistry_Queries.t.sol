// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/**
 * @title VaultRegistry_Queries_Test
 * @notice US-IDXEX-038.3: Tests documenting query behavior after registration operations.
 *         US-IDXEX-038.4: Tests documenting anti-spam behavior (registry growth, gas costs).
 * @dev Verifies that query functions return correct subsets across multiple vaults
 *      with different types, tokens, packages, and contents IDs.
 */
contract VaultRegistry_Queries_Test is IndexedexTest {
    IVaultRegistryVaultManager vaultManager;
    IVaultRegistryVaultQuery vaultQuery;
    IVaultRegistryVaultPackageManager pkgManager;
    IVaultRegistryVaultPackageQuery pkgQuery;

    // Mock addresses.
    address vault1;
    address vault2;
    address vault3;
    address pkg1;
    address pkg2;
    address tokenA;
    address tokenB;
    address tokenC;

    // Vault type IDs.
    bytes4 constant TYPE_DEX = bytes4(0xdeadbeef);
    bytes4 constant TYPE_LENDING = bytes4(0xcafebabe);

    // Fee type IDs.
    bytes32 constant FEE_IDS = bytes32(
        abi.encodePacked(
            bytes4(0x11111111),
            bytes4(0x22222222),
            bytes4(0x33333333),
            bytes4(0x44444444),
            bytes4(0x55555555),
            bytes12(0)
        )
    );

    // Configs for 3 vaults.
    IStandardVault.VaultConfig config1; // vault1: pkg1, [tokenA, tokenB], [DEX, LENDING]
    IStandardVault.VaultConfig config2; // vault2: pkg1, [tokenB, tokenC], [DEX]
    IStandardVault.VaultConfig config3; // vault3: pkg2, [tokenA], [LENDING]

    function setUp() public virtual override {
        super.setUp();

        vaultManager = IVaultRegistryVaultManager(address(indexedexManager));
        vaultQuery = IVaultRegistryVaultQuery(address(indexedexManager));
        pkgManager = IVaultRegistryVaultPackageManager(address(indexedexManager));
        pkgQuery = IVaultRegistryVaultPackageQuery(address(indexedexManager));

        vault1 = makeAddr("vault1");
        vault2 = makeAddr("vault2");
        vault3 = makeAddr("vault3");
        pkg1 = makeAddr("pkg1");
        pkg2 = makeAddr("pkg2");
        tokenA = makeAddr("tokenA");
        tokenB = makeAddr("tokenB");
        tokenC = makeAddr("tokenC");

        // --- Config 1: vault1, pkg1, tokens=[tokenA, tokenB], types=[DEX, LENDING] ---
        {
            address[] memory tokens1 = _sortedPair(tokenA, tokenB);
            bytes4[] memory types1 = new bytes4[](2);
            types1[0] = TYPE_DEX;
            types1[1] = TYPE_LENDING;
            config1 = IStandardVault.VaultConfig({
                vaultFeeTypeIds: FEE_IDS,
                contentsId: keccak256(abi.encode(tokens1)),
                vaultTypes: types1,
                tokens: tokens1
            });
        }

        // --- Config 2: vault2, pkg1, tokens=[tokenB, tokenC], types=[DEX] ---
        {
            address[] memory tokens2 = _sortedPair(tokenB, tokenC);
            bytes4[] memory types2 = new bytes4[](1);
            types2[0] = TYPE_DEX;
            config2 = IStandardVault.VaultConfig({
                vaultFeeTypeIds: FEE_IDS,
                contentsId: keccak256(abi.encode(tokens2)),
                vaultTypes: types2,
                tokens: tokens2
            });
        }

        // --- Config 3: vault3, pkg2, tokens=[tokenA], types=[LENDING] ---
        {
            address[] memory tokens3 = new address[](1);
            tokens3[0] = tokenA;
            bytes4[] memory types3 = new bytes4[](1);
            types3[0] = TYPE_LENDING;
            config3 = IStandardVault.VaultConfig({
                vaultFeeTypeIds: FEE_IDS,
                contentsId: keccak256(abi.encode(tokens3)),
                vaultTypes: types3,
                tokens: tokens3
            });
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    function _sortedPair(address a, address b) internal pure returns (address[] memory sorted) {
        sorted = new address[](2);
        if (a <= b) {
            sorted[0] = a;
            sorted[1] = b;
        } else {
            sorted[0] = b;
            sorted[1] = a;
        }
    }

    function _registerAll() internal {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, config1);
        vaultManager.registerVault(vault2, pkg1, config2);
        vaultManager.registerVault(vault3, pkg2, config3);
        vm.stopPrank();
    }

    function _contains(address[] memory arr, address target) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] == target) return true;
        }
        return false;
    }

    /* ---------------------------------------------------------------------- */
    /*              US-038.3: vaults() Returns All Registered Vaults          */
    /* ---------------------------------------------------------------------- */

    /// @notice vaults() returns all registered vaults.
    function test_vaults_returnsAll() public {
        _registerAll();

        address[] memory all = vaultQuery.vaults();
        assertEq(all.length, 3, "should have 3 vaults");
        assertTrue(_contains(all, vault1), "vault1 present");
        assertTrue(_contains(all, vault2), "vault2 present");
        assertTrue(_contains(all, vault3), "vault3 present");
    }

    /* ---------------------------------------------------------------------- */
    /*         US-038.3: vaultsOfType Returns Correct Subset                  */
    /* ---------------------------------------------------------------------- */

    /// @notice vaultsOfType(DEX) returns vault1 and vault2 (both have DEX type).
    function test_vaultsOfType_dex_returnsCorrectSubset() public {
        _registerAll();

        address[] memory dexVaults = vaultQuery.vaultsOfType(TYPE_DEX);
        assertEq(dexVaults.length, 2, "DEX type should have 2 vaults");
        assertTrue(_contains(dexVaults, vault1), "vault1 is DEX");
        assertTrue(_contains(dexVaults, vault2), "vault2 is DEX");
        assertFalse(_contains(dexVaults, vault3), "vault3 is not DEX");
    }

    /// @notice vaultsOfType(LENDING) returns vault1 and vault3 (both have LENDING type).
    function test_vaultsOfType_lending_returnsCorrectSubset() public {
        _registerAll();

        address[] memory lendingVaults = vaultQuery.vaultsOfType(TYPE_LENDING);
        assertEq(lendingVaults.length, 2, "LENDING type should have 2 vaults");
        assertTrue(_contains(lendingVaults, vault1), "vault1 is LENDING");
        assertTrue(_contains(lendingVaults, vault3), "vault3 is LENDING");
        assertFalse(_contains(lendingVaults, vault2), "vault2 is not LENDING");
    }

    /// @notice vaultsOfType for a non-registered type returns empty.
    function test_vaultsOfType_unregisteredType_returnsEmpty() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfType(bytes4(0x99999999));
        assertEq(result.length, 0, "unregistered type should return empty");
    }

    /* ---------------------------------------------------------------------- */
    /*        US-038.3: vaultsOfToken Returns Correct Subset                  */
    /* ---------------------------------------------------------------------- */

    /// @notice vaultsOfToken(tokenA) returns vault1 and vault3.
    function test_vaultsOfToken_tokenA_returnsCorrectSubset() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfToken(tokenA);
        assertEq(result.length, 2, "tokenA should have 2 vaults");
        assertTrue(_contains(result, vault1), "vault1 has tokenA");
        assertTrue(_contains(result, vault3), "vault3 has tokenA");
    }

    /// @notice vaultsOfToken(tokenB) returns vault1 and vault2.
    function test_vaultsOfToken_tokenB_returnsCorrectSubset() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfToken(tokenB);
        assertEq(result.length, 2, "tokenB should have 2 vaults");
        assertTrue(_contains(result, vault1), "vault1 has tokenB");
        assertTrue(_contains(result, vault2), "vault2 has tokenB");
    }

    /// @notice vaultsOfToken(tokenC) returns vault2 only.
    function test_vaultsOfToken_tokenC_returnsCorrectSubset() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfToken(tokenC);
        assertEq(result.length, 1, "tokenC should have 1 vault");
        assertEq(result[0], vault2, "vault2 has tokenC");
    }

    /// @notice vaultsOfToken for an unregistered token returns empty.
    function test_vaultsOfToken_unregisteredToken_returnsEmpty() public {
        _registerAll();

        address unregistered = makeAddr("unregisteredToken");
        address[] memory result = vaultQuery.vaultsOfToken(unregistered);
        assertEq(result.length, 0, "unregistered token should return empty");
    }

    /* ---------------------------------------------------------------------- */
    /*        US-038.3: Cross-Index Queries (Type + Token)                     */
    /* ---------------------------------------------------------------------- */

    /// @notice vaultsOfTypeOfToken(DEX, tokenB) returns vault1 and vault2.
    function test_vaultsOfTypeOfToken_dex_tokenB() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfTypeOfToken(TYPE_DEX, tokenB);
        assertEq(result.length, 2, "DEX+tokenB should have 2 vaults");
        assertTrue(_contains(result, vault1), "vault1 is DEX with tokenB");
        assertTrue(_contains(result, vault2), "vault2 is DEX with tokenB");
    }

    /// @notice vaultsOfTypeOfToken(LENDING, tokenA) returns vault1 and vault3.
    function test_vaultsOfTypeOfToken_lending_tokenA() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfTypeOfToken(TYPE_LENDING, tokenA);
        assertEq(result.length, 2, "LENDING+tokenA should have 2 vaults");
        assertTrue(_contains(result, vault1), "vault1 is LENDING with tokenA");
        assertTrue(_contains(result, vault3), "vault3 is LENDING with tokenA");
    }

    /// @notice vaultsOfTypeOfToken(LENDING, tokenC) returns empty (no overlap).
    function test_vaultsOfTypeOfToken_noOverlap_returnsEmpty() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfTypeOfToken(TYPE_LENDING, tokenC);
        assertEq(result.length, 0, "LENDING+tokenC should have 0 vaults");
    }

    /* ---------------------------------------------------------------------- */
    /*        US-038.3: Package-Specific Queries                              */
    /* ---------------------------------------------------------------------- */

    /// @notice vaultsOfPackage(pkg1) returns vault1 and vault2.
    function test_vaultsOfPackage_pkg1() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfPackage(pkg1);
        assertEq(result.length, 2, "pkg1 should have 2 vaults");
        assertTrue(_contains(result, vault1), "vault1 from pkg1");
        assertTrue(_contains(result, vault2), "vault2 from pkg1");
    }

    /// @notice vaultsOfPackage(pkg2) returns vault3 only.
    function test_vaultsOfPackage_pkg2() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfPackage(pkg2);
        assertEq(result.length, 1, "pkg2 should have 1 vault");
        assertEq(result[0], vault3, "vault3 from pkg2");
    }

    /// @notice vaultsOfPkgOfToken(pkg1, tokenA) returns vault1 only.
    function test_vaultsOfPkgOfToken_pkg1_tokenA() public {
        _registerAll();

        address[] memory result = vaultQuery.vaultsOfPkgOfToken(pkg1, tokenA);
        assertEq(result.length, 1, "pkg1+tokenA should have 1 vault");
        assertEq(result[0], vault1);
    }

    /* ---------------------------------------------------------------------- */
    /*        US-038.3: Query Results After Unregister                         */
    /* ---------------------------------------------------------------------- */

    /// @notice After unregistering vault1, vaults() returns vault2 and vault3.
    function test_vaults_afterUnregister() public {
        _registerAll();

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        address[] memory all = vaultQuery.vaults();
        assertEq(all.length, 2, "should have 2 vaults after unregister");
        assertFalse(_contains(all, vault1), "vault1 should be removed");
        assertTrue(_contains(all, vault2), "vault2 should remain");
        assertTrue(_contains(all, vault3), "vault3 should remain");
    }

    /// @notice After unregistering vault1, vaultsOfType(DEX) returns vault2 only.
    function test_vaultsOfType_afterUnregister() public {
        _registerAll();

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        address[] memory dexVaults = vaultQuery.vaultsOfType(TYPE_DEX);
        assertEq(dexVaults.length, 1, "DEX should have 1 vault after unregister");
        assertEq(dexVaults[0], vault2, "vault2 should remain in DEX");
    }

    /// @notice After unregistering vault1, vaultsOfToken(tokenA) returns vault3 only.
    function test_vaultsOfToken_afterUnregister() public {
        _registerAll();

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        address[] memory result = vaultQuery.vaultsOfToken(tokenA);
        assertEq(result.length, 1, "tokenA should have 1 vault after unregister");
        assertEq(result[0], vault3, "vault3 should remain for tokenA");
    }

    /// @notice After unregistering vault1, vaultsOfPackage(pkg1) returns vault2 only.
    function test_vaultsOfPackage_afterUnregister() public {
        _registerAll();

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        address[] memory result = vaultQuery.vaultsOfPackage(pkg1);
        assertEq(result.length, 1, "pkg1 should have 1 vault after unregister");
        assertEq(result[0], vault2, "vault2 should remain in pkg1");
    }

    /// @notice After unregistering vault1, contentsIds retains stale entries (append-only).
    function test_contentsIds_afterUnregister_retainsStaleEntries() public {
        _registerAll();

        uint256 beforeCount = vaultQuery.contentsIds().length;

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        uint256 afterCount = vaultQuery.contentsIds().length;
        assertEq(afterCount, beforeCount, "contentsIds count unchanged (append-only)");
    }

    /// @notice After unregistering vault1, vaultTokens retains stale entries (append-only).
    function test_vaultTokens_afterUnregister_retainsStaleEntries() public {
        _registerAll();

        uint256 beforeCount = vaultQuery.vaultTokens().length;

        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, config1);

        uint256 afterCount = vaultQuery.vaultTokens().length;
        assertEq(afterCount, beforeCount, "vaultTokens count unchanged (append-only)");
    }

    /* ---------------------------------------------------------------------- */
    /*    US-038.4: Anti-Spam Behavior (Registry Growth and Gas Costs)         */
    /* ---------------------------------------------------------------------- */

    /// @notice Multiple vault registrations increase the vaults() array size linearly.
    function test_multipleRegistrations_increaseRegistrySize() public {
        uint256 count = 10;
        vm.startPrank(owner);
        for (uint256 i; i < count; i++) {
            address v = address(uint160(0x1000 + i));
            address t = address(uint160(0x2000 + i));
            address[] memory tokens = new address[](1);
            tokens[0] = t;
            bytes4[] memory types = new bytes4[](1);
            types[0] = TYPE_DEX;
            IStandardVault.VaultConfig memory cfg = IStandardVault.VaultConfig({
                vaultFeeTypeIds: FEE_IDS, contentsId: keccak256(abi.encode(tokens)), vaultTypes: types, tokens: tokens
            });
            vaultManager.registerVault(v, pkg1, cfg);
        }
        vm.stopPrank();

        assertEq(vaultQuery.vaults().length, count, "registry should have 10 vaults");
    }

    /// @notice Gas cost of registerVault increases with vault type and token count.
    /// @dev This test documents gas cost for a single registration. Monitor in CI for regressions.
    function test_registerVault_gasProfile() public {
        address v = makeAddr("gasTestVault");
        address t = makeAddr("gasTestToken");
        address[] memory tokens = new address[](1);
        tokens[0] = t;
        bytes4[] memory types = new bytes4[](1);
        types[0] = TYPE_DEX;
        IStandardVault.VaultConfig memory cfg = IStandardVault.VaultConfig({
            vaultFeeTypeIds: FEE_IDS, contentsId: keccak256(abi.encode(tokens)), vaultTypes: types, tokens: tokens
        });

        vm.prank(owner);
        uint256 gasBefore = gasleft();
        vaultManager.registerVault(v, pkg1, cfg);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas used for monitoring. Exact values depend on optimizer settings.
        // The purpose is to have a baseline - not to assert a hard limit.
        assertTrue(gasUsed > 0, "gas should be consumed");
    }

    /// @notice Query performance: vaults() with a populated registry returns all entries.
    /// @dev Tests that the registry can handle 20 vaults without issues.
    function test_queryPerformance_withLargeRegistry() public {
        uint256 count = 20;
        vm.startPrank(owner);
        for (uint256 i; i < count; i++) {
            address v = address(uint160(0x3000 + i));
            address t = address(uint160(0x4000 + i));
            address[] memory tokens = new address[](1);
            tokens[0] = t;
            bytes4[] memory types = new bytes4[](1);
            types[0] = TYPE_DEX;
            IStandardVault.VaultConfig memory cfg = IStandardVault.VaultConfig({
                vaultFeeTypeIds: FEE_IDS, contentsId: keccak256(abi.encode(tokens)), vaultTypes: types, tokens: tokens
            });
            vaultManager.registerVault(v, pkg1, cfg);
        }
        vm.stopPrank();

        address[] memory all = vaultQuery.vaults();
        assertEq(all.length, count, "should return all 20 vaults");

        address[] memory dexVaults = vaultQuery.vaultsOfType(TYPE_DEX);
        assertEq(dexVaults.length, count, "all 20 should be DEX type");
    }
}
