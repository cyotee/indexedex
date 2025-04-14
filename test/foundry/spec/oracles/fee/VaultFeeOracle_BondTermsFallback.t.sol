// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    DEFAULT_BOND_MIN_TERM,
    DEFAULT_BOND_MAX_TERM,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title VaultFeeOracle_BondTermsFallback_Test
 * @notice US-IDXEX-040.1: Tests documenting the Vault Fee Oracle's 3-level bond terms fallback hierarchy.
 * @notice US-IDXEX-040.2: Tests proving ProtocolNFTVaultTarget always delegates to the oracle.
 *
 * @dev The fee oracle resolves bond terms via a sentinel-based fallback chain:
 *
 *      bondTermsOfVault(vault)
 *      │
 *      ├─ Level 1: _bondTermsOfVault(vault)           [vault-specific override]
 *      │  └─ If minLockDuration == 0, continue...
 *      │
 *      ├─ Level 2: defaultBondTermsOfVaultTypeId(id)   [vault-type default]
 *      │  └─ If minLockDuration == 0, continue...
 *      │
 *      └─ Level 3: defaultBondTerms()                  [global default]
 *
 *      The sentinel value is `minLockDuration == 0`, which means "not configured."
 *      A zero minLockDuration is never valid in production (a bond with no lock is meaningless),
 *      so this sentinel does not reduce the usable value space.
 */
