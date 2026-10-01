// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";

// tag::ProtectionAndInventoryMathTest[]
/// @notice Independent integer controls for the pure helpers, not vault acceptance evidence.
contract UniswapV4FullSpreadPonsFamilyHookProtectionAndInventoryMathTest is Test {
    uint160 internal constant Q96 = uint160(1) << 96;

    function test_fullWordProduct() public pure {
        Types.Uint2048 memory product = Protection._multiply(Protection._from(type(uint256).max), Protection._from(type(uint256).max));
        assertEq(product.limb[0], 1);
        assertEq(product.limb[1], type(uint256).max - 1);
        for (uint256 i = 2; i < 8; ++i) assertEq(product.limb[i], 0);
    }

    function test_allEightLimbsCarryAndBorrow() public pure {
        // (2^1024 - 1)^2 = 2^2048 - 2^1025 + 1.
        Types.Uint2048 memory a;
        for (uint256 i; i < 4; ++i) a.limb[i] = type(uint256).max;
        Types.Uint2048 memory result = Protection._multiply(a, a);
        assertEq(result.limb[0], 1);
        for (uint256 i = 1; i < 4; ++i) assertEq(result.limb[i], 0);
        assertEq(result.limb[4], type(uint256).max - 1);
        for (uint256 i = 5; i < 8; ++i) assertEq(result.limb[i], type(uint256).max);
        Types.Uint2048 memory power;
        power.limb[7] = 1;
        result = Protection._subtract(power, Protection._from(1));
        assertEq(result.limb[7], 0);
        for (uint256 i; i < 7; ++i) assertEq(result.limb[i], type(uint256).max);
    }

    function overflowingProduct() external pure {
        Types.Uint2048 memory a;
        a.limb[7] = uint256(1) << 255;
        Protection._scale(a, 2);
    }

    function test_overflowRejectedNotTruncated() public {
        vm.expectRevert(Protection.AccountingMismatch.selector);
        this.overflowingProduct();
    }

    function testFuzz_productAgainstBase256Schoolbook(uint256 a_, uint256 b_) public pure {
        // Independent representation: 64 base-256 digits, with no mulmod or 256-bit multiply.
        uint256[64] memory digits;
        for (uint256 i; i < 32; ++i) {
            for (uint256 j; j < 32; ++j) digits[i + j] += uint8(a_ >> (8 * i)) * uint256(uint8(b_ >> (8 * j)));
        }
        for (uint256 i; i < 63; ++i) {
            digits[i + 1] += digits[i] >> 8;
            digits[i] &= 255;
        }
        Types.Uint2048 memory actual = Protection._multiply(Protection._from(a_), Protection._from(b_));
        for (uint256 i; i < 64; ++i) assertEq(uint8(actual.limb[i / 32] >> (8 * (i % 32))), digits[i]);
    }

    function test_exactBpsAndOneWeiBoundaries() public pure {
        assertTrue(Protection._aligned(9_999, 1, 10_000, 1));
        assertFalse(Protection._aligned(9_998, 1, 10_000, 1));
        assertTrue(Protection._shortfallWithin(10_000, 9_990));
        assertFalse(Protection._shortfallWithin(10_000, 9_989));
        assertTrue(Protection._shortfallWithin(1, 1));
        assertFalse(Protection._shortfallWithin(1, 0));
        assertTrue(Protection._priceWithin(10_000, 10_001, 3));
        assertFalse(Protection._priceWithin(10_000, 10_001, 2));
        assertTrue(Protection._priceWithin(type(uint160).max, type(uint160).max, 25));
        assertTrue(Protection._aligned(type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max));
    }

    function test_sleeveIsFractionOfFinalDeployed() public pure {
        assertEq(Inventory._target(120, 0.2e18), 20);
        assertEq(Inventory._target(120, 1e18), 60);
        assertEq(Inventory._target(120, 0), 0);
        assertEq(Inventory._target(type(uint256).max, 1e18), type(uint256).max / 2);
        assertEq(Inventory._free(100, 10, 20, 30), 40);
        assertEq(Inventory._deadband(100, 1), 5);
        assertEq(Inventory._deadband(0, 1), 1);
    }

    function test_finiteRangeCompositionEqualityAndOneWei() public pure {
        Types.Snapshot memory state = _state();
        state.book.free = [uint256(10_000), uint256(9_999)];
        Types.Progress memory progress = Inventory._progress(state);
        assertEq(Protection._compare(progress.compositionExcess.numerator, Protection._from(0)), 0);
        state.book.free[1] = 9_998;
        progress = Inventory._progress(state);
        assertGt(Protection._compare(progress.compositionExcess.numerator, Protection._from(0)), 0);
    }

    function test_outsideRangeDoesNotHideInactiveInventory() public pure {
        Types.Snapshot memory state = _state();
        state.position.sqrtPriceX96 = state.position.lowerX96;
        state.book.free[0] = 100;
        Types.Ratio memory rho = Inventory._composition(state);
        assertEq(rho.numerator.limb[0], 0);
        state.book.free[1] = 1;
        rho = Inventory._composition(state);
        assertEq(rho.numerator.limb[0], 1);
        assertEq(rho.denominator.limb[0], 1);
    }

    function test_closedPlacementNonzeroAndNoTradeSuccess() public pure {
        // q=1, a=1/2, b=2: each principal leg is exactly L/2.
        Types.Snapshot memory state = _state();
        state.book.free = [uint256(120), uint256(120)];
        Types.Placement memory placement = Planner._closedPlacement(state);
        assertTrue(placement.certified);
        assertEq(placement.afterState.position.liquidity, 200);
        assertEq(placement.liquidityDelta, 200);
        for (uint256 i; i < 2; ++i) {
            assertEq(placement.debt[i], 100);
            assertEq(placement.afterState.book.free[i], 20);
            assertEq(placement.afterState.book.deployed[i], 100);
            assertEq(placement.roundingLoss[i], 0);
        }
        placement = Planner._closedPlacement(placement.afterState);
        assertTrue(placement.certified);
        assertEq(placement.liquidityDelta, 0);
    }

    function test_signedDeltaRoundingNotValuationDifference() public pure {
        Types.Snapshot memory state = _state();
        state.position.liquidity = 3;
        state.position.lowerLiquidityGross = 3;
        state.position.upperLiquidityGross = 3;
        state.position.activeLiquidity = 3;
        state.book.deployed = [uint256(1), uint256(1)];
        state.book.free = [uint256(10), uint256(10)];
        Types.Placement memory placement = Inventory._placement(state, 2);
        // floor((3-2)/2)=0; subtracting floor(3/2)-floor(2/2) also
        // happens to be zero here. Removing two units distinguishes them.
        assertEq(placement.proceeds[0], 0);
        placement = Inventory._placement(state, 1);
        assertEq(placement.proceeds[0], 1);
        assertEq(placement.roundingLoss[0], 0);
        state.position.liquidity = 2;
        state.position.lowerLiquidityGross = 2;
        state.position.upperLiquidityGross = 2;
        state.position.activeLiquidity = 2;
        placement = Inventory._placement(state, 1);
        assertEq(placement.proceeds[0], 0);
        assertEq(placement.roundingLoss[0], 1);
        assertEq(placement.afterState.book.deployed[0], 0);
    }

    function test_collectionMovesFeesOnce() public pure {
        Types.Book memory book;
        book.free = [uint256(10), uint256(20)];
        book.deployed = [uint256(30), uint256(40)];
        book.earned = [uint256(2), uint256(3)];
        uint256[2] memory beforeTotals = Inventory._totals(book);
        Inventory._collect(book);
        Inventory._collect(book);
        assertEq(book.free[0], 12);
        assertEq(book.free[1], 23);
        assertEq(Inventory._totals(book)[0], beforeTotals[0]);
        assertEq(Inventory._totals(book)[1], beforeTotals[1]);
    }

    function test_placementRejectsUnrepresentableCurrencyDebt() public pure {
        Types.Snapshot memory state = _state();
        state.position.lowerX96 = uint160(1) << 129;
        state.position.upperX96 = uint160(1) << 130;
        state.position.sqrtPriceX96 = state.position.upperX96;
        state.position.tick = state.position.upper;
        state.book.free[1] = uint256(1) << 200;
        state.sleeveWad = 0;
        Types.Placement memory placement = Inventory._placement(state, uint128(1) << 96);
        assertFalse(placement.funded);
        assertFalse(placement.certified);
    }

    function test_safePlacementTieChoosesSmallerLiquidityChange() public pure {
        Types.Snapshot memory state = _state();
        state.book.free = [uint256(120), uint256(120)];
        Types.Placement memory placement = Planner._safePlacement(state);
        assertTrue(placement.certified);
        assertEq(placement.afterState.position.liquidity, 199);
        assertEq(placement.liquidityDelta, 199);
        assertEq(placement.roundingLoss[0], 1);
        assertEq(placement.roundingLoss[1], 1);
    }

    function test_ratioComparisonUsesFull1472BitCrossProducts() public pure {
        // N = 2^736 - 1, built independently as three explicit limbs.
        Types.Ratio memory one;
        one.numerator.limb[0] = type(uint256).max;
        one.numerator.limb[1] = type(uint256).max;
        one.numerator.limb[2] = (uint256(1) << 224) - 1;
        one.denominator = one.numerator;
        Types.Ratio memory below = abi.decode(abi.encode(one), (Types.Ratio));
        below.numerator = abi.decode(abi.encode(one.numerator), (Types.Uint2048));
        below.numerator.limb[0] = type(uint256).max - 1;
        assertEq(Protection._ratioCompare(one, one), 0);
        assertEq(Protection._ratioCompare(below, one), -1);
        assertEq(Protection._ratioCompare(one, below), 1);
    }

    function _state() internal pure returns (Types.Snapshot memory state_) {
        state_.idle = true;
        state_.sleeveWad = 0.2e18;
        state_.absoluteFloor = [uint256(1), uint256(1)];
        state_.position.sqrtPriceX96 = Q96;
        state_.position.lowerX96 = Q96 / 2;
        state_.position.upperX96 = Q96 * 2;
        state_.position.lower = -13_864;
        state_.position.upper = 13_864;
        state_.position.maxLiquidityPerTick = type(uint128).max;
    }
}
// end::ProtectionAndInventoryMathTest[]
