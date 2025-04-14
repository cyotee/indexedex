// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
    DEFAULT_BOND_MIN_TERM,
    DEFAULT_BOND_MAX_TERM
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title BondTermsDefaults_Test
 * @notice Validates that bond bonus default constants are correctly scaled (WAD: 1e18 = 100%).
 * @dev Regression test for IDXEX-030 where defaults were 100x too large (5e18/10e18 vs 5e16/1e17).
 */
contract BondTermsDefaults_Test is IndexedexTest {
    /* ---------------------------------------------------------------------- */
    /*                    US-030.1: Constant Value Checks                      */
    /* ---------------------------------------------------------------------- */

    function test_minBonusPercentage_equals5Percent() public pure {
        // 5% in WAD = 0.05 * 1e18 = 5e16
        assertEq(DEFAULT_BOND_MIN_BONUS_PERCENTAGE, 5e16, "min bonus should be 5e16 (5%)");
    }

    function test_maxBonusPercentage_equals10Percent() public pure {
        // 10% in WAD = 0.10 * 1e18 = 1e17
        assertEq(DEFAULT_BOND_MAX_BONUS_PERCENTAGE, 1e17, "max bonus should be 1e17 (10%)");
    }

    function test_bonusPercentages_lessThanOneWad() public pure {
        // Bonus percentages must be < 100% (< ONE_WAD) for sane economics
        assertLt(DEFAULT_BOND_MIN_BONUS_PERCENTAGE, ONE_WAD, "min bonus must be < 100%");
        assertLt(DEFAULT_BOND_MAX_BONUS_PERCENTAGE, ONE_WAD, "max bonus must be < 100%");
    }

    function test_minBonus_lessThanOrEqualMaxBonus() public pure {
        assertLe(DEFAULT_BOND_MIN_BONUS_PERCENTAGE, DEFAULT_BOND_MAX_BONUS_PERCENTAGE, "min bonus must be <= max bonus");
    }

    /* ---------------------------------------------------------------------- */
    /*            US-030.1: Manager Init Sets Correct Defaults                 */
    /* ---------------------------------------------------------------------- */

    function test_managerInit_setsCorrectDefaultBondTerms() public view {
        BondTerms memory terms = IVaultFeeOracleQuery(address(indexedexManager)).defaultBondTerms();

        assertEq(terms.minLockDuration, DEFAULT_BOND_MIN_TERM, "minLockDuration mismatch");
        assertEq(terms.maxLockDuration, DEFAULT_BOND_MAX_TERM, "maxLockDuration mismatch");
        assertEq(terms.minBonusPercentage, 5e16, "init minBonusPercentage should be 5%");
        assertEq(terms.maxBonusPercentage, 1e17, "init maxBonusPercentage should be 10%");
    }

    /* ---------------------------------------------------------------------- */
    /*          US-030.2: Bonus Multiplier Calculation Validation              */
    /* ---------------------------------------------------------------------- */

    function test_bonusMultiplier_atMinDuration_is105Percent() public pure {
        // At minimum lock duration, bonus = minBonusPercentage
        // multiplier = ONE_WAD + minBonusPercentage = 1e18 + 5e16 = 1.05e18
        uint256 multiplier = ONE_WAD + DEFAULT_BOND_MIN_BONUS_PERCENTAGE;
        assertEq(multiplier, 1.05e18, "min duration multiplier should be 1.05x (105%)");
    }

    function test_bonusMultiplier_atMaxDuration_is110Percent() public pure {
        // At maximum lock duration, bonus = maxBonusPercentage
        // multiplier = ONE_WAD + maxBonusPercentage = 1e18 + 1e17 = 1.1e18
        uint256 multiplier = ONE_WAD + DEFAULT_BOND_MAX_BONUS_PERCENTAGE;
        assertEq(multiplier, 1.1e18, "max duration multiplier should be 1.1x (110%)");
    }

    function test_effectiveShares_atMaxBonus_correctlyScaled() public pure {
        // Simulate: 1000e18 shares locked for max duration
        uint256 originalShares = 1000e18;
        uint256 bonusMultiplier = ONE_WAD + DEFAULT_BOND_MAX_BONUS_PERCENTAGE;
        uint256 effectiveShares = (originalShares * bonusMultiplier) / ONE_WAD;

        // Expected: 1000e18 * 1.1 = 1100e18
        assertEq(effectiveShares, 1100e18, "effective shares should be 1.1x original");
    }

    /* ---------------------------------------------------------------------- */
    /*                US-030.2: Overflow Edge Case                             */
    /* ---------------------------------------------------------------------- */

    function test_bonusMultiplier_noOverflow_withLargeShares() public pure {
        // Use a very large share amount to ensure no overflow
        // type(uint128).max is a reasonable upper bound for shares in production
        uint256 largeShares = type(uint128).max;
        uint256 bonusMultiplier = ONE_WAD + DEFAULT_BOND_MAX_BONUS_PERCENTAGE;

        // This must not overflow
        uint256 effectiveShares = (largeShares * bonusMultiplier) / ONE_WAD;

        // Verify result is 110% of original
        assertGt(effectiveShares, largeShares, "effective shares must exceed original");
        assertEq(effectiveShares, (largeShares * 1.1e18) / ONE_WAD, "effective shares must equal 1.1x original");
    }
}
