// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4PairTokenStandardExchangeVaultMath as Math
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {PairTokenMath} from "contracts/pairtoken-baseline/PairTokenMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {SYUtils} from "@crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultMathTest[]
/// @notice P1 arithmetic controls, not real-proxy A32/A45 product acceptance.
/// @dev The actual library is the SUT. External self-call frames expose exact
/// revert data without replacing any production behavior or deploying a vault.
contract UniswapV4PairTokenStandardExchangeVaultMathTest is Test {
    uint160 private constant Q96 = uint160(1 << 96);
    string private constant FIXTURE =
        "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/reference/vectors.json";

    /// @notice The fixed linked math component cannot be invoked in its own context.
    function test_mathLibrary_rejectsDirectCall() public view {
        (bool success, bytes memory result) = address(Math).staticcall(
            abi.encodeWithSelector(Math.principal.selector, Q96, Q96 / 2, 2 * Q96, uint128(1))
        );
        assertFalse(success);
        assertEq(result, abi.encodeWithSelector(Math.DirectCallNotAllowed.selector));
    }

    /// @notice Rational controls span below/equal/interior/equal/above and zero liquidity.
    function test_principalAndCosts_fractionVectors() public view {
        uint256[] memory rows = _rows(".amounts", 8);
        for (uint256 i; i < rows.length; i += 8) {
            (uint256 a0, uint256 a1) =
                Math.principal(uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]), uint128(rows[i + 3]));
            (uint256 c0, uint256 c1) =
                Math.costs(uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]), uint128(rows[i + 3]));
            assertEq(a0, rows[i + 4], "principal0");
            assertEq(a1, rows[i + 5], "principal1");
            assertEq(c0, rows[i + 6], "cost0");
            assertEq(c1, rows[i + 7], "cost1");
        }
    }

    /// @notice Only the limiting liquidity is narrowed; capacity is never clamped.
    function test_liquidity_integerVectors() public view {
        uint256[] memory rows = _rows(".liquidity", 7);
        for (uint256 i; i < rows.length; i += 7) {
            (bool fits, uint128 result) = Math.tryLiquidityForAmounts(
                uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]), rows[i + 3], rows[i + 4]
            );
            assertEq(fits, rows[i + 5] != 0);
            assertEq(result, rows[i + 6]);
            _assertUint(
                abi.encodeCall(this.callLiquidity, (
                    uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]), rows[i + 3], rows[i + 4]
                )),
                rows[i + 5] != 0,
                rows[i + 6],
                Math.LiquidityOverflow.selector
            );
        }
    }

    /// @notice Candidate ceiling inputs retain the one-sided full-maximum rule.
    function test_pairedQuote_integerVectors() public view {
        // Given: hand-sized exact nonintegral ratios.
        // When: positive supply uses the limiting candidate.
        (uint256 q, uint256 used0, uint256 used1) = Math.pairedQuote(11, 7, 13, 17, 19);
        // Then: accepted inputs ceil(16*R/11), not a second post-credit selection.
        assertEq(q, 16);
        assertEq(used0, 11);
        assertEq(used1, 19);
    }

    /// @notice Replay independently generated genesis, one-sided and wide candidates.
    function test_pairedQuote_oracleVectors() public view {
        uint256[] memory rows = _rows(".paired", 8);
        for (uint256 i; i < rows.length; i += 8) {
            (uint256 q, uint256 used0, uint256 used1) =
                Math.pairedQuote(rows[i], rows[i + 1], rows[i + 2], rows[i + 3], rows[i + 4]);
            assertEq(q, rows[i + 5]);
            assertEq(used0, rows[i + 6]);
            assertEq(used1, rows[i + 7]);
        }
    }

    /// @notice A representable cap needs no representable intermediate ratio quotient.
    function test_credit_cappedOracleVectors() public view {
        uint256[] memory rows = _rows(".credit", 7);
        for (uint256 i; i < rows.length; i += 7) {
            assertEq(
                Math.credit(rows[i], rows[i + 1], rows[i + 2], rows[i + 3], rows[i + 4], rows[i + 5]),
                rows[i + 6]
            );
        }
    }

    /// @notice The uncapped path rejects a truly overflowing minimum, not an irrelevant leg.
    function test_zapCredit_uncappedOracleVectors() public view {
        uint256[] memory rows = _rows(".zap", 7);
        for (uint256 i; i < rows.length; i += 7) {
            _assertUint(
                abi.encodeCall(this.callZap, (rows[i], rows[i + 1], rows[i + 2], rows[i + 3], rows[i + 4])),
                rows[i + 5] == 1,
                rows[i + 6],
                rows[i + 5] == 2 ? Math.ZeroShares.selector : Math.ArithmeticOverflow.selector
            );
        }
    }

    /// @notice A zero-reserve leg cannot create a separate issuance constraint or credit.
    function test_credit_zeroReserveAndOneSidedAcceptance() public view {
        (uint256 q, uint256 used0, uint256 used1) = Math.pairedQuote(3, 0, 7, 999, 10);
        assertEq(q, 4);
        assertEq(used0, 0);
        assertEq(used1, 10);
        assertEq(Math.credit(3, 0, 7, type(uint256).max, 8, q), 3);
        assertEq(Math.zapCredit(3, 0, 7, type(uint256).max, 8), 3);
    }

    /// @notice Full-width allocation leaves partial dust and drains exact final allocations.
    function test_allocation_integerVectors() public view {
        uint256[] memory rows = _rows(".allocation", 8);
        for (uint256 i; i < rows.length; i += 8) {
            (uint128 removed, uint256 a0, uint256 a1) =
                Math.allocation(rows[i], rows[i + 1], uint128(rows[i + 2]), rows[i + 3], rows[i + 4]);
            assertEq(removed, rows[i + 5]);
            assertEq(a0, rows[i + 6]);
            assertEq(a1, rows[i + 7]);
        }
    }

    /// @notice Baseline strict dust, ties, half-swap, zero active and quarter caps.
    function test_compoundSwap_integerVectors() public view {
        uint256[] memory rows = _rows(".compound", 9);
        for (uint256 i; i < rows.length; i += 9) {
            (bool direction, uint256 amount) = Math.compoundSwap(
                uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]),
                rows[i + 3], rows[i + 4], uint128(rows[i + 5]), uint16(rows[i + 6])
            );
            assertEq(direction, rows[i + 7] != 0);
            assertEq(amount, rows[i + 8]);
            (bool fits, bool tryDirection, uint256 tryAmount) = Math.tryCompoundSwap(
                uint160(rows[i]), uint160(rows[i + 1]), uint160(rows[i + 2]),
                rows[i + 3], rows[i + 4], uint128(rows[i + 5]), uint16(rows[i + 6])
            );
            assertTrue(fits);
            assertEq(tryDirection, direction);
            assertEq(tryAmount, amount);
        }
    }

    /// @notice Failure is an inspectable result; the normal wrapper still rejects.
    function test_compoundSwap_inspectableLiquidityFailure() public {
        (bool fits, bool direction, uint256 amount) = Math.tryCompoundSwap(
            Q96, Q96 / 2, 2 * Q96, type(uint256).max, type(uint256).max, 10000, 10000
        );
        assertFalse(fits);
        assertFalse(direction);
        assertEq(amount, 0);
        vm.expectRevert(Math.LiquidityOverflow.selector);
        this.callCompound(type(uint256).max, type(uint256).max);
    }

    /// @notice Exact uint128 endpoint is accepted, while one more is not clamped.
    function test_liquidity_inspectableCapacityBoundary() public view {
        (bool fits, uint128 result) =
            Math.tryLiquidityForAmounts(2 * Q96, Q96, 2 * Q96, 0, type(uint128).max);
        assertTrue(fits);
        assertEq(result, type(uint128).max);
        (fits, result) = Math.tryLiquidityForAmounts(2 * Q96, Q96, 2 * Q96, 0, uint256(1) << 128);
        assertFalse(fits);
        assertEq(result, 0);
    }

    /// @notice A narrow-range math control distinguishes the two floor contracts.
    /// @dev This scalar-domain witness is not a full-range product reachability claim.
    function test_compoundSwap_sequentialFloorDirection() public view {
        uint160 price = 4295128740;
        uint256 input0 = 340597043326865546349313180835249851050402;
        (bool direction, uint256 amount) = Math.compoundSwap(price, price, 2 * price, input0, 1001, 10000, 10000);
        assertFalse(direction);
        assertEq(amount, 0);
        assertEq(Math.accountingRate(price, input0, 0, 1e18, false), 1001);
    }

    /// @notice Compound compares a wide sequential valuation without narrowing it.
    function test_compoundSwap_wideComparison() public view {
        (bool direction, uint256 amount) = Math.compoundSwap(
            uint160(1 << 159), uint160(1 << 158), type(uint160).max,
            type(uint256).max, 0, 1e18, 10000
        );
        assertTrue(direction);
        assertEq(amount, 0);
    }

    /// @notice Exact rational conversions, including high square and three-word products.
    function test_accountingRate_fractionVectors() public view {
        uint256[] memory rows = _rows(".rates", 7);
        for (uint256 i; i < rows.length; i += 7) {
            _assertUint(
                abi.encodeCall(this.callRate, (uint160(rows[i]), rows[i + 1], rows[i + 2], rows[i + 3], rows[i + 4] != 0)),
                rows[i + 5] != 0,
                rows[i + 6],
                Math.ArithmeticOverflow.selector
            );
        }
    }

    /// @notice Both conversions can have a >256-bit Vraw and a small valid final rate.
    function test_accountingRate_wideIntermediateRepresentableFinal() public view {
        uint256 maximum = type(uint256).max;
        assertEq(Math.accountingRate(2 * Q96, maximum, 0, maximum, false), 4e18);
        assertEq(Math.accountingRate(Q96 / 2, 0, maximum, maximum, true), 4e18);
        assertEq(Math.accountingRate(Q96, maximum, maximum, maximum, true), 2e18);
    }

    /// @notice One currency floor is observably different from sequential floors.
    function test_accountingRate_singleFloorNotSequentialFloors() public view {
        uint160 price = Q96 + Q96 / 2;
        assertEq(Math.accountingRate(price, 1, 0, 1e18, false), 2);
        assertEq((uint256(1) * price / Q96) * price / Q96, 1);
    }

    /// @notice Six/eight/eighteen-decimal metadata adds no extra rate scaling.
    function test_accountingRate_canonicalRawSYHelpers() public view {
        uint256[3] memory amounts = [uint256(1e6), uint256(1e8), uint256(1e18)];
        for (uint256 i; i < amounts.length; ++i) {
            uint256 rate = Math.accountingRate(Q96, amounts[i], 0, 1e18, true);
            assertEq(rate, amounts[i]);
            assertEq(SYUtils.syToAsset(rate, 1e18), amounts[i]);
            uint256 portion = uint256(1e18) / 3;
            assertEq(SYUtils.syToAsset(rate, portion), (amounts[i] * portion) / 1e18);
        }
    }

    /// @notice Each rounding contract stands alone; an exact inverse is not promised.
    function test_accountingRate_rateAndSYRounding() public view {
        uint256 rate = Math.accountingRate(Q96, 2, 0, 3, true);
        assertEq(rate, 666666666666666666);
        assertEq(SYUtils.syToAsset(rate, 3), 1);
    }

    /// @notice A helper's checked multiplication failure is not a wide-rate failure.
    function test_accountingRate_helperOverflowIsSeparate() public {
        uint256 maximum = type(uint256).max;
        uint256 rate = Math.accountingRate(2 * Q96, maximum, 0, maximum, false);
        assertEq(rate, 4e18);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        this.callSyToAsset(rate, maximum);
    }

    /// @notice Reject actual final-rate overflow in both conversion directions.
    function test_accountingRate_finalOverflow() public {
        vm.expectRevert(Math.ArithmeticOverflow.selector);
        this.callRate(2 * Q96, type(uint256).max, 0, 1, false);
        vm.expectRevert(Math.ArithmeticOverflow.selector);
        this.callRate(Q96 / 2, 0, type(uint256).max, 1, true);
    }

    /// @notice Empty supply returns zero even before a price exists; nonempty needs price.
    function test_accountingRate_emptyAndInvalidPrice() public {
        assertEq(Math.accountingRate(0, type(uint256).max, type(uint256).max, 0, true), 0);
        vm.expectRevert(Math.InvalidPrice.selector);
        this.callRate(0, 1, 1, 1, true);
    }

    /// @notice Genesis multiplication is checked, unlike wide proportional issuance.
    function test_pairedQuote_checkedGenesisAndZero() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        this.callPaired(0, 0, 0, type(uint256).max, 2);
        vm.expectRevert(Math.ZeroShares.selector);
        this.callPaired(0, 0, 0, 0, 1);
        vm.expectRevert(Math.ZeroShares.selector);
        this.callPaired(1, 2, 2, 1, 1);
        vm.expectRevert(Math.ArithmeticOverflow.selector);
        this.callPaired(type(uint256).max, 1, 1, type(uint256).max, type(uint256).max);
    }

    /// @notice Positive supply with no backing rejects instead of using genesis.
    function test_credit_invalidAccountingAndZero() public {
        vm.expectRevert(Math.InvalidAccountingState.selector);
        this.callPaired(1, 0, 0, 10, 10);
        vm.expectRevert(Math.InvalidAccountingState.selector);
        this.callCredit(1, 0, 0, 10, 10, 1);
        vm.expectRevert(Math.InvalidAccountingState.selector);
        this.callZap(0, 1, 1, 1, 1);
        vm.expectRevert(Math.ZeroShares.selector);
        this.callCredit(1, 1, 1, 1, 1, 0);
        vm.expectRevert(Math.ZeroShares.selector);
        this.callZap(1, 2, 2, 1, 1);
    }

    /// @notice Actual result capacity is rejected rather than saturated.
    function test_liquidity_capacityAndInvalidRange() public {
        vm.expectRevert(Math.LiquidityOverflow.selector);
        this.callLiquidity(Q96, Q96 / 2, 2 * Q96, type(uint128).max, type(uint128).max);
        vm.expectRevert(Math.InvalidPrice.selector);
        this.callLiquidity(Q96, Q96, Q96, 1, 1);
        vm.expectRevert(Math.InvalidPrice.selector);
        this.callLiquidity(Q96, 0, Q96, 1, 1);
    }

    /// @notice A non-limiting uint256 overflow is ignored in both orientations.
    function test_liquidity_nonlimitingOverflow() public view {
        assertEq(Math.liquidityForAmounts(Q96, Q96 / 2, 2 * Q96, type(uint256).max, 1), 2);
        assertEq(Math.liquidityForAmounts(Q96, Q96 / 2, 2 * Q96, 1, type(uint256).max), 2);
    }

    /// @notice Zero, missing and excess submitted shares do not allocate backing.
    function test_allocation_invalidShares() public {
        vm.expectRevert(Math.InvalidAllocation.selector);
        this.callAllocation(0, 0, 1, 1, 1);
        vm.expectRevert(Math.InvalidAllocation.selector);
        this.callAllocation(1, 0, 1, 1, 1);
        vm.expectRevert(Math.InvalidAllocation.selector);
        this.callAllocation(1, 2, 1, 1, 1);
    }

    /// @notice Preserved baseline interior principal and canonical addition rounding.
    function testFuzz_principal_interiorPreserved(uint64 offset_, uint96 size_) public view {
        uint160 price = Q96 + uint160(offset_);
        uint160 lower = Q96 / 2;
        uint160 upper = 2 * Q96;
        (uint256 a0, uint256 a1) = Math.principal(price, lower, upper, size_);
        (uint256 c0, uint256 c1) = Math.costs(price, lower, upper, size_);
        assertEq(a0, PairTokenMath.A0down(price, upper, size_));
        assertEq(a1, PairTokenMath.A1down(lower, price, size_));
        assertEq(c0, PairTokenMath.A0up(price, upper, size_));
        assertEq(c1, PairTokenMath.A1up(lower, price, size_));
        assertEq(a0, SqrtPriceMath.getAmount0Delta(price, upper, size_, false));
        assertEq(c1, SqrtPriceMath.getAmount1Delta(lower, price, size_, true));
    }

    /// @notice Compare canonical/baseline sizing only on their common cast-admitted domain.
    function testFuzz_liquidity_preservedAffordable(uint64 offset_, uint64 a0_, uint64 a1_) public view {
        uint160 price = Q96 + uint160(offset_);
        uint128 result = Math.liquidityForAmounts(price, Q96 / 2, 2 * Q96, a0_, a1_);
        assertEq(result, LiquidityAmounts.getLiquidityForAmounts(price, Q96 / 2, 2 * Q96, a0_, a1_));
        assertEq(result, PairTokenMath.Fit(price, Q96 / 2, 2 * Q96, a0_, a1_));
        (uint256 c0, uint256 c1) = Math.costs(price, Q96 / 2, 2 * Q96, result);
        assertLe(c0, a0_);
        assertLe(c1, a1_);
    }

    /// @notice Independently bounded integer products assert exact issuance and no dilution.
    function testFuzz_credit_nonDilution(uint64 s_, uint64 r0_, uint64 r1_, uint64 c0_, uint64 c1_) public {
        uint256 s = uint256(s_) + 1;
        uint256 r0 = uint256(r0_) + 1;
        uint256 r1 = uint256(r1_) + 1;
        uint256 expected0 = s * c0_ / r0;
        uint256 expected1 = s * c1_ / r1;
        uint256 expected = expected0 < expected1 ? expected0 : expected1;
        if (expected == 0) {
            vm.expectRevert(Math.ZeroShares.selector);
            this.callZap(s, r0, r1, c0_, c1_);
            return;
        }
        uint256 actual = Math.zapCredit(s, r0, r1, c0_, c1_);
        assertEq(actual, expected);
        assertLe(actual * r0, s * c0_);
        assertLe(actual * r1, s * c1_);
    }

    /// @notice Bounded prices/amounts give a single-word independent rational fuzz oracle.
    function testFuzz_accountingRate_singleFloor(uint80 p_, uint64 a0_, uint64 a1_, uint64 supply_) public view {
        uint160 price = uint160(p_) + 1;
        uint256 supply = uint256(supply_) + 1;
        uint256 square = uint256(price) * price;
        uint256 raw = uint256(a1_) + uint256(a0_) * square / (uint256(1) << 192);
        assertEq(Math.accountingRate(price, a0_, a1_, supply, false), raw * 1e18 / supply);
    }

    function callLiquidity(uint160 p_, uint160 lo_, uint160 hi_, uint256 a0_, uint256 a1_)
        external view returns (uint256)
    {
        return Math.liquidityForAmounts(p_, lo_, hi_, a0_, a1_);
    }

    function callPaired(uint256 s_, uint256 r0_, uint256 r1_, uint256 a0_, uint256 a1_)
        external view returns (uint256, uint256, uint256)
    {
        return Math.pairedQuote(s_, r0_, r1_, a0_, a1_);
    }

    function callCredit(uint256 s_, uint256 r0_, uint256 r1_, uint256 c0_, uint256 c1_, uint256 cap_)
        external view returns (uint256)
    {
        return Math.credit(s_, r0_, r1_, c0_, c1_, cap_);
    }

    function callZap(uint256 s_, uint256 r0_, uint256 r1_, uint256 c0_, uint256 c1_)
        external view returns (uint256)
    {
        return Math.zapCredit(s_, r0_, r1_, c0_, c1_);
    }

    function callAllocation(uint256 s_, uint256 shares_, uint128 size_, uint256 b0_, uint256 b1_)
        external view returns (uint128, uint256, uint256)
    {
        return Math.allocation(s_, shares_, size_, b0_, b1_);
    }

    function callRate(uint160 p_, uint256 a0_, uint256 a1_, uint256 s_, bool token0_) external view returns (uint256) {
        return Math.accountingRate(p_, a0_, a1_, s_, token0_);
    }

    function callSyToAsset(uint256 rate_, uint256 shares_) external pure returns (uint256) {
        return SYUtils.syToAsset(rate_, shares_);
    }

    function callCompound(uint256 idle0_, uint256 idle1_) external view returns (bool, uint256) {
        return Math.compoundSwap(Q96, Q96 / 2, 2 * Q96, idle0_, idle1_, 10000, 10000);
    }

    function _rows(string memory key_, uint256 width_) private view returns (uint256[] memory rows) {
        rows = vm.parseJsonUintArray(vm.readFile(FIXTURE), key_);
        assertGt(rows.length, 0);
        assertEq(rows.length % width_, 0);
    }

    function _assertUint(bytes memory call_, bool success_, uint256 value_, bytes4 error_) private view {
        (bool success, bytes memory returned) = address(this).staticcall(call_);
        assertEq(success, success_, "oracle success");
        if (success) assertEq(abi.decode(returned, (uint256)), value_, "oracle value");
        else assertEq(returned, abi.encodeWithSelector(error_), "oracle exact error");
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultMathTest[]
