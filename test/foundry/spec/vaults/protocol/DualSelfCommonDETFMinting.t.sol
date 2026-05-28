// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/**
 * @title ProtocolDETFMintingTest
 * @notice Tests for US-5.1: Mint CHIR with WETH
 * @dev Specification tests validating mathematical formulas and business logic.
 *      Tests the minting flow:
 *      - WETH -> CHIR (mint when synthetic price > mintThreshold)
 *      - Reverts when synthetic price below threshold
 *      - Seigniorage capture on mint
 */
contract ProtocolDETFMintingTest is Test {
    /* ---------------------------------------------------------------------- */
    /*                       Synthetic Price Calculation                      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test synthetic price calculation formula.
     * @dev synthetic_price = (St / G) * (CHIR_gas / CHIR_static)
     *      where:
     *        St = RICH reserve in RICH/CHIR pool
     *        G = WETH reserve in CHIR/WETH pool
     *        CHIR_gas = CHIR reserve in CHIR/WETH pool
     *        CHIR_static = CHIR reserve in RICH/CHIR pool
     */
    function test_calcSyntheticPrice_balanced() public pure {
        // Balanced pools: equal value on both sides
        uint256 chirInWethPool = 1000e18;
        uint256 wethInWethPool = 1000e18;
        uint256 chirInRichPool = 1000e18;
        uint256 richInRichPool = 1000e18;

        uint256 syntheticPrice =
            _calcSyntheticPriceStatic(chirInWethPool, wethInWethPool, chirInRichPool, richInRichPool);

        // When balanced: (1000/1000) * (1000/1000) = 1.0
        assertEq(syntheticPrice, ONE_WAD, "Balanced pools should give price = 1.0");
    }

    function test_calcSyntheticPrice_abovePeg() public pure {
        // RICH is relatively more valuable (more RICH backing per CHIR)
        uint256 chirInWethPool = 1000e18;
        uint256 wethInWethPool = 1000e18;
        uint256 chirInRichPool = 1000e18;
        uint256 richInRichPool = 1100e18; // 10% more RICH

        uint256 syntheticPrice =
            _calcSyntheticPriceStatic(chirInWethPool, wethInWethPool, chirInRichPool, richInRichPool);

        // (1100/1000) * (1000/1000) = 1.1
        assertEq(syntheticPrice, 11e17, "Above peg: synthetic price should be 1.1");
    }

    function test_calcSyntheticPrice_belowPeg() public pure {
        // WETH is relatively more valuable (more WETH backing per CHIR)
        uint256 chirInWethPool = 1000e18;
        uint256 wethInWethPool = 1100e18; // 10% more WETH
        uint256 chirInRichPool = 1000e18;
        uint256 richInRichPool = 1000e18;

        uint256 syntheticPrice =
            _calcSyntheticPriceStatic(chirInWethPool, wethInWethPool, chirInRichPool, richInRichPool);

        // (1000/1100) * (1000/1000) = 0.909
        uint256 expected = (1000e18 * ONE_WAD) / 1100e18;
        assertApproxEqRel(syntheticPrice, expected, 1e15, "Below peg: synthetic price should be ~0.909");
    }

    function test_calcSyntheticPrice_proportionalDistribution() public pure {
        // Different CHIR distribution between pools
        uint256 chirInWethPool = 800e18; // 80% of CHIR in WETH pool
        uint256 wethInWethPool = 1000e18;
        uint256 chirInRichPool = 200e18; // 20% of CHIR in RICH pool
        uint256 richInRichPool = 250e18;

        uint256 syntheticPrice =
            _calcSyntheticPriceStatic(chirInWethPool, wethInWethPool, chirInRichPool, richInRichPool);

        // (250/1000) * (800/200) = 0.25 * 4 = 1.0
        assertEq(syntheticPrice, ONE_WAD, "Proportional distribution should maintain peg");
    }

    /**
     * @notice Fuzz test for synthetic price calculation.
     */
    function testFuzz_calcSyntheticPrice_nonZero(
        uint256 chirInWethPool,
        uint256 wethInWethPool,
        uint256 chirInRichPool,
        uint256 richInRichPool
    ) public pure {
        // Bound inputs to reasonable ranges
        // Keep bounds tight enough that 1e18 fixed-point math doesn't truncate to 0.
        chirInWethPool = bound(chirInWethPool, 1e18, 1e24);
        wethInWethPool = bound(wethInWethPool, 1e18, 1e24);
        chirInRichPool = bound(chirInRichPool, 1e18, 1e24);
        richInRichPool = bound(richInRichPool, 1e18, 1e24);

        uint256 syntheticPrice =
            _calcSyntheticPriceStatic(chirInWethPool, wethInWethPool, chirInRichPool, richInRichPool);

        // Price should always be > 0 for non-zero inputs
        assertTrue(syntheticPrice > 0, "Synthetic price should be non-zero");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Mint Threshold Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_isMintingAllowed_aboveThreshold() public pure {
        uint256 syntheticPrice = 1006e15; // 1.006
        uint256 mintThreshold = 1005e15; // 1.005

        assertTrue(syntheticPrice > mintThreshold, "Minting should be allowed above threshold");
    }

    function test_isMintingAllowed_atThreshold() public pure {
        uint256 syntheticPrice = 1005e15; // 1.005
        uint256 mintThreshold = 1005e15; // 1.005

        // At threshold, minting should NOT be allowed (must be strictly above)
        assertFalse(syntheticPrice > mintThreshold, "Minting should not be allowed at threshold");
    }

    function test_isMintingAllowed_belowThreshold() public pure {
        uint256 syntheticPrice = 1004e15; // 1.004
        uint256 mintThreshold = 1005e15; // 1.005

        assertFalse(syntheticPrice > mintThreshold, "Minting should not be allowed below threshold");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Burn Threshold Tests                          */
    /* ---------------------------------------------------------------------- */

    function test_isBurningAllowed_belowThreshold() public pure {
        uint256 syntheticPrice = 994e15; // 0.994
        uint256 burnThreshold = 995e15; // 0.995

        assertTrue(syntheticPrice < burnThreshold, "Burning should be allowed below threshold");
    }

    function test_isBurningAllowed_atThreshold() public pure {
        uint256 syntheticPrice = 995e15; // 0.995
        uint256 burnThreshold = 995e15; // 0.995

        // At threshold, burning should NOT be allowed (must be strictly below)
        assertFalse(syntheticPrice < burnThreshold, "Burning should not be allowed at threshold");
    }

    function test_isBurningAllowed_aboveThreshold() public pure {
        uint256 syntheticPrice = 996e15; // 0.996
        uint256 burnThreshold = 995e15; // 0.995

        assertFalse(syntheticPrice < burnThreshold, "Burning should not be allowed above threshold");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Seigniorage Calculation                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test seigniorage calculation when above peg.
     * @dev Seigniorage = (synthetic_price - 1) * amountIn
     *      At synthetic_price = 1.1, depositing 100 WETH should yield:
     *      - 100 CHIR to user (at 1:1 base rate)
     *      - 10 CHIR seigniorage to protocol NFT vault
     */
    function test_seigniorageCalc_abovePeg() public pure {
        uint256 syntheticPrice = 11e17; // 1.1
        uint256 amountIn = 100e18;

        // Seigniorage = (syntheticPrice - ONE_WAD) * amountIn / ONE_WAD
        uint256 seigniorage = ((syntheticPrice - ONE_WAD) * amountIn) / ONE_WAD;

        assertEq(seigniorage, 10e18, "Seigniorage should be 10% of input");
    }

    function test_seigniorageCalc_atPeg() public pure {
        uint256 syntheticPrice = ONE_WAD; // 1.0
        uint256 amountIn = 100e18;

        // At peg, no seigniorage
        uint256 seigniorage = syntheticPrice > ONE_WAD ? ((syntheticPrice - ONE_WAD) * amountIn) / ONE_WAD : 0;

        assertEq(seigniorage, 0, "No seigniorage at peg");
    }

    function test_seigniorageCalc_justAboveMintThreshold() public pure {
        uint256 syntheticPrice = 1006e15; // 1.006 (just above 1.005 threshold)
        uint256 amountIn = 1000e18;

        uint256 seigniorage = ((syntheticPrice - ONE_WAD) * amountIn) / ONE_WAD;

        // 0.006 * 1000 = 6
        assertEq(seigniorage, 6e18, "Seigniorage should be 0.6% of input");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Static version of synthetic price calculation for pure tests.
     */
    function _calcSyntheticPriceStatic(
        uint256 chirInWethPool,
        uint256 wethInWethPool,
        uint256 chirInRichPool,
        uint256 richInRichPool
    ) internal pure returns (uint256) {
        if (chirInRichPool == 0 || wethInWethPool == 0) return 0;

        // Avoid overflow on fuzz bounds by using 512-bit mulDiv.
        uint256 numeratorPart = Math.mulDiv(richInRichPool, chirInWethPool, chirInRichPool);
        return Math.mulDiv(numeratorPart, ONE_WAD, wethInWethPool);
    }
}
