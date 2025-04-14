// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    DEFAULT_VAULT_USAGE_FEE,
    DEFAULT_DEX_FEE,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
    DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title VaultFeeOracle_Units_Test
 * @notice Verifies that fee constants and oracle values are consistent with WAD scale (1e18 = 100%).
 * @notice Also tests the zero-value sentinel fallback behavior.
 */
contract VaultFeeOracle_Units_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
    }

    /* ---------------------------------------------------------------------- */
    /*                     WAD Scale Constant Verification                    */
    /* ---------------------------------------------------------------------- */

    function test_defaultUsageFee_isWADScale() public pure {
        // DEFAULT_VAULT_USAGE_FEE = 1e15 should represent 0.1%
        assertEq(DEFAULT_VAULT_USAGE_FEE, 1e15);
        // 0.1% of 1e18 (WAD) = 1e15
        assertEq(DEFAULT_VAULT_USAGE_FEE, ONE_WAD / 1000);
    }

    function test_defaultDexFee_isWADScale() public pure {
        // DEFAULT_DEX_FEE = 5e16 should represent 5%
        assertEq(DEFAULT_DEX_FEE, 5e16);
        // 5% of 1e18 (WAD) = 5e16
        assertEq(DEFAULT_DEX_FEE, ONE_WAD * 5 / 100);
    }

    function test_defaultBondPercentages_areWADScale() public pure {
        // DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e16 should be 5%
        assertEq(DEFAULT_BOND_MIN_BONUS_PERCENTAGE, 5e16);
        assertEq(DEFAULT_BOND_MIN_BONUS_PERCENTAGE, ONE_WAD * 5 / 100);

        // DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 1e17 should be 10%
        assertEq(DEFAULT_BOND_MAX_BONUS_PERCENTAGE, 1e17);
        assertEq(DEFAULT_BOND_MAX_BONUS_PERCENTAGE, ONE_WAD / 10);
    }

    function test_defaultSeignioragePercentage_isWADScale() public pure {
        // DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE = 5e17 should be 50%
        assertEq(DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE, 5e17);
        assertEq(DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE, ONE_WAD / 2);
    }

    /* ---------------------------------------------------------------------- */
    /*                   Oracle Returns Expected Defaults                     */
    /* ---------------------------------------------------------------------- */

    function test_oracleDefaultUsageFee_matchesConstant() public view {
        assertEq(feeOracle.defaultUsageFee(), DEFAULT_VAULT_USAGE_FEE);
    }

    function test_oracleDefaultDexSwapFee_matchesConstant() public view {
        assertEq(feeOracle.defaultDexSwapFee(), DEFAULT_DEX_FEE);
    }

    function test_oracleDefaultBondTerms_matchConstants() public view {
        BondTerms memory terms = feeOracle.defaultBondTerms();
        assertEq(terms.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(terms.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
    }

    function test_oracleDefaultSeignioragePercentage_matchesConstant() public view {
        assertEq(feeOracle.defaultSeigniorageIncentivePercentage(), DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Fee Calculation Produces Expected Result            */
    /* ---------------------------------------------------------------------- */

    function test_usageFeeCalculation_producesCorrectResult() public pure {
        // With 0.1% usage fee (1e15 WAD), applying to 1000 tokens should yield 1 token
        uint256 amount = 1000e18; // 1000 tokens
        uint256 fee = BetterMath._percentageOfWAD(amount, DEFAULT_VAULT_USAGE_FEE);
        // 1000e18 * 1e15 / 1e18 = 1e18 = 1 token
        assertEq(fee, 1e18);
    }

    function test_dexFeeCalculation_producesCorrectResult() public pure {
        // With 5% dex fee (5e16 WAD), applying to 100 tokens should yield 5 tokens
        uint256 amount = 100e18; // 100 tokens
        uint256 fee = BetterMath._percentageOfWAD(amount, DEFAULT_DEX_FEE);
        // 100e18 * 5e16 / 1e18 = 5e18 = 5 tokens
        assertEq(fee, 5e18);
    }

    function test_seigniorageFeeCalculation_producesCorrectResult() public pure {
        // With 50% seigniorage (5e17 WAD), applying to 200 tokens should yield 100 tokens
        uint256 amount = 200e18;
        uint256 fee = BetterMath._percentageOfWAD(amount, DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE);
        assertEq(fee, 100e18);
    }

    /* ---------------------------------------------------------------------- */
    /*              Zero-Value Sentinel: Fallback to Default                   */
    /* ---------------------------------------------------------------------- */

    function test_usageFeeOfVault_fallsBackToDefault_whenUnset() public view {
        // Query fee for a vault that has no override set — should return global default
        address unknownVault = address(0xdead);
        uint256 fee = feeOracle.usageFeeOfVault(unknownVault);
        assertEq(fee, DEFAULT_VAULT_USAGE_FEE);
    }

    function test_dexSwapFeeOfVault_fallsBackToDefault_whenUnset() public view {
        // Query fee for a vault that has no override set — should return global default
        address unknownVault = address(0xdead);
        uint256 fee = feeOracle.dexSwapFeeOfVault(unknownVault);
        assertEq(fee, DEFAULT_DEX_FEE);
    }

    function test_usageFeeOfVault_returnsOverride_whenSet() public {
        address testVault = makeAddr("testVault");
        uint256 customFee = 2e16; // 2%

        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, customFee);

        uint256 fee = feeOracle.usageFeeOfVault(testVault);
        assertEq(fee, customFee);
    }

    function test_dexSwapFeeOfVault_returnsOverride_whenSet() public {
        address testVault = makeAddr("testVault");
        uint256 customFee = 3e16; // 3%

        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, customFee);

        uint256 fee = feeOracle.dexSwapFeeOfVault(testVault);
        assertEq(fee, customFee);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Global Default Can Be Updated                     */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultUsageFee_updatesOracleValue() public {
        uint256 newFee = 5e15; // 0.5%

        vm.prank(owner);
        feeManager.setDefaultUsageFee(newFee);

        assertEq(feeOracle.defaultUsageFee(), newFee);
    }

    function test_setDefaultDexSwapFee_updatesOracleValue() public {
        uint256 newFee = 1e17; // 10%

        vm.prank(owner);
        feeManager.setDefaultDexSwapFee(newFee);

        assertEq(feeOracle.defaultDexSwapFee(), newFee);
    }
}
