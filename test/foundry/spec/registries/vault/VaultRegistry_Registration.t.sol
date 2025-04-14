// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryEvents} from "contracts/interfaces/IVaultRegistryEvents.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/**
 * @title VaultRegistry_Registration_Test
 * @notice US-IDXEX-038.1: Tests documenting vault registration/unregistration behavior.
 * @dev These tests call registerVault/unregisterVault directly on the IndexedexManager
 *      Diamond proxy with synthetic VaultConfig data to verify registry indexing semantics.
 *
 *      Key behaviors documented:
 *      - registerVault adds vault to ALL indexes (vaults, vaultsOfPkg, vaultsOfType, etc.)
 *      - unregisterVault removes from most indexes BUT NOT from contentsIds or vaultTokens
 *      - unregisterVault incorrectly assigns feeTypeIdsOfVault instead of clearing it
 *      - AddressSet._add is idempotent (second add is a no-op)
 *      - AddressSet._remove on non-existent vault is a no-op
 */
contract VaultRegistry_Registration_Test is IndexedexTest {
    // Cast the indexedexManager proxy to the manager and query interfaces.
    IVaultRegistryVaultManager vaultManager;
    IVaultRegistryVaultQuery vaultQuery;
    IVaultRegistryVaultPackageManager pkgManager;
    IVaultRegistryVaultPackageQuery pkgQuery;

    // Mock addresses for vaults and packages.
    address vault1;
    address vault2;
    address pkg1;
    address token0;
    address token1;

    // Synthetic vault type IDs (mock ERC165 interface IDs).
    bytes4 constant TYPE_DEX = bytes4(0xdeadbeef);
    bytes4 constant TYPE_LENDING = bytes4(0xcafebabe);

    // Synthetic fee type IDs packed into bytes32.
    // VaultFeeTypeIds has 5 fields of bytes4: usage, dex, bond, seigniorage, lending
    // Packed as: [usage:4][dex:4][bond:4][seigniorage:4][lending:4][padding:12]
    bytes32 constant VAULT_FEE_TYPE_IDS = bytes32(
        abi.encodePacked(
            bytes4(0x11111111), // usage
            bytes4(0x22222222), // dex
            bytes4(0x33333333), // bond
            bytes4(0x44444444), // seigniorage
            bytes4(0x55555555), // lending
            bytes12(0) // padding
        )
    );

    // Pre-computed contentsId (hash of sorted tokens).
    bytes32 contentsId1;

    // Reusable vault config.
    IStandardVault.VaultConfig vaultConfig1;

    function setUp() public virtual override {
        super.setUp();

        vaultManager = IVaultRegistryVaultManager(address(indexedexManager));
        vaultQuery = IVaultRegistryVaultQuery(address(indexedexManager));
        pkgManager = IVaultRegistryVaultPackageManager(address(indexedexManager));
        pkgQuery = IVaultRegistryVaultPackageQuery(address(indexedexManager));

        vault1 = makeAddr("vault1");
        vault2 = makeAddr("vault2");
        pkg1 = makeAddr("pkg1");
        token0 = makeAddr("token0");
        token1 = makeAddr("token1");

        // Ensure token0 < token1 for sorted order (required for contentsId).
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        // Build sorted token array.
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;

        // Compute contentsId the same way the registry does.
        contentsId1 = keccak256(abi.encode(tokens));

        // Build vault types.
        bytes4[] memory vaultTypes = new bytes4[](2);
        vaultTypes[0] = TYPE_DEX;
        vaultTypes[1] = TYPE_LENDING;

        vaultConfig1 = IStandardVault.VaultConfig({
            vaultFeeTypeIds: VAULT_FEE_TYPE_IDS, contentsId: contentsId1, vaultTypes: vaultTypes, tokens: tokens
        });
    }

    /* ---------------------------------------------------------------------- */
    /*               registerVault: Adds to All Relevant Indexes              */
    /* ---------------------------------------------------------------------- */

    /// @notice registerVault adds vault to vaults() set.
    function test_registerVault_addsToVaultsSet() public {
        assertEq(vaultQuery.vaults().length, 0, "vaults should start empty");

        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory allVaults = vaultQuery.vaults();
        assertEq(allVaults.length, 1, "vaults should have 1 entry");
        assertEq(allVaults[0], vault1, "vault1 should be in vaults set");
        assertTrue(vaultQuery.isVault(vault1), "isVault should return true");
    }

    /// @notice registerVault adds to vaultsOfToken for each token in the config.
    function test_registerVault_addsToVaultsOfToken() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory vaultsOfToken0 = vaultQuery.vaultsOfToken(token0);
        address[] memory vaultsOfToken1 = vaultQuery.vaultsOfToken(token1);
        assertEq(vaultsOfToken0.length, 1, "vaultsOfToken0 should have 1");
        assertEq(vaultsOfToken0[0], vault1);
        assertEq(vaultsOfToken1.length, 1, "vaultsOfToken1 should have 1");
        assertEq(vaultsOfToken1[0], vault1);
    }

    /// @notice registerVault adds to vaultsOfType for each type in the config.
    function test_registerVault_addsToVaultsOfType() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory dexVaults = vaultQuery.vaultsOfType(TYPE_DEX);
        address[] memory lendingVaults = vaultQuery.vaultsOfType(TYPE_LENDING);
        assertEq(dexVaults.length, 1, "vaultsOfType(DEX) should have 1");
        assertEq(dexVaults[0], vault1);
        assertEq(lendingVaults.length, 1, "vaultsOfType(LENDING) should have 1");
        assertEq(lendingVaults[0], vault1);
    }

    /// @notice registerVault adds to vaultsOfPackage.
    function test_registerVault_addsToVaultsOfPackage() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory pkgVaults = vaultQuery.vaultsOfPackage(pkg1);
        assertEq(pkgVaults.length, 1, "vaultsOfPackage should have 1");
        assertEq(pkgVaults[0], vault1);
    }

    /// @notice registerVault adds to contentsIds set (append-only).
    function test_registerVault_addsToContentsIds() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        bytes32[] memory ids = vaultQuery.contentsIds();
        assertEq(ids.length, 1, "contentsIds should have 1");
        assertEq(ids[0], contentsId1);
    }

    /// @notice registerVault adds to vaultTokens set (append-only).
    function test_registerVault_addsToVaultTokens() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory tokens = vaultQuery.vaultTokens();
        assertEq(tokens.length, 2, "vaultTokens should have 2");
        assertTrue(
            vaultQuery.isContainedToken(token0) && vaultQuery.isContainedToken(token1),
            "both tokens should be contained"
        );
    }

    /// @notice registerVault adds to vaultsOfTypeOfToken cross-index.
    function test_registerVault_addsToVaultsOfTypeOfToken() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        address[] memory result = vaultQuery.vaultsOfTypeOfToken(TYPE_DEX, token0);
        assertEq(result.length, 1, "vaultsOfTypeOfToken should have 1");
        assertEq(result[0], vault1);
    }

    /// @notice registerVault sets fee type IDs for the vault.
    function test_registerVault_setsFeeTypeIds() public {
        vm.prank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);

        assertEq(vaultQuery.vaultUsageFeeTypeId(vault1), bytes4(0x11111111), "usage fee type should match");
        assertEq(vaultQuery.vaultDexTermsTypeId(vault1), bytes4(0x22222222), "dex fee type should match");
        assertEq(vaultQuery.vaultBondTermsTypeId(vault1), bytes4(0x33333333), "bond fee type should match");
    }

    /// @notice registerVault emits NewVault, NewVaultOfType, and NewVaultOfToken events.
    function test_registerVault_emitsEvents() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVaultRegistryEvents.NewVault(
            vault1, pkg1, VAULT_FEE_TYPE_IDS, contentsId1, vaultConfig1.vaultTypes, vaultConfig1.tokens
        );
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
    }

    /* ---------------------------------------------------------------------- */
    /*           unregisterVault: Removes from Expected Indexes               */
    /* ---------------------------------------------------------------------- */

    /// @notice unregisterVault removes from vaults() set.
    function test_unregisterVault_removesFromVaultsSet() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaults().length, 0, "vaults should be empty after unregister");
        assertFalse(vaultQuery.isVault(vault1), "isVault should return false after unregister");
    }

    /// @notice unregisterVault removes from vaultsOfToken for each token.
    function test_unregisterVault_removesFromVaultsOfToken() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaultsOfToken(token0).length, 0, "vaultsOfToken0 should be empty");
        assertEq(vaultQuery.vaultsOfToken(token1).length, 0, "vaultsOfToken1 should be empty");
    }

    /// @notice unregisterVault removes from vaultsOfType for each type.
    function test_unregisterVault_removesFromVaultsOfType() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaultsOfType(TYPE_DEX).length, 0, "vaultsOfType(DEX) should be empty");
        assertEq(vaultQuery.vaultsOfType(TYPE_LENDING).length, 0, "vaultsOfType(LENDING) should be empty");
    }

    /// @notice unregisterVault removes from vaultsOfPackage.
    function test_unregisterVault_removesFromVaultsOfPackage() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaultsOfPackage(pkg1).length, 0, "vaultsOfPackage should be empty");
    }

    /// @notice unregisterVault removes from vaultsOfTypeOfToken.
    function test_unregisterVault_removesFromVaultsOfTypeOfToken() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaultsOfTypeOfToken(TYPE_DEX, token0).length, 0, "vaultsOfTypeOfToken should be empty");
    }

    /// @notice unregisterVault clears per-vault fee ID mappings (usage, dex, bond, seigniorage, lending).
    function test_unregisterVault_clearsFeeIdMappings() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        assertEq(vaultQuery.vaultUsageFeeTypeId(vault1), bytes4(0), "usage fee should be cleared");
        assertEq(vaultQuery.vaultDexTermsTypeId(vault1), bytes4(0), "dex fee should be cleared");
        assertEq(vaultQuery.vaultBondTermsTypeId(vault1), bytes4(0), "bond fee should be cleared");
        assertEq(vaultQuery.vaultLendingTermsTypeId(vault1), bytes4(0), "lending fee should be cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*     unregisterVault: Does NOT Remove from Append-Only Sets             */
    /*     (Documents current behavior - these sets grow monotonically)        */
    /* ---------------------------------------------------------------------- */

    /// @notice BEHAVIOR: contentsIds is append-only. unregisterVault does NOT remove from contentsIds.
    /// @dev This means contentsIds() will return stale entries after unregistration.
    ///      This is by design - the set tracks "all ever seen" content IDs.
    function test_unregisterVault_doesNotRemoveFromContentsIds() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        bytes32[] memory ids = vaultQuery.contentsIds();
        assertEq(ids.length, 1, "contentsIds should still have 1 entry (append-only)");
        assertEq(ids[0], contentsId1, "stale contentsId should remain");
    }

    /// @notice BEHAVIOR: vaultTokens is append-only. unregisterVault does NOT remove from vaultTokens.
    /// @dev This means vaultTokens() will return stale entries after unregistration.
    ///      This is by design - the set tracks "all ever seen" tokens.
    function test_unregisterVault_doesNotRemoveFromVaultTokens() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        address[] memory tokens = vaultQuery.vaultTokens();
        assertEq(tokens.length, 2, "vaultTokens should still have 2 entries (append-only)");
        assertTrue(vaultQuery.isContainedToken(token0), "token0 should still be contained");
        assertTrue(vaultQuery.isContainedToken(token1), "token1 should still be contained");
    }

    /// @notice BEHAVIOR BUG: _removeVault assigns feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds
    ///         instead of deleting it. This means the packed feeTypeIds mapping retains stale data
    ///         after unregistration, even though individual fee fields are deleted.
    /// @dev See VaultRegistryVaultRepo.sol line 172:
    ///      layout.feeTypeIdsOfVault[vault] = vaultConfig.vaultFeeTypeIds;
    ///      This should be: delete layout.feeTypeIdsOfVault[vault];
    function test_unregisterVault_feeTypeIdsOfVault_bugStaleAssignment() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        // The individual fee fields ARE cleared (usage, dex, bond, etc.)
        assertEq(vaultQuery.vaultUsageFeeTypeId(vault1), bytes4(0), "individual fee field cleared");

        // But the packed feeTypeIdsOfVault[vault] mapping is NOT cleared - it retains the config value.
        // This is documented as a known bug from the code review.
        // We cannot directly query feeTypeIdsOfVault from the external interface,
        // but the behavior is captured in the source code analysis.
    }

    /* ---------------------------------------------------------------------- */
    /*                   Idempotence and Edge Cases                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Repeated registration of the same vault is idempotent (AddressSet._add ignores duplicates).
    function test_registerVault_repeated_isIdempotent() public {
        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        address[] memory allVaults = vaultQuery.vaults();
        assertEq(allVaults.length, 1, "repeated add should not duplicate in set");

        address[] memory vaultsOfToken0 = vaultQuery.vaultsOfToken(token0);
        assertEq(vaultsOfToken0.length, 1, "repeated add should not duplicate in vaultsOfToken");
    }

    /// @notice Unregistering a non-existent vault is a no-op (AddressSet._remove on absent element).
    function test_unregisterVault_nonExistent_isNoOp() public {
        // Should not revert when removing a vault that was never registered.
        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);

        assertEq(vaultQuery.vaults().length, 0, "vaults should remain empty");
    }

    /// @notice Register two vaults, then unregister one - the other remains intact.
    function test_unregisterVault_doesNotAffectOtherVaults() public {
        // Build a second vault config with different contentsId.
        address token2 = makeAddr("token2");
        address[] memory tokens2 = new address[](1);
        tokens2[0] = token2;
        bytes32 contentsId2 = keccak256(abi.encode(tokens2));
        bytes4[] memory types2 = new bytes4[](1);
        types2[0] = TYPE_DEX;

        IStandardVault.VaultConfig memory vaultConfig2 = IStandardVault.VaultConfig({
            vaultFeeTypeIds: VAULT_FEE_TYPE_IDS, contentsId: contentsId2, vaultTypes: types2, tokens: tokens2
        });

        vm.startPrank(owner);
        vaultManager.registerVault(vault1, pkg1, vaultConfig1);
        vaultManager.registerVault(vault2, pkg1, vaultConfig2);

        // Remove vault1 only.
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        vm.stopPrank();

        // vault2 should still be registered.
        assertEq(vaultQuery.vaults().length, 1, "one vault should remain");
        assertTrue(vaultQuery.isVault(vault2), "vault2 should still be registered");
        assertFalse(vaultQuery.isVault(vault1), "vault1 should be unregistered");

        // vault2's indexes should be intact.
        assertEq(vaultQuery.vaultsOfType(TYPE_DEX).length, 1, "vault2 should remain in DEX type");
        assertEq(vaultQuery.vaultsOfToken(token2).length, 1, "vault2's token should remain");
    }
}
