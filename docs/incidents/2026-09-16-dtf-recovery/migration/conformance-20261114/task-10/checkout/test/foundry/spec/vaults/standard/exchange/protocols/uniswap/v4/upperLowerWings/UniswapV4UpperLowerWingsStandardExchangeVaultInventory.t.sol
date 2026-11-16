// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultGeometry as Geometry
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultReference as Reference
} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultReference.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultInventoryTest[]
/// @notice Independent principal, rounding and fee observations. Does not certify custody or pool execution.
contract UniswapV4UpperLowerWingsStandardExchangeVaultInventoryTest is Test {
    /// @notice Direct rational parity within a documented no-overflow reference domain.
    function testFuzz_principalAgainstRationalReference(uint16 priceSeed_, uint32 liquidity_) public pure {
        int24 tick = int24(int256(uint256(priceSeed_) % 40001) - 20000);
        uint160 q = TickMath.getSqrtPriceAtTick(tick);
        for (uint256 i; i < 2; ++i) {
            bool ceil = i == 1;
            Types.Principal memory p = Inventory.principal(q, -10000, 10000, liquidity_, ceil);
            (uint256 expected0, uint256 expected1) = Reference.principal(
                q, TickMath.getSqrtPriceAtTick(-10000), TickMath.getSqrtPriceAtTick(10000), liquidity_, ceil
            );
            assertEq(p.amount0, expected0);
            assertEq(p.amount1, expected1);
        }
    }

    /// @notice Each add/remove rounding gap is at most one native unit per token per position.
    function testFuzz_roundingGapAtProtocolScale(uint160 priceSeed_, uint128 liquidity_) public pure {
        uint160 q = TickMath.MIN_SQRT_PRICE + priceSeed_ % (TickMath.MAX_SQRT_PRICE - TickMath.MIN_SQRT_PRICE);
        Types.Principal memory down = Inventory.principal(q, -887272, 887272, liquidity_, false);
        Types.Principal memory up = Inventory.principal(q, -887272, 887272, liquidity_, true);
        assertGe(up.amount0, down.amount0);
        assertGe(up.amount1, down.amount1);
        assertLe(up.amount0 - down.amount0, 1);
        assertLe(up.amount1 - down.amount1, 1);
    }

    /// @notice Upper and lower wings become eligible on partial or full conversion and revert on price reversal.
    function test_mixedCrossedAndReversedWings() public pure {
        uint128 liquidity = 1e18;
        Types.Principal memory upper = Inventory.principal(TickMath.getSqrtPriceAtTick(0), 60, 120, liquidity, false);
        assertEq(uint256(Inventory.composition(upper)), uint256(Types.Composition.Token0Only));
        assertFalse(Inventory.harvestEligible(Types.Slot.Upper, upper));
        upper = Inventory.principal(TickMath.getSqrtPriceAtTick(90), 60, 120, liquidity, false);
        assertEq(uint256(Inventory.composition(upper)), uint256(Types.Composition.Mixed));
        assertTrue(Inventory.harvestEligible(Types.Slot.Upper, upper));
        upper = Inventory.principal(TickMath.getSqrtPriceAtTick(120), 60, 120, liquidity, false);
        assertEq(uint256(Inventory.composition(upper)), uint256(Types.Composition.Token1Only));
        assertTrue(Inventory.harvestEligible(Types.Slot.Upper, upper));
        upper = Inventory.principal(TickMath.getSqrtPriceAtTick(60), 60, 120, liquidity, false);
        assertFalse(Inventory.harvestEligible(Types.Slot.Upper, upper));
        Types.Principal memory lower = Inventory.principal(TickMath.getSqrtPriceAtTick(0), -120, -60, liquidity, false);
        assertEq(uint256(Inventory.composition(lower)), uint256(Types.Composition.Token1Only));
        assertFalse(Inventory.harvestEligible(Types.Slot.Lower, lower));
        lower = Inventory.principal(TickMath.getSqrtPriceAtTick(-90), -120, -60, liquidity, false);
        assertEq(uint256(Inventory.composition(lower)), uint256(Types.Composition.Mixed));
        assertTrue(Inventory.harvestEligible(Types.Slot.Lower, lower));
        lower = Inventory.principal(TickMath.getSqrtPriceAtTick(-120), -120, -60, liquidity, false);
        assertEq(uint256(Inventory.composition(lower)), uint256(Types.Composition.Token0Only));
        assertTrue(Inventory.harvestEligible(Types.Slot.Lower, lower));
        lower = Inventory.principal(TickMath.getSqrtPriceAtTick(-60), -120, -60, liquidity, false);
        assertFalse(Inventory.harvestEligible(Types.Slot.Lower, lower));
    }

    /// @notice One native unit of converted principal is sufficient, whereas core is never a wing harvest.
    function test_oneUnitAndCoreEligibility() public pure {
        assertTrue(Inventory.harvestEligible(Types.Slot.Upper, Types.Principal(0, 1)));
        assertTrue(Inventory.harvestEligible(Types.Slot.Lower, Types.Principal(1, 0)));
        assertFalse(Inventory.harvestEligible(Types.Slot.Core, Types.Principal(1, 1)));
    }

    /// @notice Zero liquidity and integer dust do not falsely signal converted principal.
    function test_zeroLiquidityDustAndFeesAlone() public pure {
        Types.Principal memory p = Inventory.principal(uint160(1) << 96, -60, 60, 0, false);
        assertEq(p.amount0, 0);
        assertEq(p.amount1, 0);
        assertFalse(Inventory.harvestEligible(Types.Slot.Upper, p));
        p = Inventory.principal(uint160(1) << 96, -60, 60, 1, false);
        assertEq(uint256(Inventory.composition(p)), uint256(Types.Composition.NoPrincipal));
        assertEq(Inventory.earnedFee(1, uint256(10) << 128, 0), 10);
        assertFalse(Inventory.harvestEligible(Types.Slot.Lower, p));
        assertFalse(Inventory.harvestEligible(Types.Slot.Upper, p));
    }

    /// @notice Q128 fee subtraction deliberately wraps as in real protocol position accounting.
    function test_feeGrowthWrapAndCheckpoint() public pure {
        assertEq(Inventory.earnedFee(8, 0, type(uint256).max - (uint256(1) << 128) + 1), 8);
        assertEq(Inventory.earnedFee(8, 100, 100), 0);
        assertEq(Inventory.earnedFee(0, type(uint256).max, 0), 0);
    }

    /// @notice Fee multiplication uses an independent 192-bit integer reference.
    function testFuzz_feeReference(uint64 liquidity_, uint128 growth_) public pure {
        assertEq(Inventory.earnedFee(liquidity_, growth_, 0), uint256(liquidity_) * growth_ / (uint256(1) << 128));
    }

    /// @notice Collapsed and invalid ranges fail explicitly even at zero liquidity.
    function test_invalidRangesAndPrice() public {
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidPositionRange.selector, int24(60), int24(60)));
        this.getPrincipal(uint160(1) << 96, 60, 60);
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidPositionRange.selector, int24(-887273), int24(60)));
        this.getPrincipal(uint160(1) << 96, -887273, 60);
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidSqrtPrice.selector, uint160(0)));
        this.getPrincipal(0, -60, 60);
    }

    /// @notice External frame for exact helper revert assertions.
    function getPrincipal(uint160 q_, int24 lower_, int24 upper_) external pure returns (Types.Principal memory) {
        return Inventory.principal(q_, lower_, upper_, 0, false);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultInventoryTest[]
