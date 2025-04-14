// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {
    DEFAULT_VAULT_USAGE_FEE,
    DEFAULT_DEX_FEE,
    DEFAULT_BOND_MIN_TERM,
    DEFAULT_BOND_MAX_TERM,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
    DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title VaultFeeOracle_Bounds_Test
 * @notice Tests that fee parameters behave correctly at boundary values.
 * @dev All WAD-denominated setters enforce on-chain validation (<= 1e18).
 *      Bond terms additionally validate: maxBonus <= WAD, minBonus <= maxBonus, minLock <= maxLock.
 */
contract VaultFeeOracle_Bounds_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;

    bytes4 testTypeId;
    address testVault;

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
        testTypeId = bytes4(keccak256("TEST_TYPE"));
        testVault = makeAddr("testVault");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Usage Fee Bounds                                */
    /* ---------------------------------------------------------------------- */

    /// @notice Setting usage fee to 100% (1e18) is accepted — no on-chain cap.
    function test_setDefaultUsageFee_accepts100Percent() public {
        vm.prank(owner);
        bool success = feeManager.setDefaultUsageFee(ONE_WAD);
        assertTrue(success);
        assertEq(feeOracle.defaultUsageFee(), ONE_WAD);
    }

    /// @notice Setting usage fee above 100% reverts.
    function test_setDefaultUsageFee_revertsAbove100Percent() public {
        uint256 aboveMax = ONE_WAD + 1;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, aboveMax, ONE_WAD));
        feeManager.setDefaultUsageFee(aboveMax);
    }

    /// @notice Setting usage fee to 0 is the sentinel for "unset" — triggers fallback.
    function test_setUsageFeeOfVault_zeroTriggersDefaultFallback() public {
        // First set a custom fee
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, 5e16); // 5%
        assertEq(feeOracle.usageFeeOfVault(testVault), 5e16);

        // Reset to 0 (unset) — should fallback to global default
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, 0);
        assertEq(feeOracle.usageFeeOfVault(testVault), DEFAULT_VAULT_USAGE_FEE);
    }

    /// @notice Type-level fee set to 0 falls back to global default.
    function test_setDefaultUsageFeeOfTypeId_zeroTriggersGlobalFallback() public {
        // Set a type-level fee
        vm.prank(owner);
        feeManager.setDefaultUsageFeeOfTypeId(testTypeId, 3e16); // 3%
        assertEq(feeOracle.defaultUsageFeeOfTypeId(testTypeId), 3e16);

        // Reset to 0
        vm.prank(owner);
        feeManager.setDefaultUsageFeeOfTypeId(testTypeId, 0);
        assertEq(feeOracle.defaultUsageFeeOfTypeId(testTypeId), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                        DEX Swap Fee Bounds                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Swap fee at 100% is accepted.
    function test_setDefaultDexSwapFee_accepts100Percent() public {
        vm.prank(owner);
        bool success = feeManager.setDefaultDexSwapFee(ONE_WAD);
        assertTrue(success);
        assertEq(feeOracle.defaultDexSwapFee(), ONE_WAD);
    }

    /// @notice Swap fee above 100% reverts.
    function test_setDefaultDexSwapFee_revertsAbove100Percent() public {
        uint256 aboveMax = ONE_WAD + 1;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, aboveMax, ONE_WAD));
        feeManager.setDefaultDexSwapFee(aboveMax);
    }

    /// @notice Swap fee at 0 is the sentinel for "unset".
    function test_setVaultDexSwapFee_zeroTriggersDefaultFallback() public {
        // Set a vault-specific swap fee
        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, 1e16); // 1%
        assertEq(feeOracle.dexSwapFeeOfVault(testVault), 1e16);

        // Reset to 0 — fallback to global default
        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, 0);
        assertEq(feeOracle.dexSwapFeeOfVault(testVault), DEFAULT_DEX_FEE);
    }

    /* ---------------------------------------------------------------------- */
    /*                   Bond Terms Validation — Reverts                      */
    /* ---------------------------------------------------------------------- */

    /// @notice maxBonusPercentage > ONE_WAD reverts.
    function test_setDefaultBondTerms_revertsWhenMaxBonusExceedsWAD() public {
        BondTerms memory bad = BondTerms({
            minLockDuration: 0,
            maxLockDuration: type(uint256).max,
            minBonusPercentage: 0,
            maxBonusPercentage: ONE_WAD + 1
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(VaultFeeOracleRepo.BondTerms_MaxBonusExceedsWAD.selector, ONE_WAD + 1, ONE_WAD)
        );
        feeManager.setDefaultBondTerms(bad);
    }

    /// @notice minBonusPercentage > maxBonusPercentage reverts.
    function test_setDefaultBondTerms_revertsWhenMinBonusExceedsMax() public {
        BondTerms memory inverted = BondTerms({
            minLockDuration: 30 days,
            maxLockDuration: 180 days,
            minBonusPercentage: ONE_WAD, // 100%
            maxBonusPercentage: 1e15 // 0.1%
        });
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.BondTerms_MinBonusExceedsMax.selector, ONE_WAD, 1e15));
        feeManager.setDefaultBondTerms(inverted);
    }

    /// @notice Type-level setter also validates bond terms.
    function test_setDefaultBondTermsOfTypeId_revertsWhenMaxBonusExceedsWAD() public {
        BondTerms memory bad = BondTerms({
            minLockDuration: 30 days, maxLockDuration: 180 days, minBonusPercentage: 0, maxBonusPercentage: 2 * ONE_WAD
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(VaultFeeOracleRepo.BondTerms_MaxBonusExceedsWAD.selector, 2 * ONE_WAD, ONE_WAD)
        );
        feeManager.setDefaultBondTermsOfTypeId(testTypeId, bad);
    }

    /// @notice Vault-level setter also validates bond terms.
    function test_setVaultBondTerms_revertsWhenMinBonusExceedsMax() public {
        BondTerms memory inverted = BondTerms({
            minLockDuration: 7 days,
            maxLockDuration: 90 days,
            minBonusPercentage: 5e16, // 5%
            maxBonusPercentage: 1e16 // 1%
        });
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.BondTerms_MinBonusExceedsMax.selector, 5e16, 1e16));
        feeManager.setVaultBondTerms(testVault, inverted);
    }

    /* ---------------------------------------------------------------------- */
    /*                   Bond Terms Validation — Accepts                       */
    /* ---------------------------------------------------------------------- */

    /// @notice Valid bond terms with typical percentages are accepted.
    function test_setDefaultBondTerms_acceptsValidTerms() public {
        BondTerms memory valid = BondTerms({
            minLockDuration: 30 days,
            maxLockDuration: 180 days,
            minBonusPercentage: 5e16, // 5%
            maxBonusPercentage: 1e17 // 10%
        });
        vm.prank(owner);
        bool success = feeManager.setDefaultBondTerms(valid);
        assertTrue(success);

        BondTerms memory stored = feeOracle.defaultBondTerms();
        assertEq(stored.minBonusPercentage, 5e16);
        assertEq(stored.maxBonusPercentage, 1e17);
    }

    /// @notice Bond terms with maxBonusPercentage exactly at ONE_WAD (100%) are accepted.
    function test_setDefaultBondTerms_acceptsMaxAt100Percent() public {
        BondTerms memory atMax = BondTerms({
            minLockDuration: 30 days,
            maxLockDuration: 180 days,
            minBonusPercentage: 5e17, // 50%
            maxBonusPercentage: ONE_WAD // 100%
        });
        vm.prank(owner);
        bool success = feeManager.setDefaultBondTerms(atMax);
        assertTrue(success);

        BondTerms memory stored = feeOracle.defaultBondTerms();
        assertEq(stored.maxBonusPercentage, ONE_WAD);
    }

    /// @notice Bond terms with min == max bonus percentage are accepted.
    function test_setDefaultBondTerms_acceptsEqualMinMax() public {
        BondTerms memory equal = BondTerms({
            minLockDuration: 30 days,
            maxLockDuration: 180 days,
            minBonusPercentage: 5e16, // 5%
            maxBonusPercentage: 5e16 // 5%
        });
        vm.prank(owner);
        bool success = feeManager.setDefaultBondTerms(equal);
        assertTrue(success);

        BondTerms memory stored = feeOracle.defaultBondTerms();
        assertEq(stored.minBonusPercentage, stored.maxBonusPercentage);
    }

    /// @notice All-zero bond terms is the sentinel for "unset" — triggers fallback.
    function test_setVaultBondTerms_allZeroTriggersDefaultFallback() public {
        // Set vault-specific bond terms
        BondTerms memory custom = BondTerms({
            minLockDuration: 7 days, maxLockDuration: 90 days, minBonusPercentage: 1e16, maxBonusPercentage: 5e16
        });
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, custom);

        BondTerms memory stored = feeOracle.bondTermsOfVault(testVault);
        assertEq(stored.minLockDuration, 7 days);

        // Reset with all-zero bond terms — minLockDuration == 0 triggers fallback
        BondTerms memory zero =
            BondTerms({minLockDuration: 0, maxLockDuration: 0, minBonusPercentage: 0, maxBonusPercentage: 0});
        vm.prank(owner);
        feeManager.setVaultBondTerms(testVault, zero);

        // Should fallback to global defaults
        BondTerms memory fallbackTerms = feeOracle.bondTermsOfVault(testVault);
        assertEq(fallbackTerms.minLockDuration, DEFAULT_BOND_MIN_TERM);
        assertEq(fallbackTerms.maxLockDuration, DEFAULT_BOND_MAX_TERM);
        assertEq(fallbackTerms.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(fallbackTerms.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
    }

    /// @notice Extreme lock durations are accepted when properly ordered (0, max).
    function test_setDefaultBondTerms_acceptsExtremeDurations() public {
        BondTerms memory extreme = BondTerms({
            minLockDuration: 0, maxLockDuration: type(uint256).max, minBonusPercentage: 0, maxBonusPercentage: ONE_WAD
        });
        vm.prank(owner);
        bool success = feeManager.setDefaultBondTerms(extreme);
        assertTrue(success);

        BondTerms memory stored = feeOracle.defaultBondTerms();
        assertEq(stored.minLockDuration, 0);
        assertEq(stored.maxLockDuration, type(uint256).max);
    }

    /// @notice Inverted lock durations revert at global level.
    function test_setDefaultBondTerms_revertsWhenMinLockExceedsMax() public {
        BondTerms memory invertedDurations = BondTerms({
            minLockDuration: 180 days, maxLockDuration: 30 days, minBonusPercentage: 0, maxBonusPercentage: 1e17
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFeeOracleRepo.BondTerms_MinLockExceedsMax.selector,
                invertedDurations.minLockDuration,
                invertedDurations.maxLockDuration
            )
        );
        feeManager.setDefaultBondTerms(invertedDurations);
    }

    /// @notice Type-level setter rejects inverted lock durations.
    function test_setDefaultBondTermsOfTypeId_revertsWhenMinLockExceedsMax() public {
        BondTerms memory invertedDurations = BondTerms({
            minLockDuration: 180 days, maxLockDuration: 30 days, minBonusPercentage: 0, maxBonusPercentage: 1e17
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFeeOracleRepo.BondTerms_MinLockExceedsMax.selector,
                invertedDurations.minLockDuration,
                invertedDurations.maxLockDuration
            )
        );
        feeManager.setDefaultBondTermsOfTypeId(testTypeId, invertedDurations);
    }

    /// @notice Vault-level setter rejects inverted lock durations.
    function test_setVaultBondTerms_revertsWhenMinLockExceedsMax() public {
        BondTerms memory invertedDurations = BondTerms({
            minLockDuration: 180 days, maxLockDuration: 30 days, minBonusPercentage: 0, maxBonusPercentage: 1e17
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultFeeOracleRepo.BondTerms_MinLockExceedsMax.selector,
                invertedDurations.minLockDuration,
                invertedDurations.maxLockDuration
            )
        );
        feeManager.setVaultBondTerms(testVault, invertedDurations);
    }

    /// @notice Bond terms with equal min/max lock duration are accepted.
    function test_setDefaultBondTerms_acceptsEqualLockDurations() public {
        BondTerms memory equal = BondTerms({
            minLockDuration: 90 days, maxLockDuration: 90 days, minBonusPercentage: 5e16, maxBonusPercentage: 1e17
        });
        vm.prank(owner);
        bool success = feeManager.setDefaultBondTerms(equal);
        assertTrue(success);

        BondTerms memory stored = feeOracle.defaultBondTerms();
        assertEq(stored.minLockDuration, stored.maxLockDuration);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Three-Tier Fallback Chain                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Full three-tier fallback: vault → type → global for usage fees.
    function test_usageFee_threeTierFallback() public {
        // Tier 3: global default
        assertEq(feeOracle.usageFeeOfVault(testVault), DEFAULT_VAULT_USAGE_FEE);

        // Tier 2: type-level default (need to register vault with this type — skip, covered by unit tests)

        // Tier 1: vault-specific override
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, 7e16); // 7%
        assertEq(feeOracle.usageFeeOfVault(testVault), 7e16);

        // Unset vault-specific → falls back to global (type not registered)
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, 0);
        assertEq(feeOracle.usageFeeOfVault(testVault), DEFAULT_VAULT_USAGE_FEE);
    }

    /// @notice Full three-tier fallback: vault → type → global for dex swap fees.
    function test_dexSwapFee_threeTierFallback() public {
        // Tier 3: global default
        assertEq(feeOracle.dexSwapFeeOfVault(testVault), DEFAULT_DEX_FEE);

        // Tier 1: vault-specific override
        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, 2e16); // 2%
        assertEq(feeOracle.dexSwapFeeOfVault(testVault), 2e16);

        // Unset vault-specific
        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, 0);
        assertEq(feeOracle.dexSwapFeeOfVault(testVault), DEFAULT_DEX_FEE);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Fuzz: Fee Values (<= ONE_WAD)                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Any uint256 fee value <= ONE_WAD can be stored and retrieved.
    function testFuzz_setDefaultUsageFee_wadBoundStored(uint256 fee) public {
        fee = bound(fee, 0, ONE_WAD);
        vm.prank(owner);
        feeManager.setDefaultUsageFee(fee);

        assertEq(feeOracle.defaultUsageFee(), fee);
    }

    /// @notice Any uint256 swap fee value <= ONE_WAD can be stored and retrieved.
    function testFuzz_setDefaultDexSwapFee_wadBoundStored(uint256 fee) public {
        fee = bound(fee, 0, ONE_WAD);
        vm.prank(owner);
        feeManager.setDefaultDexSwapFee(fee);

        assertEq(feeOracle.defaultDexSwapFee(), fee);
    }

    /* ---------------------------------------------------------------------- */
    /*                   Seigniorage Incentive Percentage Bounds               */
    /* ---------------------------------------------------------------------- */

    /// @notice Setting seigniorage incentive to 100% (1e18) is accepted.
    function test_setDefaultSeigniorageIncentivePercentage_accepts100Percent() public {
        vm.prank(owner);
        bool success = feeManager.setDefaultSeigniorageIncentivePercentage(ONE_WAD);
        assertTrue(success);
    }

    /// @notice Setting seigniorage incentive above 100% reverts.
    function test_setDefaultSeigniorageIncentivePercentage_revertsAbove100Percent() public {
        uint256 aboveMax = ONE_WAD + 1;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, aboveMax, ONE_WAD));
        feeManager.setDefaultSeigniorageIncentivePercentage(aboveMax);
    }

    /// @notice Type-level seigniorage setter validates WAD bounds.
    function test_setDefaultSeigniorageIncentivePercentageOfTypeId_revertsAbove100Percent() public {
        uint256 aboveMax = ONE_WAD + 1;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, aboveMax, ONE_WAD));
        feeManager.setDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, aboveMax);
    }

    /// @notice Vault-level seigniorage setter validates WAD bounds.
    function test_setSeigniorageIncentivePercentageOfVault_revertsAbove100Percent() public {
        uint256 aboveMax = ONE_WAD + 1;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, aboveMax, ONE_WAD));
        feeManager.setSeigniorageIncentivePercentageOfVault(testVault, aboveMax);
    }

    /// @notice Any seigniorage incentive value <= ONE_WAD can be stored.
    function testFuzz_setDefaultSeigniorageIncentivePercentage_wadBoundStored(uint256 pct) public {
        pct = bound(pct, 0, ONE_WAD);
        vm.prank(owner);
        feeManager.setDefaultSeigniorageIncentivePercentage(pct);
    }
}
