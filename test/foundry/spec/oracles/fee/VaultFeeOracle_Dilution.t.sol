// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {
    DEFAULT_VAULT_USAGE_FEE,
    DEFAULT_DEX_FEE,
    DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title VaultFeeOracle_Dilution_Test
 * @notice Tests that quantify the economic impact of fee parameter values on vault operations.
 * @dev Vault fees apply via BetterMath._percentageOfWAD(yield, feePercentage) which computes
 *      (yield * feePercentage) / 1e18. The result represents tokens extracted as protocol fees
 *      (either minted as shares or transferred as LP tokens, depending on vault type).
 *
 *      These tests verify the oracle stores the right values and document the mathematical
 *      impact at boundary conditions (0%, 100%, and extreme values).
 */
contract VaultFeeOracle_Dilution_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;

    address testVault;

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
        testVault = makeAddr("testVault");
    }

    /* ---------------------------------------------------------------------- */
    /*               US-IDXEX-036.3: 0% Fee → No Dilution                     */
    /* ---------------------------------------------------------------------- */

    /// @notice When usage fee is 0 (sentinel), vault falls back to global default.
    /// @dev 0 is the "unset" sentinel. There is no way to set an explicit 0% fee.
    ///      This documents that the protocol always extracts some fee via the default.
    function test_usageFee_zeroSentinel_noExplicitZeroFee() public view {
        // A vault with no override returns the global default, not 0
        uint256 fee = feeOracle.usageFeeOfVault(testVault);
        assertEq(fee, DEFAULT_VAULT_USAGE_FEE);
        assertGt(fee, 0, "Cannot achieve true 0% fee via oracle - sentinel triggers fallback");
    }

    /// @notice Mathematical impact: 0% fee produces zero extracted tokens.
    /// @dev Even though the oracle can't return 0% via fallback, we verify the math
    ///      to document that the formula handles zero correctly (no division by zero).
    function test_feeCalculation_zeroPercent_noExtraction() public pure {
        uint256 yield = 1000e18; // 1000 tokens of yield
        uint256 zeroPct = 0; // 0%

        uint256 feeExtracted = BetterMath._percentageOfWAD(yield, zeroPct);
        assertEq(feeExtracted, 0, "0% fee should extract nothing");
    }

    /// @notice With global default set to minimum (1 wei in WAD), near-zero fee extraction.
    function test_usageFee_minimumNonZero_negligibleExtraction() public {
        // Set global default to smallest possible non-zero WAD value
        vm.prank(owner);
        feeManager.setDefaultUsageFee(1); // 1 wei = 1e-18 = 0.0000000000000001%

        uint256 yield = 1000e18; // 1000 tokens
        uint256 fee = feeOracle.usageFeeOfVault(testVault);
        assertEq(fee, 1);

        uint256 feeExtracted = BetterMath._percentageOfWAD(yield, fee);
        // (1000e18 * 1) / 1e18 = 1000 wei = 0.000000000000001 tokens
        assertEq(feeExtracted, 1000);
    }

    /* ---------------------------------------------------------------------- */
    /*             US-IDXEX-036.3: 100% Fee → Maximum Dilution                */
    /* ---------------------------------------------------------------------- */

    /// @notice 100% usage fee means all yield is extracted as protocol fee.
    function test_usageFee_100Percent_allYieldExtracted() public {
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, ONE_WAD); // 100%

        uint256 fee = feeOracle.usageFeeOfVault(testVault);
        assertEq(fee, ONE_WAD);

        uint256 yield = 500e18; // 500 tokens
        uint256 feeExtracted = BetterMath._percentageOfWAD(yield, fee);
        assertEq(feeExtracted, yield, "100% fee should extract entire yield");
    }

    /// @notice 100% usage fee on 1 token of yield.
    function test_usageFee_100Percent_singleToken() public {
        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, ONE_WAD);

        uint256 yield = 1e18; // 1 token
        uint256 fee = feeOracle.usageFeeOfVault(testVault);
        uint256 feeExtracted = BetterMath._percentageOfWAD(yield, fee);
        assertEq(feeExtracted, 1e18, "100% fee on 1 token should extract exactly 1 token");
    }

    /* ---------------------------------------------------------------------- */
    /*          US-IDXEX-036.3: Out-of-Range → Revert (Bounds Enforced)       */
    /* ---------------------------------------------------------------------- */

    /// @notice Usage fee above 100% is rejected by on-chain bounds validation.
    function test_usageFee_above100Percent_reverts() public {
        uint256 fee200Pct = 2 * ONE_WAD; // 200%
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, fee200Pct, ONE_WAD));
        feeManager.setUsageFeeOfVault(testVault, fee200Pct);
    }

    /// @notice Very large fee percentage can cause overflow in multiplication.
    /// @dev BetterMath._percentageOfWAD computes (total * percentage) / 1e18.
    ///      If total * percentage > type(uint256).max, the multiplication reverts.
    ///      We use a helper contract to make this an external call so vm.expectRevert works.
    function test_usageFee_extremeValue_overflowOnLargeYield() public {
        PercentageCalculator calc = new PercentageCalculator();

        // uint256.max ≈ 1.16e77, so we need total * pct > 1.16e77
        // Using type(uint256).max as fee and any yield > 1e18 guarantees overflow
        uint256 extremeFee = type(uint256).max;

        // Yield of 2 tokens with max fee overflows: (2e18 * ~1.16e77) > type(uint256).max
        vm.expectRevert();
        calc.percentageOfWAD(2e18, extremeFee);
    }

    /* ---------------------------------------------------------------------- */
    /*                   DEX Swap Fee Dilution Impact                          */
    /* ---------------------------------------------------------------------- */

    /// @notice 0% swap fee (sentinel) falls back to global default.
    function test_dexSwapFee_zeroSentinel_fallsBackToDefault() public view {
        uint256 fee = feeOracle.dexSwapFeeOfVault(testVault);
        assertEq(fee, DEFAULT_DEX_FEE);
        assertGt(fee, 0);
    }

    /// @notice 100% swap fee extracts all swap value.
    function test_dexSwapFee_100Percent_allSwapValueExtracted() public {
        vm.prank(owner);
        feeManager.setVaultDexSwapFee(testVault, ONE_WAD);

        uint256 swapAmount = 100e18;
        uint256 fee = feeOracle.dexSwapFeeOfVault(testVault);
        uint256 feeExtracted = BetterMath._percentageOfWAD(swapAmount, fee);
        assertEq(feeExtracted, swapAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Default Fee Impact Quantification                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Documents the dilution impact of each default fee parameter.
    function test_defaultFees_impactOnStandardYield() public pure {
        uint256 yield = 1000e18; // 1000 tokens

        // Usage fee: 0.1% → 1 token extracted per 1000 tokens yield
        uint256 usageFeeExtracted = BetterMath._percentageOfWAD(yield, DEFAULT_VAULT_USAGE_FEE);
        assertEq(usageFeeExtracted, 1e18, "0.1% usage fee: 1 token per 1000");

        // DEX swap fee: 5% → 50 tokens extracted per 1000 tokens swapped
        uint256 dexFeeExtracted = BetterMath._percentageOfWAD(yield, DEFAULT_DEX_FEE);
        assertEq(dexFeeExtracted, 50e18, "5% dex fee: 50 tokens per 1000");

        // Seigniorage incentive: 50% → 500 tokens incentive per 1000 tokens
        uint256 seigniorageExtracted = BetterMath._percentageOfWAD(yield, DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE);
        assertEq(seigniorageExtracted, 500e18, "50% seigniorage: 500 tokens per 1000");
    }

    /// @notice feeTo address is correctly paired with fee values.
    function test_usageFeeAndFeeTo_returnsPairedValues() public view {
        (IFeeCollectorProxy feeTo_, uint256 usageFee_) = feeOracle.usageFeeAndFeeToOfVault(testVault);
        assertEq(address(feeTo_), address(feeCollector));
        assertEq(usageFee_, DEFAULT_VAULT_USAGE_FEE);
    }

    /// @notice dexSwapFee and feeTo are correctly paired.
    function test_dexSwapFeeAndFeeTo_returnsPairedValues() public view {
        (IFeeCollectorProxy feeTo_, uint256 swapFee_) = feeOracle.dexSwapFeeAndFeeToOfVault(testVault);
        assertEq(address(feeTo_), address(feeCollector));
        assertEq(swapFee_, DEFAULT_DEX_FEE);
    }

    /* ---------------------------------------------------------------------- */
    /*                     Fuzz: Dilution Proportionality                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Fee extraction is always proportional: fee = yield * pct / 1e18.
    function testFuzz_feeExtraction_isProportional(uint128 yieldRaw, uint128 pctRaw) public pure {
        uint256 yield = uint256(yieldRaw);
        uint256 pct = uint256(pctRaw);

        // Avoid overflow: yield * pct must fit in uint256
        // uint128 * uint128 < uint256.max, so this is always safe
        uint256 fee = BetterMath._percentageOfWAD(yield, pct);

        // fee should equal (yield * pct) / 1e18
        assertEq(fee, (yield * pct) / 1e18);
    }

    /// @notice Setting a vault override changes the dilution for that vault only.
    function testFuzz_vaultOverride_isolatedImpact(uint256 customFee) public {
        customFee = bound(customFee, 1, ONE_WAD); // 0 is sentinel, >1e18 reverts

        address otherVault = makeAddr("otherVault");

        vm.prank(owner);
        feeManager.setUsageFeeOfVault(testVault, customFee);

        // testVault uses the override
        assertEq(feeOracle.usageFeeOfVault(testVault), customFee);

        // otherVault still uses global default
        assertEq(feeOracle.usageFeeOfVault(otherVault), DEFAULT_VAULT_USAGE_FEE);
    }
}

/// @notice Helper contract to make BetterMath library calls external,
///         allowing vm.expectRevert() to catch arithmetic overflow.
contract PercentageCalculator {
    function percentageOfWAD(uint256 total, uint256 percentage) external pure returns (uint256) {
        return BetterMath._percentageOfWAD(total, percentage);
    }
}