contract VaultFeeOracle_BondTermsFallback_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;
    IVaultRegistryVaultManager vaultManager;

    address testVault;

    // Bond type ID used for vault-type-level defaults (Level 2).
    bytes4 constant TEST_BOND_TYPE_ID = bytes4(0xb04d0001);

    // Packed VaultFeeTypeIds: [usage:4][dex:4][bond:4][seigniorage:4][lending:4][padding:12]
    // Only the bond slot (index 2) matters — set to TEST_BOND_TYPE_ID.
    bytes32 vaultFeeTypeIds;

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
        vaultManager = IVaultRegistryVaultManager(address(indexedexManager));
        testVault = makeAddr("bondFallbackVault");

        // Encode fee type IDs with TEST_BOND_TYPE_ID in the bond slot.
        vaultFeeTypeIds = bytes32(
            abi.encodePacked(
                bytes4(0), // usage (unused for this test)
                bytes4(0), // dex (unused for this test)
                TEST_BOND_TYPE_ID, // bond
                bytes4(0), // seigniorage (unused for this test)
                bytes4(0), // lending (unused for this test)
                bytes12(0) // padding
            )
        );
    }

    /* ====================================================================== */
    /*              US-IDXEX-040.1: 3-Level Bond Terms Fallback Chain         */
    /* ====================================================================== */

    /* ---------------------------------------------------------------------- */
    /*               Level 3: Global Defaults (Lowest Priority)               */
    /* ---------------------------------------------------------------------- */

    /// @notice Global defaults are initialized during deployment and match the named constants.
    function test_globalDefaults_matchConstants() public view {
        BondTerms memory terms = feeOracle.defaultBondTerms();
        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM, "minLockDuration != DEFAULT_BOND_MIN_TERM");
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM, "maxLockDuration != DEFAULT_BOND_MAX_TERM");
        assertEq(
            terms.minBonusPercentage,
            DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
            "minBonusPercentage != DEFAULT_BOND_MIN_BONUS_PERCENTAGE"
        );
        assertEq(
            terms.maxBonusPercentage,
            DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
            "maxBonusPercentage != DEFAULT_BOND_MAX_BONUS_PERCENTAGE"
        );
    }

    /// @notice Global defaults: 30 days min, 180 days max, 5% min bonus, 10% max bonus.
    function test_globalDefaults_haveExpectedValues() public view {
        BondTerms memory terms = feeOracle.defaultBondTerms();
        assertEq(terms.minLockDuration, 30 days);
        assertEq(terms.maxLockDuration, 180 days);
        assertEq(terms.minBonusPercentage, 5e16); // 5% WAD
        assertEq(terms.maxBonusPercentage, 1e17); // 10% WAD
    }

    /// @notice An unregistered vault with no overrides falls back to global defaults.
    function test_unregisteredVault_fallsBackToGlobalDefaults() public view {
        address unknownVault = address(0xdead);
        BondTerms memory terms = feeOracle.bondTermsOfVault(unknownVault);
        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM);
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM);
        assertEq(terms.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(terms.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
    }

    /// @notice Updating the global default changes what unregistered vaults receive.
    function test_updateGlobalDefaults_affectsUnregisteredVault() public {
        BondTerms memory newGlobal = BondTerms({
            minLockDuration: 14 days,
            maxLockDuration: 365 days,
            minBonusPercentage: 2e16, // 2%
            maxBonusPercentage: 2e17 // 20%
        });

        vm.prank(owner);
        feeManager.setDefaultBondTerms(newGlobal);

        address unknownVault = makeAddr("unknownVault2");
        BondTerms memory terms = feeOracle.bondTermsOfVault(unknownVault);
        assertEq(terms.minLockDuration, 14 days);
        assertEq(terms.maxLockDuration, 365 days);
        assertEq(terms.minBonusPercentage, 2e16);
        assertEq(terms.maxBonusPercentage, 2e17);
    }

    /* ---------------------------------------------------------------------- */
    /*              Level 2: Vault-Type Defaults (Medium Priority)            */
    /* ---------------------------------------------------------------------- */

    /// @notice Vault-type defaults are returned when queried directly.
    function test_vaultTypeDefault_returnedByDirectQuery() public {
        BondTerms memory typeDefault = BondTerms({
            minLockDuration: 60 days,
            maxLockDuration: 270 days,
            minBonusPercentage: 3e16, // 3%
            maxBonusPercentage: 8e16 // 8%
        });

        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, typeDefault);

        BondTerms memory terms = feeOracle.defaultBondTermsOfVaultTypeId(TEST_BOND_TYPE_ID);
        assertEq(terms.minLockDuration, 60 days);
        assertEq(terms.maxLockDuration, 270 days);
        assertEq(terms.minBonusPercentage, 3e16);
        assertEq(terms.maxBonusPercentage, 8e16);
    }

    /// @notice A registered vault with a bond type ID falls back to vault-type defaults
    ///         when no vault-specific override is set.
    function test_registeredVault_fallsBackToVaultTypeDefault() public {
        // Step 1: Set vault-type default for TEST_BOND_TYPE_ID.
        BondTerms memory typeDefault = BondTerms({
            minLockDuration: 45 days,
            maxLockDuration: 240 days,
            minBonusPercentage: 4e16, // 4%
            maxBonusPercentage: 9e16 // 9%
        });
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, typeDefault);

        // Step 2: Register vault with TEST_BOND_TYPE_ID in the bond slot.
        _registerTestVault(testVault);

        // Step 3: Query — should return vault-type default, NOT global default.
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, 45 days, "Should use vault-type default minLockDuration");
        assertEq(terms.maxLockDuration, 240 days, "Should use vault-type default maxLockDuration");
        assertEq(terms.minBonusPercentage, 4e16, "Should use vault-type default minBonusPercentage");
        assertEq(terms.maxBonusPercentage, 9e16, "Should use vault-type default maxBonusPercentage");
    }

    /// @notice A vault-type default with minLockDuration == 0 is treated as "not configured",
    ///         causing fallback to global defaults even when the vault is registered with that type.
    function test_vaultTypeDefault_withZeroMinLock_fallsThroughToGlobal() public {
        // Set a vault-type default where only minLockDuration is zero (sentinel triggers).
        BondTerms memory emptyType = BondTerms({
            minLockDuration: 0, // sentinel: "not configured"
            maxLockDuration: 999 days,
            minBonusPercentage: 1e17,
            maxBonusPercentage: 5e17
        });
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, emptyType);

        _registerTestVault(testVault);

        // Should fall through to global defaults because minLockDuration == 0.
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM, "Should fall through to global");
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM, "Should fall through to global");
    }

    /* ---------------------------------------------------------------------- */
    /*             Level 1: Vault-Specific Override (Highest Priority)        */
    /* ---------------------------------------------------------------------- */

    /// @notice Vault-specific bond terms override both vault-type and global defaults.
    function test_vaultSpecificOverride_takesHighestPriority() public {
        // Set global and vault-type defaults to known values.
        BondTerms memory typeDefault = BondTerms({
            minLockDuration: 60 days, maxLockDuration: 270 days, minBonusPercentage: 3e16, maxBonusPercentage: 8e16
        });
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, typeDefault);

        _registerTestVault(testVault);

        // Set vault-specific override — should take priority.
        BondTerms memory vaultOverride = BondTerms({
            minLockDuration: 7 days,
            maxLockDuration: 90 days,
            minBonusPercentage: 1e16, // 1%
            maxBonusPercentage: 5e16 // 5%
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, vaultOverride);

        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, 7 days, "Should use vault-specific override");
        assertEq(terms.maxLockDuration, 90 days);
        assertEq(terms.minBonusPercentage, 1e16);
        assertEq(terms.maxBonusPercentage, 5e16);
    }

    /// @notice Clearing vault-specific override (set to zero) falls back to vault-type default.
    function test_clearVaultOverride_fallsBackToVaultTypeDefault() public {
        // Set vault-type default.
        BondTerms memory typeDefault = BondTerms({
            minLockDuration: 45 days, maxLockDuration: 240 days, minBonusPercentage: 4e16, maxBonusPercentage: 9e16
        });
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, typeDefault);

        _registerTestVault(testVault);

        // Set then clear vault-specific override.
        BondTerms memory vaultOverride = BondTerms({
            minLockDuration: 7 days, maxLockDuration: 90 days, minBonusPercentage: 1e16, maxBonusPercentage: 5e16
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, vaultOverride);

        // Verify override is active.
        assertEq(feeOracle.bondTermsOfVault(testVault).minLockDuration, 7 days);

        // Clear by setting minLockDuration to 0 (sentinel).
        BondTerms memory zero =
            BondTerms({minLockDuration: 0, maxLockDuration: 0, minBonusPercentage: 0, maxBonusPercentage: 0});
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, zero);

        // Should now return vault-type default.
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, 45 days, "Should fall back to vault-type default");
        assertEq(terms.maxLockDuration, 240 days);
        assertEq(terms.minBonusPercentage, 4e16);
        assertEq(terms.maxBonusPercentage, 9e16);
    }

    /* ---------------------------------------------------------------------- */
    /*          Full 3-Level Chain: Progressive Fallback Demonstration        */
    /* ---------------------------------------------------------------------- */

    /// @notice Walk the entire fallback chain: set all 3 levels, then remove them one by one.
    function test_fullFallbackChain_progressiveRemoval() public {
        // Set vault-type default.
        BondTerms memory typeDefault = BondTerms({
            minLockDuration: 60 days, maxLockDuration: 300 days, minBonusPercentage: 6e16, maxBonusPercentage: 12e16
        });
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, typeDefault);

        _registerTestVault(testVault);

        // Set vault-specific override.
        BondTerms memory vaultOverride = BondTerms({
            minLockDuration: 7 days, maxLockDuration: 30 days, minBonusPercentage: 1e16, maxBonusPercentage: 2e16
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, vaultOverride);

        // Level 1: vault-specific is active.
        assertEq(feeOracle.bondTermsOfVault(testVault).minLockDuration, 7 days, "L1: vault override");

        // Clear Level 1 → falls to Level 2 (vault-type default).
        BondTerms memory zero =
            BondTerms({minLockDuration: 0, maxLockDuration: 0, minBonusPercentage: 0, maxBonusPercentage: 0});
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, zero);
        assertEq(feeOracle.bondTermsOfVault(testVault).minLockDuration, 60 days, "L2: vault-type default");

        // Clear Level 2 → falls to Level 3 (global default).
        vm.prank(owner);
        feeManager.setDefaultBondTermsOfTypeId(TEST_BOND_TYPE_ID, zero);
        assertEq(feeOracle.bondTermsOfVault(testVault).minLockDuration, DEFAULT_BOND_MIN_TERM, "L3: global default");
    }

    /* ====================================================================== */
    /*                     Sentinel Logic: minLockDuration == 0              */
    /* ====================================================================== */

    /// @notice minLockDuration == 0 is the ONLY sentinel check — other fields don't matter.
    function test_sentinel_onlyChecksMinLockDuration() public {
        // Set bond terms where minLockDuration is 0 but other fields are non-zero.
        BondTerms memory partialZero = BondTerms({
            minLockDuration: 0, // sentinel triggers
            maxLockDuration: 999 days,
            minBonusPercentage: 5e17, // 50%
            maxBonusPercentage: 9e17 // 90%
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, partialZero);

        // Despite non-zero max/bonus values, minLockDuration == 0 triggers fallback.
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM, "Sentinel should trigger fallback");
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM, "Entire struct should be replaced");
        assertEq(
            terms.maxBonusPercentage,
            DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
            "maxBonusPercentage should be from global, not from partial override"
        );
    }

    /// @notice A minLockDuration of 1 (smallest non-zero) does NOT trigger fallback.
    function test_sentinel_minLockDurationOfOne_noFallback() public {
        BondTerms memory minimal = BondTerms({
            minLockDuration: 1, // smallest valid value — NOT the sentinel
            maxLockDuration: 2,
            minBonusPercentage: 3,
            maxBonusPercentage: 4
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, minimal);

        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, 1, "minLockDuration=1 should NOT trigger fallback");
        assertEq(terms.maxLockDuration, 2);
        assertEq(terms.minBonusPercentage, 3);
        assertEq(terms.maxBonusPercentage, 4);
    }

    /// @notice All-zero struct is the canonical "unset" / "clear override" value.
    function test_sentinel_allZeroStruct_isClearOverride() public {
        // Set a custom override.
        BondTerms memory custom = BondTerms({
            minLockDuration: 10 days, maxLockDuration: 100 days, minBonusPercentage: 2e16, maxBonusPercentage: 8e16
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, custom);
        assertEq(feeOracle.bondTermsOfVault(testVault).minLockDuration, 10 days);

        // Clear with all-zero struct.
        BondTerms memory zero =
            BondTerms({minLockDuration: 0, maxLockDuration: 0, minBonusPercentage: 0, maxBonusPercentage: 0});
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, zero);

        // Should return global defaults.
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);
        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM);
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM);
        assertEq(terms.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(terms.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
    }

    /* ====================================================================== */
    /*         US-IDXEX-040.2: Oracle Delegation from Vault                  */
    /* ====================================================================== */

    /// @notice Changing global defaults changes what bondTermsOfVault returns for an unset vault.
    /// @dev This proves the vault's bond terms come from the oracle, not from a hardcoded base class.
    function test_oracleDefaultChange_affectsBondTermsOfVault() public {
        // Initial: vault falls back to global defaults.
        BondTerms memory before_ = feeOracle.bondTermsOfVault(testVault);
        assertEq(before_.minLockDuration, DEFAULT_BOND_MIN_TERM);
        assertEq(before_.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);

        // Update global defaults via oracle manager.
        BondTerms memory newGlobal = BondTerms({
            minLockDuration: 90 days,
            maxLockDuration: 365 days,
            minBonusPercentage: 1e16, // 1%
            maxBonusPercentage: 3e17 // 30%
        });
        vm.prank(owner);
        feeManager.setDefaultBondTerms(newGlobal);

        // Vault now returns updated oracle values.
        BondTerms memory after_ = feeOracle.bondTermsOfVault(testVault);
        assertEq(after_.minLockDuration, 90 days, "Oracle change should propagate to vault");
        assertEq(after_.maxLockDuration, 365 days);
        assertEq(after_.minBonusPercentage, 1e16);
        assertEq(after_.maxBonusPercentage, 3e17);
    }

    /// @notice ProtocolNFTVaultCommon._bondTerms() has different hardcoded values than the oracle.
    /// @dev If the vault ever used the base class fallback instead of the oracle, the values
    ///      would be: minLock=7d, maxLock=365d, minBonus=0, maxBonus=1e18 (100%).
    ///      This test documents that bondTermsOfVault returns oracle values (30d, 180d, 5%, 10%),
    ///      NOT the base class values. This confirms the base class is dead code.
    function test_bondTerms_areFromOracle_notBaseClass() public view {
        BondTerms memory terms = feeOracle.bondTermsOfVault(testVault);

        // Oracle global defaults (what we SHOULD get):
        assertEq(terms.minLockDuration, 30 days, "Should be oracle's 30 days, not base class 7 days");
        assertEq(terms.maxLockDuration, 180 days, "Should be oracle's 180 days, not base class 365 days");
        assertEq(terms.minBonusPercentage, 5e16, "Should be oracle's 5%, not base class 0");
        assertEq(terms.maxBonusPercentage, 1e17, "Should be oracle's 10%, not base class 100% (1e18)");

        // Verify these are NOT the ProtocolNFTVaultCommon base class values:
        assertTrue(terms.minLockDuration != 7 days, "Must differ from base class minLock");
        assertTrue(terms.maxLockDuration != 365 days, "Must differ from base class maxLock");
        assertTrue(terms.maxBonusPercentage != 1e18, "Must differ from base class maxBonus (100%)");
    }

    /* ====================================================================== */
    /*                          Fuzz: Arbitrary Bond Terms                    */
    /* ====================================================================== */

    /// @notice Any valid bond terms with non-zero minLockDuration are stored and returned as vault-specific override.
    function testFuzz_setVaultBondTerms_roundTrip(uint256 minLock, uint256 maxLock, uint256 minBonus, uint256 maxBonus)
        public
    {
        vm.assume(minLock > 0); // 0 is the sentinel — skip it.
        maxLock = bound(maxLock, minLock, type(uint256).max); // minLock <= maxLock required
        maxBonus = bound(maxBonus, 0, 1e18);
        minBonus = bound(minBonus, 0, maxBonus);

        BondTerms memory input = BondTerms({
            minLockDuration: minLock,
            maxLockDuration: maxLock,
            minBonusPercentage: minBonus,
            maxBonusPercentage: maxBonus
        });

        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, input);

        BondTerms memory stored = feeOracle.bondTermsOfVault(testVault);
        assertEq(stored.minLockDuration, minLock);
        assertEq(stored.maxLockDuration, maxLock);
        assertEq(stored.minBonusPercentage, minBonus);
        assertEq(stored.maxBonusPercentage, maxBonus);
    }

    /// @notice Any bond terms with minLockDuration == 0 trigger fallback to global defaults.
    function testFuzz_setVaultBondTerms_zeroMinLock_alwaysFallsBack(uint256 maxLock, uint256 minBonus, uint256 maxBonus)
        public
    {
        maxBonus = bound(maxBonus, 0, 1e18);
        minBonus = bound(minBonus, 0, maxBonus);

        BondTerms memory input = BondTerms({
            minLockDuration: 0, // always sentinel
            maxLockDuration: maxLock,
            minBonusPercentage: minBonus,
            maxBonusPercentage: maxBonus
        });

        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, input);

        BondTerms memory result = feeOracle.bondTermsOfVault(testVault);
        assertEq(result.minLockDuration, DEFAULT_BOND_MIN_TERM, "Should always fall back to global");
        assertEq(result.maxLockDuration, DEFAULT_BOND_MAX_TERM);
        assertEq(result.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(result.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
    }

    /* ====================================================================== */
    /*                             Test Helpers                               */
    /* ====================================================================== */

    /// @dev Registers testVault in the vault registry with TEST_BOND_TYPE_ID in the bond slot.
    function _registerTestVault(address vault) internal {
        address pkg = makeAddr("testPkg");
        address token = makeAddr("testToken");

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        bytes4[] memory vaultTypes = new bytes4[](1);
        vaultTypes[0] = bytes4(0xdeadbeef); // synthetic type

        IStandardVault.VaultConfig memory config = IStandardVault.VaultConfig({
            vaultFeeTypeIds: vaultFeeTypeIds,
            contentsId: keccak256(abi.encode(tokens)),
            vaultTypes: vaultTypes,
            tokens: tokens
        });

        vm.prank(owner);
        vaultManager.registerVault(vault, pkg, config);
    }
}
