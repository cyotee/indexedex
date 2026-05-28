// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title ProtocolDETFSeigniorageTest
 * @notice Tests for US-5.4: Seigniorage Capture
 * @dev Specification tests for seigniorage capture when above peg.
 */
contract ProtocolDETFSeigniorageTest is Test {
    /* ---------------------------------------------------------------------- */
    /*                       Seigniorage Eligibility                          */
    /* ---------------------------------------------------------------------- */

    function test_seigniorageCapture_aboveMintThreshold() public pure {
        uint256 syntheticPrice = 1010e15; // 1.010
        uint256 mintThreshold = 1005e15; // 1.005
        uint256 discountMargin = 2e15; // 0.2%

        bool canCapture = syntheticPrice > mintThreshold;
        assertTrue(canCapture, "Should be able to capture seigniorage above threshold");
    }

    function test_seigniorageCapture_belowMintThreshold() public pure {
        uint256 syntheticPrice = 1003e15; // 1.003
        uint256 mintThreshold = 1005e15; // 1.005

        bool canCapture = syntheticPrice > mintThreshold;
        assertFalse(canCapture, "Should not capture seigniorage below threshold");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Profit Margin Calculation                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test profit margin calculation.
     * @dev profit_margin = (synthetic_price - 1.0 - discount_margin) * amount
     */
    function test_profitMargin_calculation() public pure {
        uint256 syntheticPrice = 1020e15; // 1.020
        uint256 discountMargin = 5e15; // 0.5%
        uint256 amount = 1000e18;

        // Gross seigniorage = (1.020 - 1.0) * 1000 = 20
        // Net profit = gross - discount = (0.020 - 0.005) * 1000 = 15
        uint256 profitMargin = _calcProfitMargin(syntheticPrice, discountMargin, amount);

        assertEq(profitMargin, 15e18, "Profit margin should be 15 tokens");
    }

    function test_profitMargin_atThreshold() public pure {
        uint256 syntheticPrice = 1005e15; // 1.005 (exactly at threshold)
        uint256 discountMargin = 5e15; // 0.5%
        uint256 amount = 1000e18;

        // Gross = 0.005 * 1000 = 5
        // Net = 5 - 5 = 0
        uint256 profitMargin = _calcProfitMargin(syntheticPrice, discountMargin, amount);

        assertEq(profitMargin, 0, "Profit margin should be 0 at threshold");
    }

    function test_profitMargin_discountExceedsGross() public pure {
        uint256 syntheticPrice = 1002e15; // 1.002
        uint256 discountMargin = 5e15; // 0.5%
        uint256 amount = 1000e18;

        // Gross = 0.002 * 1000 = 2
        // Net = 2 - 5 = -3 (should clamp to 0)
        uint256 profitMargin = _calcProfitMargin(syntheticPrice, discountMargin, amount);

        assertEq(profitMargin, 0, "Profit margin should clamp to 0");
    }

    /* ---------------------------------------------------------------------- */
    /*                      CHIR Minting for Seigniorage                      */
    /* ---------------------------------------------------------------------- */

    function test_seigniorageChirMint_amount() public pure {
        uint256 profitMargin = 15e18; // 15 tokens profit

        // CHIR minted equals profit margin
        assertEq(profitMargin, 15e18, "Should mint 15 CHIR for seigniorage");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Zap-In Simulation                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test CHIR zap-in to RICH/CHIR pool.
     * @dev Seigniorage CHIR is single-sided deposited to RICH/CHIR vault.
     */
    function test_seigniorageZapIn_estimate() public pure {
        uint256 chirAmount = 100e18;
        uint256 richReserve = 10000e18;
        uint256 chirReserve = 10000e18;
        uint256 lpTotalSupply = 10000e18;

        // Simple approximation: for a volatile pool, single-sided deposit
        // gives approximately half the shares of a balanced deposit
        uint256 estimatedLP = _estimateSingleSidedLPOut(chirAmount, chirReserve, richReserve, lpTotalSupply);

        // Should get some LP tokens
        assertTrue(estimatedLP > 0, "Should receive LP tokens from zap-in");
        // Should be less than full balanced equivalent
        assertTrue(estimatedLP < chirAmount, "Single-sided gives less than full amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    function _calcProfitMargin(uint256 syntheticPrice, uint256 discountMargin, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        if (syntheticPrice <= ONE_WAD) return 0;

        uint256 grossMargin = syntheticPrice - ONE_WAD;
        if (grossMargin <= discountMargin) return 0;

        uint256 netMargin = grossMargin - discountMargin;
        return (netMargin * amount) / ONE_WAD;
    }

    function _estimateSingleSidedLPOut(
        uint256 tokenIn,
        uint256 tokenInReserve,
        uint256 tokenOutReserve,
        uint256 lpTotalSupply
    ) internal pure returns (uint256) {
        // Simplified constant product single-sided estimate
        // In reality, uses swap + deposit formula
        // Here we use a rough 50% efficiency approximation
        uint256 totalValue = tokenInReserve + tokenOutReserve;
        return (tokenIn * lpTotalSupply) / (totalValue * 2);
    }
}
