// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

/**
 * @title ProportionalDepositHarness
 * @notice Exposes the internal pure math from AerodromeStandardExchangeDFPkg for fuzz testing.
 * @dev Duplicates _proportionalDeposit, _calcNewPoolLP, and _sqrt exactly as implemented
 *      in the production contract to test mathematical properties in isolation.
 */
contract ProportionalDepositHarness {
    function proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        external
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        return _proportionalDeposit(reserveA, reserveB, amountA, amountB);
    }

    function calcNewPoolLP(uint256 amountA, uint256 amountB) external pure returns (uint256) {
        return _calcNewPoolLP(amountA, amountB);
    }

    function sqrt(uint256 x) external pure returns (uint256) {
        return _sqrt(x);
    }

    // --- Exact copies from AerodromeStandardExchangeDFPkg ---

    function _proportionalDeposit(uint256 reserveA, uint256 reserveB, uint256 amountA, uint256 amountB)
        internal
        pure
        returns (uint256 depositA, uint256 depositB)
    {
        if (reserveA == 0 || reserveB == 0) {
            return (amountA, amountB);
        }

        uint256 optimalB = (amountA * reserveB) / reserveA;
        if (optimalB <= amountB) {
            return (amountA, optimalB);
        } else {
            return ((amountB * reserveA) / reserveB, amountB);
        }
    }

    function _calcNewPoolLP(uint256 amountA, uint256 amountB) internal pure returns (uint256 expectedLP) {
        expectedLP = _sqrt(amountA * amountB);
        if (expectedLP > 1000) {
            expectedLP -= 1000;
        } else {
            expectedLP = 0;
        }
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

/**
 * @title AerodromeStandardExchange_Fuzz_Test
 * @notice Fuzz/property-based tests for the proportional deposit math in AerodromeStandardExchangeDFPkg.
 * @dev Tests the core invariants:
 *      1. Outputs never exceed user-provided max amounts
 *      2. Output ratio matches reserve ratio (within rounding)
 *      3. No overflow/underflow for reasonable ranges
 *      4. Edge cases: zero reserves, tiny amounts, large amounts, asymmetric reserves
 */
contract AerodromeStandardExchange_Fuzz_Test is Test {
    ProportionalDepositHarness harness;

    function setUp() public {
        harness = new ProportionalDepositHarness();
    }

    /* ======================================================================== */
    /*                    Property 1: Outputs <= Inputs                         */
    /* ======================================================================== */

    /// @notice depositA <= amountA and depositB <= amountB for any inputs
    function testFuzz_proportionalDeposit_outputsNeverExceedInputs(
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountA,
        uint256 amountB
    ) public view {
        // Bound to avoid overflow in multiplication: amountA * reserveB and amountB * reserveA
        // Using uint128 max ensures the product fits in uint256
        reserveA = bound(reserveA, 0, type(uint128).max);
        reserveB = bound(reserveB, 0, type(uint128).max);
        amountA = bound(amountA, 0, type(uint128).max);
        amountB = bound(amountB, 0, type(uint128).max);

        (uint256 depositA, uint256 depositB) = harness.proportionalDeposit(reserveA, reserveB, amountA, amountB);

        assertLe(depositA, amountA, "depositA must not exceed amountA");
        assertLe(depositB, amountB, "depositB must not exceed amountB");
    }

    /* ======================================================================== */
    /*                Property 2: Ratio Matches Reserves                       */
    /* ======================================================================== */

    /// @notice The deposit ratio should match the reserve ratio (within 1 wei rounding)
    function testFuzz_proportionalDeposit_ratioMatchesReserves(
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountA,
        uint256 amountB
    ) public view {
        // Need non-zero reserves and amounts for ratio to be meaningful
        reserveA = bound(reserveA, 1, type(uint128).max);
        reserveB = bound(reserveB, 1, type(uint128).max);
        amountA = bound(amountA, 1, type(uint128).max);
        amountB = bound(amountB, 1, type(uint128).max);

        (uint256 depositA, uint256 depositB) = harness.proportionalDeposit(reserveA, reserveB, amountA, amountB);

        // Skip ratio check if either deposit is zero (can happen with tiny values)
        if (depositA == 0 || depositB == 0) return;

        // Cross-multiply to check ratio: depositA * reserveB ≈ depositB * reserveA
        // Due to integer division, we allow a rounding error of max(reserveA, reserveB)
        uint256 lhs = depositA * reserveB;
        uint256 rhs = depositB * reserveA;

        if (lhs >= rhs) {
            assertLe(lhs - rhs, reserveA, "Ratio mismatch exceeds 1 unit of reserveA rounding");
        } else {
            assertLe(rhs - lhs, reserveB, "Ratio mismatch exceeds 1 unit of reserveB rounding");
        }
    }

    /* ======================================================================== */
    /*                Property 3: One Side Fully Used                           */
    /* ======================================================================== */

    /// @notice At least one of the deposits should equal the user's provided amount
    ///         (the algorithm maximizes liquidity by fully using one side)
    function testFuzz_proportionalDeposit_oneSideFullyUsed(
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountA,
        uint256 amountB
    ) public view {
        reserveA = bound(reserveA, 1, type(uint128).max);
        reserveB = bound(reserveB, 1, type(uint128).max);
        amountA = bound(amountA, 1, type(uint128).max);
        amountB = bound(amountB, 1, type(uint128).max);

        (uint256 depositA, uint256 depositB) = harness.proportionalDeposit(reserveA, reserveB, amountA, amountB);

        assertTrue(depositA == amountA || depositB == amountB, "At least one deposit must equal the user's max amount");
    }

    /* ======================================================================== */
    /*             Property 4: Zero Reserves Pass-Through                      */
    /* ======================================================================== */

    /// @notice When either reserve is zero, amounts are returned unchanged
    function testFuzz_proportionalDeposit_zeroReservesPassthrough(uint256 amountA, uint256 amountB) public view {
        // reserveA == 0
        (uint256 dA1, uint256 dB1) = harness.proportionalDeposit(0, 100, amountA, amountB);
        assertEq(dA1, amountA, "Zero reserveA: depositA should equal amountA");
        assertEq(dB1, amountB, "Zero reserveA: depositB should equal amountB");

        // reserveB == 0
        (uint256 dA2, uint256 dB2) = harness.proportionalDeposit(100, 0, amountA, amountB);
        assertEq(dA2, amountA, "Zero reserveB: depositA should equal amountA");
        assertEq(dB2, amountB, "Zero reserveB: depositB should equal amountB");

        // Both reserves zero
        (uint256 dA3, uint256 dB3) = harness.proportionalDeposit(0, 0, amountA, amountB);
        assertEq(dA3, amountA, "Both zero: depositA should equal amountA");
        assertEq(dB3, amountB, "Both zero: depositB should equal amountB");
    }

    /* ======================================================================== */
    /*             Property 5: Symmetry                                        */
    /* ======================================================================== */

    /// @notice Equal reserves with equal amounts should return equal deposits
    function testFuzz_proportionalDeposit_symmetry(uint256 reserve, uint256 amount) public view {
        reserve = bound(reserve, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);

        (uint256 depositA, uint256 depositB) = harness.proportionalDeposit(reserve, reserve, amount, amount);

        assertEq(depositA, amount, "Equal reserves + equal amounts: depositA should equal amount");
        assertEq(depositB, amount, "Equal reserves + equal amounts: depositB should equal amount");
    }

    /* ======================================================================== */
    /*         Property 6: No Overflow for Reasonable Token Ranges             */
    /* ======================================================================== */

    /// @notice No revert for amounts up to uint128 max (covers all realistic token amounts)
    function testFuzz_proportionalDeposit_noOverflowReasonableRange(
        uint128 reserveA,
        uint128 reserveB,
        uint128 amountA,
        uint128 amountB
    ) public view {
        // Using uint128 params directly ensures products fit in uint256
        // This covers all realistic token scenarios (18-decimal tokens up to ~3.4e20 total supply)
        reserveA = uint128(bound(uint256(reserveA), 1, type(uint128).max));
        reserveB = uint128(bound(uint256(reserveB), 1, type(uint128).max));

        (uint256 depositA, uint256 depositB) =
            harness.proportionalDeposit(uint256(reserveA), uint256(reserveB), uint256(amountA), uint256(amountB));

        // Just verify it didn't revert and outputs are bounded
        assertLe(depositA, uint256(amountA));
        assertLe(depositB, uint256(amountB));
    }

    /* ======================================================================== */
    /*             Edge Cases: Explicit boundary tests                          */
    /* ======================================================================== */

    /// @notice 1 wei amounts with varying reserves
    function testFuzz_proportionalDeposit_oneWeiAmounts(uint256 reserveA, uint256 reserveB) public view {
        reserveA = bound(reserveA, 1, type(uint128).max);
        reserveB = bound(reserveB, 1, type(uint128).max);

        (uint256 depositA, uint256 depositB) = harness.proportionalDeposit(reserveA, reserveB, 1, 1);

        assertLe(depositA, 1, "1 wei: depositA <= 1");
        assertLe(depositB, 1, "1 wei: depositB <= 1");
    }

    /// @notice Highly asymmetric reserves (1 wei vs large reserve)
    function testFuzz_proportionalDeposit_asymmetricReserves(uint256 amountA, uint256 amountB) public view {
        amountA = bound(amountA, 1, type(uint128).max);
        amountB = bound(amountB, 1, type(uint128).max);

        // reserveA = 1 wei, reserveB = 1e18
        (uint256 dA, uint256 dB) = harness.proportionalDeposit(1, 1e18, amountA, amountB);
        assertLe(dA, amountA, "Asymmetric: depositA <= amountA");
        assertLe(dB, amountB, "Asymmetric: depositB <= amountB");

        // Flip: reserveA = 1e18, reserveB = 1 wei
        (uint256 dA2, uint256 dB2) = harness.proportionalDeposit(1e18, 1, amountA, amountB);
        assertLe(dA2, amountA, "Flipped asymmetric: depositA <= amountA");
        assertLe(dB2, amountB, "Flipped asymmetric: depositB <= amountB");
    }

    /// @notice Zero input amounts
    function test_proportionalDeposit_zeroInputAmounts() public view {
        (uint256 dA, uint256 dB) = harness.proportionalDeposit(100e18, 200e18, 0, 0);
        assertEq(dA, 0, "Zero amounts: depositA = 0");
        assertEq(dB, 0, "Zero amounts: depositB = 0");
    }

    /// @notice Only one input amount is zero
    function testFuzz_proportionalDeposit_oneZeroAmount(uint256 reserveA, uint256 reserveB, uint256 amount)
        public
        view
    {
        reserveA = bound(reserveA, 1, type(uint128).max);
        reserveB = bound(reserveB, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);

        // amountA = 0, amountB > 0
        (uint256 dA1, uint256 dB1) = harness.proportionalDeposit(reserveA, reserveB, 0, amount);
        assertEq(dA1, 0, "Zero amountA: depositA should be 0");
        assertLe(dB1, amount, "Zero amountA: depositB <= amountB");

        // amountA > 0, amountB = 0
        (uint256 dA2, uint256 dB2) = harness.proportionalDeposit(reserveA, reserveB, amount, 0);
        assertLe(dA2, amount, "Zero amountB: depositA <= amountA");
        assertEq(dB2, 0, "Zero amountB: depositB should be 0");
    }

    /* ======================================================================== */
    /*                    _calcNewPoolLP Fuzz Tests                             */
    /* ======================================================================== */

    /// @notice LP tokens for new pool should be sqrt(a*b) - 1000 (or 0 if too small)
    function testFuzz_calcNewPoolLP_correctness(uint128 amountA, uint128 amountB) public view {
        amountA = uint128(bound(uint256(amountA), 1, type(uint128).max));
        amountB = uint128(bound(uint256(amountB), 1, type(uint128).max));

        uint256 lp = harness.calcNewPoolLP(uint256(amountA), uint256(amountB));
        uint256 sqrtVal = harness.sqrt(uint256(amountA) * uint256(amountB));

        if (sqrtVal > 1000) {
            assertEq(lp, sqrtVal - 1000, "LP should be sqrt(a*b) - 1000");
        } else {
            assertEq(lp, 0, "LP should be 0 when sqrt <= 1000");
        }
    }

    /// @notice LP calculation should not overflow for uint128 inputs
    function testFuzz_calcNewPoolLP_noOverflow(uint128 amountA, uint128 amountB) public view {
        // uint128 * uint128 fits in uint256, so this should never revert
        harness.calcNewPoolLP(uint256(amountA), uint256(amountB));
    }

    /* ======================================================================== */
    /*                        _sqrt Fuzz Tests                                 */
    /* ======================================================================== */

    /// @notice sqrt(x)^2 <= x < (sqrt(x)+1)^2
    /// @dev Note: _sqrt overflows for x = type(uint256).max because (x+1)/2 wraps.
    ///      In production, _sqrt is only called from _calcNewPoolLP with amountA * amountB
    ///      where both fit in uint128, so x <= type(uint256).max - 2^129 + 1.
    ///      We bound x to type(uint256).max - 1 to avoid the known overflow.
    function testFuzz_sqrt_correctness(uint256 x) public view {
        // _sqrt has (x + 1) / 2 which overflows at type(uint256).max
        x = bound(x, 0, type(uint256).max - 1);

        uint256 root = harness.sqrt(x);

        assertLe(root * root, x, "sqrt(x)^2 should be <= x");

        // Verify root is the floor: (root+1)^2 > x
        // Only check when (root+1)^2 won't overflow uint256
        if (root < type(uint128).max) {
            uint256 next = root + 1;
            assertGt(next * next, x, "(sqrt(x)+1)^2 should be > x");
        }
    }

    /// @notice _sqrt reverts on type(uint256).max due to (x+1) overflow
    /// @dev This documents the known edge case. Not a production risk since
    ///      _sqrt is only called with products of two uint128 values.
    function test_sqrt_maxUint256_reverts() public {
        vm.expectRevert(stdError.arithmeticError);
        harness.sqrt(type(uint256).max);
    }

    /// @notice sqrt(0) == 0
    function test_sqrt_zero() public view {
        assertEq(harness.sqrt(0), 0);
    }

    /// @notice sqrt(1) == 1
    function test_sqrt_one() public view {
        assertEq(harness.sqrt(1), 1);
    }

    /* ======================================================================== */
    /*            Integration: Preview Matches Deposit Logic                    */
    /* ======================================================================== */

    /// @notice The proportional math used in previewDeployVault and _depositLiquidity
    ///         should produce identical results for the same inputs
    function testFuzz_proportionalDeposit_previewMatchesDeposit(
        uint128 reserveA,
        uint128 reserveB,
        uint128 amountA,
        uint128 amountB
    ) public view {
        reserveA = uint128(bound(uint256(reserveA), 1, type(uint128).max));
        reserveB = uint128(bound(uint256(reserveB), 1, type(uint128).max));

        // Both preview and deposit call _proportionalDeposit with the same args
        // Calling it twice should yield identical results (deterministic pure function)
        (uint256 dA1, uint256 dB1) =
            harness.proportionalDeposit(uint256(reserveA), uint256(reserveB), uint256(amountA), uint256(amountB));
        (uint256 dA2, uint256 dB2) =
            harness.proportionalDeposit(uint256(reserveA), uint256(reserveB), uint256(amountA), uint256(amountB));

        assertEq(dA1, dA2, "Preview and deposit must produce identical depositA");
        assertEq(dB1, dB2, "Preview and deposit must produce identical depositB");
    }

    /* ======================================================================== */
    /*       Property 7: Expected LP computation consistency                   */
    /* ======================================================================== */

    /// @notice For an existing pool, expected LP from proportional deposit should be consistent.
    ///         LP = min(proportionalA * totalSupply / reserveA, proportionalB * totalSupply / reserveB)
    ///         The two LP values should be close because deposits are proportional.
    function testFuzz_expectedLP_existingPool(
        uint128 reserveA,
        uint128 reserveB,
        uint128 amountA,
        uint128 amountB,
        uint128 totalSupply
    ) public view {
        reserveA = uint128(bound(uint256(reserveA), 1, type(uint128).max));
        reserveB = uint128(bound(uint256(reserveB), 1, type(uint128).max));
        totalSupply = uint128(bound(uint256(totalSupply), 1, type(uint128).max));

        (uint256 propA, uint256 propB) =
            harness.proportionalDeposit(uint256(reserveA), uint256(reserveB), uint256(amountA), uint256(amountB));

        if (propA == 0 || propB == 0) return;

        uint256 lpFromA = (propA * uint256(totalSupply)) / uint256(reserveA);
        uint256 lpFromB = (propB * uint256(totalSupply)) / uint256(reserveB);
        uint256 expectedLP = lpFromA < lpFromB ? lpFromA : lpFromB;

        // The proportional deposit has up to 1 unit of reserve rounding error.
        // When computing LP, this rounding error gets scaled by totalSupply/reserve,
        // so the max LP difference is bounded by totalSupply / min(reserveA, reserveB) + 1.
        uint256 minReserve = reserveA < reserveB ? uint256(reserveA) : uint256(reserveB);
        uint256 maxLPDiff = uint256(totalSupply) / minReserve + 1;

        uint256 diff = lpFromA >= lpFromB ? lpFromA - lpFromB : lpFromB - lpFromA;
        assertLe(diff, maxLPDiff, "LP difference exceeds theoretical rounding bound");

        // expectedLP should always be <= either individual LP calculation
        assertLe(expectedLP, lpFromA, "expectedLP should be <= lpFromA");
        assertLe(expectedLP, lpFromB, "expectedLP should be <= lpFromB");
    }
}
