// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CrossVersionLoopService} from
    "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";

/**
 * @title CrossVersionLoopService_Test
 * @notice Unit tests for the pure carry-math primitives (PRD decisions 28, 29, 33).
 * @dev Pure functions - no fork needed. Validates the formulas the loop/preview depend on.
 */
contract CrossVersionLoopService_Test is Test {
    uint256 constant RAY = 1e27;
    uint256 constant WAD = 1e18;

    /* ------------------------------- usdValue ------------------------------- */

    function test_usdValue_usdc6dp_at_1usd() public pure {
        // 1000 USDC (6dp) at price 1e8 (priceUnit 1e8) -> $1000 scaled to 1e18.
        uint256 v = CrossVersionLoopService.usdValue(1000e6, 6, 1e8, 1e8);
        assertEq(v, 1000e18, "1000 USDC should be $1000 in WAD");
    }

    function test_usdValue_weth18dp_at_3000usd() public pure {
        // 2 WETH (18dp) at price 3000e8 -> $6000 in WAD.
        uint256 v = CrossVersionLoopService.usdValue(2e18, 18, 3000e8, 1e8);
        assertEq(v, 6000e18, "2 WETH at $3000 should be $6000 in WAD");
    }

    /* -------------------------- deriveV4SupplyRate -------------------------- */

    function test_deriveV4SupplyRate_basic() public pure {
        // drawnRate 10% (1e26), 50% utilization, 10% liquidityFee -> 0.10*0.50*0.90 = 4.5%.
        uint256 r = CrossVersionLoopService.deriveV4SupplyRate(1e26, 100, 100, 1000);
        assertEq(r, 45e24, "supply rate should be 4.5% RAY"); // 0.045 * 1e27 = 4.5e25 = 45e24
    }

    function test_deriveV4SupplyRate_zeroLiquidityAndOwed() public pure {
        assertEq(CrossVersionLoopService.deriveV4SupplyRate(1e26, 0, 0, 1000), 0, "no util -> 0");
    }

    /* ------------------------ effectiveV4BorrowRate ------------------------- */

    function test_effectiveV4BorrowRate_addsPremium() public pure {
        // base 10% + 20% premium -> 12%.
        uint256 r = CrossVersionLoopService.effectiveV4BorrowRate(1e26, 2000);
        assertEq(r, 12e25, "effective borrow rate 12% RAY");
    }

    /* -------------------------------- netCarry ------------------------------ */

    function test_netCarry_positiveWhenSupplyExceedsBorrow() public pure {
        // both legs: supply 6% vs borrow 5% on $1000 each -> +$20/yr (in WAD).
        int256 nc = CrossVersionLoopService.netCarry(6e25, 5e25, 1000e18, 6e25, 5e25, 1000e18);
        assertEq(nc, 20e18, "net carry should be +$20 WAD/yr");
    }

    function test_netCarry_negativeWhenBorrowExceedsSupply() public pure {
        int256 nc = CrossVersionLoopService.netCarry(4e25, 5e25, 1000e18, 4e25, 5e25, 1000e18);
        assertEq(nc, -20e18, "net carry should be -$20 WAD/yr");
    }

    /* ------------------------------ LTV gates ------------------------------- */

    function test_projectedLtvBps() public pure {
        assertEq(CrossVersionLoopService.projectedLtvBps(1000e18, 800e18), 8000, "80% LTV");
        assertEq(CrossVersionLoopService.projectedLtvBps(0, 800e18), 0, "no collateral -> 0");
    }

    function test_withinTargetLtv_boundary() public pure {
        assertTrue(CrossVersionLoopService.withinTargetLtv(8000, 9000, 100), "8000+100<=9000");
        assertFalse(CrossVersionLoopService.withinTargetLtv(8950, 9000, 100), "8950+100>9000");
        assertTrue(CrossVersionLoopService.withinTargetLtv(8900, 9000, 100), "exact boundary ok");
    }

    /* ------------------------------- shares -------------------------------- */

    function test_sharesForDeposit_firstDeposit_oneToOne() public pure {
        // First deposit (no supply): shares == deposit value.
        assertEq(CrossVersionLoopService.sharesForDeposit(0, 0, 1000e18), 1000e18, "first deposit 1:1");
    }

    function test_sharesForDeposit_proportional() public pure {
        // NAV 1000, supply 1000. A 500-value deposit mints 500 shares (proportional).
        assertEq(CrossVersionLoopService.sharesForDeposit(1000e18, 1000e18, 500e18), 500e18, "proportional");
        // If NAV grew to 2000 with same supply 1000, a 500 deposit mints 250 (price doubled).
        assertEq(CrossVersionLoopService.sharesForDeposit(2000e18, 1000e18, 500e18), 250e18, "priced by NAV");
    }

    function test_assetsForShares_proRata() public pure {
        // NAV 2000, supply 1000: 100 shares -> 200 value.
        assertEq(CrossVersionLoopService.assetsForShares(2000e18, 1000e18, 100e18), 200e18, "pro-rata");
        assertEq(CrossVersionLoopService.assetsForShares(2000e18, 0, 100e18), 0, "no supply -> 0");
    }

    function test_performanceFeeShares_onGrowth() public pure {
        // NAV grew 1000 -> 1100 (+100), 10% fee on growth = $10 of value to feeTo.
        // feeShares = supply * 10 / (1100 - 10) = 1000 * 10 / 1090.
        uint256 fs = CrossVersionLoopService.performanceFeeShares(1100e18, 1000e18, 1000e18, 1000);
        assertEq(fs, (uint256(1000e18) * 10e18) / (1090e18), "perf fee dilution shares");
    }

    function test_performanceFeeShares_noGrowth_zero() public pure {
        assertEq(CrossVersionLoopService.performanceFeeShares(1000e18, 1000e18, 1000e18, 1000), 0, "no growth");
        assertEq(CrossVersionLoopService.performanceFeeShares(900e18, 1000e18, 1000e18, 1000), 0, "loss -> 0");
    }
}
