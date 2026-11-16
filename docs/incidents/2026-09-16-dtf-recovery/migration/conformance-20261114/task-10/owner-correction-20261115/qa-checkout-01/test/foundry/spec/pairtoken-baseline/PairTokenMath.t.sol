// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PairTokenMath} from "../../../../contracts/pairtoken-baseline/PairTokenMath.sol";

/// @dev External frames expose the library's exact revert bytes without mocking the SUT.
contract PairTokenMathHarness {
    function MD(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PairTokenMath.MD(a, b, c);
    }

    function MU(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PairTokenMath.MU(a, b, c);
    }

    function A0down(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return PairTokenMath.A0down(a, b, liquidity);
    }

    function A0up(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return PairTokenMath.A0up(a, b, liquidity);
    }

    function A1down(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return PairTokenMath.A1down(a, b, liquidity);
    }

    function A1up(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return PairTokenMath.A1up(a, b, liquidity);
    }

    function L0(uint160 a, uint160 b, uint256 amount) external pure returns (uint128) {
        return PairTokenMath.L0(a, b, amount);
    }

    function L1(uint160 a, uint160 b, uint256 amount) external pure returns (uint128) {
        return PairTokenMath.L1(a, b, amount);
    }

    function Fit(uint160 p, uint160 a, uint160 b, uint256 x, uint256 y) external pure returns (uint128) {
        return PairTokenMath.Fit(p, a, b, x, y);
    }

    function T(int24 tick) external pure returns (uint160) {
        return PairTokenMath.T(tick);
    }

    function sqrt(uint256 value) external pure returns (uint256) {
        return PairTokenMath.sqrt(value);
    }

    function U128(int128 delta) external pure returns (uint256) {
        return PairTokenMath.U128(delta);
    }

    function genesisRoot(uint256 x, uint256 y) external pure returns (uint256) {
        return PairTokenMath.sqrt(x * y);
    }

    function checkedProduct(uint256 x, uint256 factor) external pure returns (uint256) {
        return x * factor;
    }

    function initializationDivision(int24 spacing) external pure returns (int24) {
        return (-887272 / spacing) * spacing;
    }

    function negativeMagnitude(int128 delta) external pure returns (uint256) {
        return uint128(-delta);
    }

    function swapEncoding(uint256 amount) external pure returns (int256) {
        return -int256(amount);
    }
}

