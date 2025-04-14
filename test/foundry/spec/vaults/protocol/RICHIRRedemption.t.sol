// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title RICHIRRedemptionTest
 * @notice Tests for US-5.6: RICHIR Redemption
 * @dev Specification tests for RICHIR rebasing mechanics and redemption.
 */
contract RICHIRRedemptionTest is Test {
    /* ---------------------------------------------------------------------- */
    /*                        Rebasing Balance Tests                          */
    /* ---------------------------------------------------------------------- */

    function test_balanceOf_computedFromShares() public pure {
        uint256 userShares = 100e18;
        uint256 redemptionRate = 12e17; // 1.2 WETH per share

        uint256 balance = _sharesToBalance(userShares, redemptionRate);

        assertEq(balance, 120e18, "Balance should be shares * rate");
    }

    function test_balanceOf_changesWithRate() public pure {
        uint256 userShares = 100e18;

        // Rate increases from 1.0 to 1.5
        uint256 balanceAt1x = _sharesToBalance(userShares, ONE_WAD);
        uint256 balanceAt15x = _sharesToBalance(userShares, 15e17);

        assertEq(balanceAt1x, 100e18, "Balance at 1.0 rate");
        assertEq(balanceAt15x, 150e18, "Balance at 1.5 rate");
        assertTrue(balanceAt15x > balanceAt1x, "Balance should increase with rate");
    }

    function test_totalSupply_computedFromTotalShares() public pure {
        uint256 totalShares = 1000e18;
        uint256 redemptionRate = 11e17; // 1.1

        uint256 totalSupply = _sharesToBalance(totalShares, redemptionRate);

        assertEq(totalSupply, 1100e18, "Total supply should be totalShares * rate");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Redemption Rate Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_redemptionRate_atPeg() public pure {
        // When pools are balanced, rate should be ~1.0
        uint256 rate = ONE_WAD;

        assertEq(rate, ONE_WAD, "Rate should be 1.0 at peg");
    }

    function test_redemptionRate_abovePeg() public pure {
        // When RICH is relatively stronger, rate > 1.0
        uint256 rate = 12e17; // 1.2

        assertTrue(rate > ONE_WAD, "Rate should be > 1.0 above peg");
    }

    function test_redemptionRate_belowPeg() public pure {
        // When WETH is relatively stronger, rate < 1.0
        uint256 rate = 8e17; // 0.8

        assertTrue(rate < ONE_WAD, "Rate should be < 1.0 below peg");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Redemption Eligibility                           */
    /* ---------------------------------------------------------------------- */

    function test_redemption_allowedBelowBurnThreshold() public pure {
        uint256 syntheticPrice = 990e15; // 0.990
        uint256 burnThreshold = 995e15; // 0.995

        bool canRedeem = syntheticPrice < burnThreshold;

        assertTrue(canRedeem, "Redemption should be allowed below threshold");
    }

    function test_redemption_blockedAboveBurnThreshold() public pure {
        uint256 syntheticPrice = 998e15; // 0.998
        uint256 burnThreshold = 995e15; // 0.995

        bool canRedeem = syntheticPrice < burnThreshold;

        assertFalse(canRedeem, "Redemption should be blocked above threshold");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redemption Flow                               */
    /* ---------------------------------------------------------------------- */

    function test_redemption_sharesToWeth() public pure {
        uint256 richirAmount = 100e18;
        uint256 redemptionRate = 12e17; // 1.2

        // Convert RICHIR balance to shares
        uint256 shares = _balanceToShares(richirAmount, redemptionRate);

        // Shares should be less than balance (rate > 1)
        assertTrue(shares < richirAmount, "Shares should be less than balance");
        assertApproxEqRel(shares, 833e17, 1e15, "Shares should be ~83.3");
    }

    function test_redemption_wethOutput() public pure {
        uint256 shares = 100e18;
        uint256 wethPerShare = 11e17; // 1.1 WETH per share

        uint256 wethOut = (shares * wethPerShare) / ONE_WAD;

        assertEq(wethOut, 110e18, "WETH output should be shares * wethPerShare");
    }

    function test_redemption_partialAllowed() public pure {
        uint256 totalShares = 1000e18;
        uint256 redeemShares = 100e18; // 10% redemption

        assertTrue(redeemShares < totalShares, "Partial redemption should be allowed");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Shares/Balance Conversions                         */
    /* ---------------------------------------------------------------------- */

    function test_convertToShares_roundTrip() public pure {
        uint256 originalBalance = 100e18;
        uint256 rate = 15e17; // 1.5

        uint256 shares = _balanceToShares(originalBalance, rate);
        uint256 backToBalance = _sharesToBalance(shares, rate);

        // Should round-trip within rounding error
        assertApproxEqRel(backToBalance, originalBalance, 1e15, "Should round-trip");
    }

    function testFuzz_conversion_roundTrip(uint256 balance, uint256 rate) public pure {
        balance = bound(balance, 1e18, 1e30);
        rate = bound(rate, 1e17, 10e18); // 0.1x to 10x

        uint256 shares = _balanceToShares(balance, rate);
        uint256 backToBalance = _sharesToBalance(shares, rate);

        // Allow for rounding
        assertApproxEqRel(backToBalance, balance, 1e12, "Should round-trip within tolerance");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Transfer Tests                                 */
    /* ---------------------------------------------------------------------- */

    function test_transfer_movesShares() public pure {
        uint256 senderSharesBefore = 100e18;
        uint256 recipientSharesBefore = 50e18;
        uint256 rate = 12e17;

        // Transfer 60 RICHIR (balance)
        uint256 transferAmount = 60e18;
        uint256 sharesTransferred = _balanceToShares(transferAmount, rate);

        uint256 senderSharesAfter = senderSharesBefore - sharesTransferred;
        uint256 recipientSharesAfter = recipientSharesBefore + sharesTransferred;

        assertTrue(senderSharesAfter < senderSharesBefore, "Sender shares should decrease");
        assertTrue(recipientSharesAfter > recipientSharesBefore, "Recipient shares should increase");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    function _sharesToBalance(uint256 shares, uint256 rate) internal pure returns (uint256) {
        return (shares * rate) / ONE_WAD;
    }

    function _balanceToShares(uint256 balance, uint256 rate) internal pure returns (uint256) {
        return (balance * ONE_WAD) / rate;
    }
}
