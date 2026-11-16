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

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultGeometryTest[]
/// @notice Pure production helper tests, not package deployment or lifecycle acceptance evidence.
contract UniswapV4UpperLowerWingsStandardExchangeVaultGeometryTest is Test {
    /// @notice Exact aligned prices skip the boundary on both sides.
    function test_exactAlignedAndNegativeTicks() public pure {
        _assertBounds(0, 60, -60, 60);
        _assertBounds(-60, 60, -120, 0);
        _assertBounds(-61, 60, -120, -60);
        _assertBounds(-1, 60, -60, 0);
        _assertBounds(1, 60, 0, 60);
    }

    /// @notice Price within a tick uses the actual sqrt boundary rather than the rounded tick alone.
    function test_oneSqrtUnitAroundAlignedBoundary() public pure {
        uint160 q = TickMath.getSqrtPriceAtTick(-60);
        Types.Geometry memory at = Geometry.ranges(q, 60);
        Types.Geometry memory above = Geometry.ranges(q + 1, 60);
        Types.Geometry memory below = Geometry.ranges(q - 1, 60);
        assertEq(at.lower.upper, -120);
        assertEq(above.lower.upper, -60);
        assertEq(below.lower.upper, -120);
        assertEq(at.upper.lower, 0);
        assertEq(above.upper.lower, 0);
        assertEq(below.upper.lower, -60);
    }

    /// @notice Collapsed or beyond-protocol wings are explicitly unavailable and have zeroed bounds.
    function test_extremaRetainUnplaceableInventory() public pure {
        Types.Geometry memory low = Geometry.ranges(TickMath.MIN_SQRT_PRICE, 60);
        assertFalse(low.lower.available);
        assertEq(low.lower.lower, 0);
        assertEq(low.lower.upper, 0);
        assertTrue(low.upper.available);
        assertEq(low.upper.lower, low.core.lower);
        Types.Geometry memory high = Geometry.ranges(TickMath.MAX_SQRT_PRICE - 1, 60);
        assertFalse(high.upper.available);
        assertEq(high.upper.lower, 0);
        assertEq(high.upper.upper, 0);
        assertTrue(high.lower.available);
        assertEq(high.lower.upper, high.core.upper);
        low = Geometry.ranges(TickMath.getSqrtPriceAtTick(-887220), 60);
        high = Geometry.ranges(TickMath.getSqrtPriceAtTick(887220), 60);
        assertFalse(low.lower.available);
        assertFalse(high.upper.available);
    }

    /// @notice Both immutable target orientations select the geometrically correct wing.
    function test_bothTargetOrientations() public pure {
        assertEq(uint256(Geometry.targetWing(true)), uint256(Types.Slot.Upper));
        assertEq(uint256(Geometry.targetWing(false)), uint256(Types.Slot.Lower));
    }

    /// @notice Differential search across protocol prices, spacing and exact/intermediate boundaries.
    function testFuzz_geometryAgainstIndependentBoundarySearch(uint160 seed_, uint16 spacingSeed_) public pure {
        int24 spacing = int24(int256(uint256(spacingSeed_) % 32767 + 1));
        uint160 q = TickMath.MIN_SQRT_PRICE + seed_ % (TickMath.MAX_SQRT_PRICE - TickMath.MIN_SQRT_PRICE);
        _compareSearch(q, spacing);
    }

    /// @notice Uniform tick sampling complements uniform sqrt-price sampling near the upper extreme.
    function testFuzz_geometryAcrossTicks(int24 tickSeed_, uint16 spacingSeed_, bool above_) public pure {
        int24 tick = int24(int256(uint256(uint24(tickSeed_)) % 1774544) - 887272);
        uint160 q = TickMath.getSqrtPriceAtTick(tick) + (above_ ? 1 : 0);
        _compareSearch(q, int24(int256(uint256(spacingSeed_) % 32767 + 1)));
    }

    /// @notice Invalid spacing fails before arithmetic and cannot manufacture valid-looking ranges.
    function test_invalidSpacing() public {
        int24[4] memory values = [int24(0), int24(-1), int24(32768), type(int24).max];
        for (uint256 i; i < values.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(Geometry.InvalidTickSpacing.selector, values[i]));
            this.getRanges(uint160(1) << 96, values[i]);
        }
    }

    /// @notice Price validation follows the protocol's inclusive lower/exclusive upper domain.
    function test_invalidPrice() public {
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidSqrtPrice.selector, TickMath.MIN_SQRT_PRICE - 1));
        this.getRanges(TickMath.MIN_SQRT_PRICE - 1, 60);
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidSqrtPrice.selector, TickMath.MAX_SQRT_PRICE));
        this.getRanges(TickMath.MAX_SQRT_PRICE, 60);
    }

    /// @notice External frame for exact revert assertions against internal production helpers.
    function getRanges(uint160 q_, int24 spacing_) external pure returns (Types.Geometry memory) {
        return Geometry.ranges(q_, spacing_);
    }

    function _assertBounds(int24 tick_, int24 spacing_, int24 lower_, int24 upper_) internal pure {
        Types.Geometry memory g = Geometry.ranges(TickMath.getSqrtPriceAtTick(tick_), spacing_);
        assertTrue(g.lower.available && g.upper.available);
        assertEq(g.lower.upper, lower_);
        assertEq(g.upper.lower, upper_);
        assertEq(g.core.lower, g.lower.lower);
        assertEq(g.core.upper, g.upper.upper);
    }

    function _compareSearch(uint160 q_, int24 spacing_) internal pure {
        Types.Geometry memory g = Geometry.ranges(q_, spacing_);
        (int24 lower, int24 upper) = Reference.boundaries(q_, spacing_);
        int24 maximum = (887272 / spacing_) * spacing_;
        assertEq(g.core.lower, -maximum);
        assertEq(g.core.upper, maximum);
        assertTrue(g.core.available);
        assertEq(g.lower.available, lower > -maximum && lower <= maximum);
        assertEq(g.upper.available, upper >= -maximum && upper < maximum);
        if (g.lower.available) {
            assertEq(g.lower.upper, lower);
            assertLt(TickMath.getSqrtPriceAtTick(lower), q_);
        }
        if (g.upper.available) {
            assertEq(g.upper.lower, upper);
            assertGt(TickMath.getSqrtPriceAtTick(upper), q_);
        }
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultGeometryTest[]