contract PairTokenMathTest is Test {
    uint160 private constant Q96 = uint160(1 << 96);
    string private constant FIXTURE = "test/foundry/spec/pairtoken-baseline/fixtures/math.json";
    PairTokenMathHarness private math;

    function setUp() public {
        math = new PairTokenMathHarness();
    }

    function test_PT_MATH_md_mu() public view {
        // Given: independent Python wide-product fixtures, including >256-bit products.
        uint256[] memory rows = vm.parseJsonUintArray(vm.readFile(FIXTURE), ".md");
        assertGt(rows.length, 0);
        assertEq(rows.length % 7, 0);
        for (uint256 i; i < rows.length; i += 7) {
            // When: each rounding variant processes the same full-width operands.
            // Then: the exact integer or exact empty revert matches the oracle.
            _assertResult(
                abi.encodeCall(math.MD, (rows[i], rows[i + 1], rows[i + 2])), rows[i + 3] != 0, rows[i + 4]
            );
            _assertResult(
                abi.encodeCall(math.MU, (rows[i], rows[i + 1], rows[i + 2])), rows[i + 5] != 0, rows[i + 6]
            );
        }
    }

    function testFuzz_PT_MATH_md_mu_wide_oracle(uint256 a, uint256 b, uint256 c) public {
        // Given: arbitrary uint256 operands, evaluated by Python's unbounded integer product.
        string[] memory command = new string[](6);
        command[0] = "python3";
        command[1] = "test/foundry/spec/pairtoken-baseline/math-oracle.py";
        command[2] = "md";
        command[3] = vm.toString(a);
        command[4] = vm.toString(b);
        command[5] = vm.toString(c);
        (bool downOk, uint256 down, bool upOk, uint256 up) =
            abi.decode(vm.ffi(command), (bool, uint256, bool, uint256));
        // When / Then: compare both SUT outcomes, including failure bytes.
        _assertResult(abi.encodeCall(math.MD, (a, b, c)), downOk, down);
        _assertResult(abi.encodeCall(math.MU, (a, b, c)), upOk, up);
    }

    function test_PT_MATH_amounts() public view {
        // Given: sorted/reversed, equal, zero-liquidity, extreme, and rounding fixtures.
        uint256[] memory rows = vm.parseJsonUintArray(vm.readFile(FIXTURE), ".amounts");
        assertGt(rows.length, 0);
        assertEq(rows.length % 7, 0);
        for (uint256 i; i < rows.length; i += 7) {
            uint160 a = uint160(rows[i]);
            uint160 b = uint160(rows[i + 1]);
            uint128 liquidity = uint128(rows[i + 2]);
            // When / Then: amount0 nested rounding and amount1 absolute difference match.
            assertEq(math.A0down(a, b, liquidity), rows[i + 3]);
            assertEq(math.A0up(a, b, liquidity), rows[i + 4]);
            assertEq(math.A1down(a, b, liquidity), rows[i + 5]);
            assertEq(math.A1up(a, b, liquidity), rows[i + 6]);
        }
    }

    function test_PT_MATH_amount0_zero_price_including_zero_liquidity() public {
        // Given: a zero endpoint, in both argument orders, including zero liquidity.
        for (uint128 liquidity; liquidity < 2; ++liquidity) {
            // When / Then: amount0 rejects with InvalidPrice, before any zero shortcut.
            vm.expectRevert(PairTokenMath.InvalidPrice.selector);
            math.A0down(0, Q96, liquidity);
            vm.expectRevert(PairTokenMath.InvalidPrice.selector);
            math.A0down(Q96, 0, liquidity);
            vm.expectRevert(PairTokenMath.InvalidPrice.selector);
            math.A0up(0, Q96, liquidity);
            vm.expectRevert(PairTokenMath.InvalidPrice.selector);
            math.A0up(Q96, 0, liquidity);
            vm.expectRevert(PairTokenMath.InvalidPrice.selector);
            math.A0up(0, 0, liquidity);
        }
    }

    function test_PT_MATH_amount1_zero_price_and_remainder() public view {
        // Given: a zero endpoint, exact Q96 difference, and a fractional product.
        // When / Then: no InvalidPrice guard is imported into amount1.
        assertEq(math.A1down(0, Q96, 5), 5);
        assertEq(math.A1up(Q96, 0, 5), 5);
        assertEq(math.A1down(0, 1, 1), 0);
        assertEq(math.A1up(1, 0, 1), 1);
        assertEq(math.A1up(0, 0, type(uint128).max), 0);
        assertEq(math.A1up(0, Q96, 0), 0);
    }

    function test_PT_MATH_fit() public view {
        // Given: both bound orders, all three branches, endpoint equalities, and zero limiting legs.
        uint256[] memory rows = vm.parseJsonUintArray(vm.readFile(FIXTURE), ".fit");
        assertGt(rows.length, 0);
        assertEq(rows.length % 6, 0);
        for (uint256 i; i < rows.length; i += 6) {
            // When / Then: Fit returns the independently computed branch result.
            assertEq(
                math.Fit(uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]), rows[i + 3], rows[i + 4]),
                rows[i + 5]
            );
        }
        assertEq(math.L0(Q96, Q96 * 2, 1000), 2000);
        assertEq(math.L0(Q96 * 2, Q96, 1000), 2000);
        assertEq(math.L1(Q96, Q96 * 2, 300), 300);
        assertEq(math.L1(Q96 * 2, Q96, 300), 300);
    }

    function test_PT_MATH_tick_oracle() public view {
        // Given: fixtures generated from the hash-verified PRD coefficient table, not a second table.
        string memory json = vm.readFile(FIXTURE);
        int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
        uint256[] memory prices = vm.parseJsonUintArray(json, ".prices");
        assertGt(ticks.length, 200);
        assertEq(ticks.length, prices.length);
        for (uint256 i; i < ticks.length; ++i) {
            // When / Then: every per-bit, boundary, and deterministic sampled tick is exact.
            assertEq(math.T(int24(ticks[i])), prices[i]);
        }
        // PT-CONST-02 anchors are specified independently of the recurrence.
        assertEq(math.T(0), Q96);
        assertEq(math.T(-887272), 4295128739);
        assertEq(math.T(887272), 1461446703485210103287273052203988822378723970342);
    }

    function test_PT_MATH_tick_out_of_range() public {
        // Given: immediate out-of-range and signed-width extrema.
        int24[4] memory ticks = [int24(-887273), int24(887273), type(int24).min, type(int24).max];
        for (uint256 i; i < ticks.length; ++i) {
            // When / Then: the supplied tick is preserved in the custom error.
            vm.expectRevert(abi.encodeWithSelector(PairTokenMath.InvalidTick.selector, ticks[i]));
            math.T(ticks[i]);
        }
    }

    function test_PT_MATH_sqrt() public view {
        // Given: independent math.isqrt fixtures, including MAX and adjacent squares.
        uint256[] memory rows = vm.parseJsonUintArray(vm.readFile(FIXTURE), ".roots");
        assertGt(rows.length, 0);
        assertEq(rows.length % 2, 0);
        for (uint256 i; i < rows.length; i += 2) {
            // When / Then: floor sqrt agrees on the complete uint256 input domain samples.
            assertEq(math.sqrt(rows[i]), rows[i + 1]);
        }
        assertEq(math.genesisRoot(1000, 1000), 1000);
        assertEq(math.genesisRoot(1001, 1001), 1001);
    }

    function test_PT_MATH_U128() public view {
        // Given: same-width signed values, including negative minimum.
        // When / Then: U128 preserves low bits rather than taking a magnitude.
        assertEq(math.U128(0), 0);
        assertEq(math.U128(1), 1);
        assertEq(math.U128(type(int128).max), uint256(uint128(type(int128).max)));
        assertEq(math.U128(-1), type(uint128).max);
        assertEq(math.U128(type(int128).min), uint256(1) << 127);
    }

    function test_PT_MATH_signed_minimum_negation() public {
        // Given: negative minimum at the settlement's original width.
        // When / Then: checked negation fails before U128 conversion.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        math.negativeMagnitude(type(int128).min);
    }

    function test_PT_MATH_swap_encoding_boundaries() public {
        // Given: inputs straddling the uint256/int256 conversion boundary.
        // When / Then: signed conversion precedes checked negation.
        assertEq(math.swapEncoding(0), 0);
        assertEq(math.swapEncoding((uint256(1) << 255) - 1), -type(int256).max);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        math.swapEncoding(uint256(1) << 255);
        assertEq(math.swapEncoding((uint256(1) << 255) + 1), type(int256).max);
        assertEq(math.swapEncoding(type(uint256).max), 1);
    }

    function test_PT_AC_22_math() public {
        // Given: a representable mathematical root but an unrepresentable ordinary genesis product.
        // When / Then: checked multiplication panics, rather than being replaced with MD.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        math.genesisRoot(uint256(1) << 128, uint256(1) << 128);
    }

    function test_PT_MATH_checked_basis_point_products() public {
        // Given: overflowing retention, fee, and cap products remain ordinary multiplication.
        uint256[3] memory factors = [uint256(9990), uint256(10000), uint256(type(uint16).max)];
        for (uint256 i; i < factors.length; ++i) {
            // When / Then: no full-precision rewrite silently removes the panic.
            vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
            math.checkedProduct(type(uint256).max, factors[i]);
        }
    }

    function test_PT_AC_55() public {
        // Given: zero tick, invalid tick, and equal bounds.
        assertEq(math.T(0), Q96);
        vm.expectRevert(abi.encodeWithSelector(PairTokenMath.InvalidTick.selector, int24(887273)));
        math.T(887273);
        // When / Then: equal bounds produce an empty MD revert even for zero amounts.
        _assertResult(abi.encodeCall(math.Fit, (Q96, Q96, Q96, 0, 0)), false, 0);
        _assertResult(abi.encodeCall(math.L0, (Q96, Q96, 1)), false, 0);
        _assertResult(abi.encodeCall(math.L1, (Q96, Q96, 1)), false, 0);
        // That is observably distinct from initialization's native division-by-zero panic.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x12));
        math.initializationDivision(0);
    }

    function test_PT_AC_55_inside_candidate_casts_before_minimum() public {
        // Given: p=2Q96 in [Q96,3Q96]; one candidate overflows uint128 while the other is zero.
        uint256 oversized = uint256(1) << 128;
        // When / Then: neither overflowing candidate is rescued by the other candidate.
        vm.expectRevert(PairTokenMath.SafeCastOverflow.selector);
        math.Fit(Q96 * 2, Q96, Q96 * 3, oversized, 0);
        vm.expectRevert(PairTokenMath.SafeCastOverflow.selector);
        math.Fit(Q96 * 2, Q96, Q96 * 3, 0, oversized);
        vm.expectRevert(PairTokenMath.SafeCastOverflow.selector);
        math.L0(Q96, Q96 * 2, oversized);
        vm.expectRevert(PairTokenMath.SafeCastOverflow.selector);
        math.L1(Q96, Q96 * 2, oversized);
        assertEq(math.L1(Q96, Q96 * 2, type(uint128).max), type(uint128).max);
    }

    function test_PT_AC_33_math_does_not_clamp_basket_endpoints() public view {
        // Given: live price outside [Q96,2Q96], liquidity 12; basket uses (p,b) and (a,p).
        // When / Then: amount deltas retain their endpoints; Fit independently branches.
        assertEq(math.A0down(Q96 * 3, Q96 * 2, 12), 2);
        assertEq(math.A1down(Q96, Q96 * 3, 12), 24);
        assertEq(math.Fit(Q96 * 3, Q96, Q96 * 2, 1000, 300), 300);
        assertEq(math.A0down(Q96 / 2, Q96 * 2, 12), 18);
        assertEq(math.A1down(Q96, Q96 / 2, 12), 6);
        assertEq(math.Fit(Q96 / 2, Q96, Q96 * 2, 1000, 300), 2000);
    }

    function _assertResult(bytes memory input, bool expectedSuccess, uint256 expectedValue) private view {
        (bool success, bytes memory data) = address(math).staticcall(input);
        assertEq(success, expectedSuccess);
        if (success) {
            assertEq(abi.decode(data, (uint256)), expectedValue);
        } else {
            assertEq(data, bytes(""));
        }
    }
}
