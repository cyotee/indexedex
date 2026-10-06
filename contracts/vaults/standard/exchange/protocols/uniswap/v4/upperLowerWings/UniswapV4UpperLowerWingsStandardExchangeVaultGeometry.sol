// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types
} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultGeometry[]
/// @notice Full-range core and nearest strictly separated upper/lower wing boundaries.
library UniswapV4UpperLowerWingsStandardExchangeVaultGeometry {
    error InvalidTickSpacing(int24 tickSpacing);

    /// @notice Derive placement ranges from actual sqrt price, never the pool's directional tick cursor.
    /// @dev At an exact aligned price both wings skip that boundary. An unavailable wing retains inventory locally.
    function ranges(uint160 sqrtPriceX96_, int24 tickSpacing_) internal pure returns (Types.Geometry memory result_) {
        if (tickSpacing_ < TickMath.MIN_TICK_SPACING || tickSpacing_ > TickMath.MAX_TICK_SPACING) {
            revert InvalidTickSpacing(tickSpacing_);
        }
        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96_);
        int24 minimum = TickMath.minUsableTick(tickSpacing_);
        int24 maximum = TickMath.maxUsableTick(tickSpacing_);
        result_.core = Types.Range(minimum, maximum, true);

        // Solidity signed division truncates toward zero; negative nonmultiples need mathematical floor.
        int24 aligned = (tick / tickSpacing_) * tickSpacing_;
        if (tick < 0 && tick % tickSpacing_ != 0) aligned -= tickSpacing_;
        int24 upper = aligned + tickSpacing_;
        // Below min usable the floor is outside TickMath's domain. Do not evaluate its sqrt price.
        int24 lower = aligned;
        if (aligned >= minimum && TickMath.getSqrtPriceAtTick(aligned) == sqrtPriceX96_) {
            lower -= tickSpacing_;
        }
        if (upper >= minimum && upper < maximum) result_.upper = Types.Range(upper, maximum, true);
        if (lower > minimum && lower <= maximum) result_.lower = Types.Range(minimum, lower, true);
    }

    /// @notice Token0 inventory uses the upper wing; token1 inventory uses the lower wing.
    function targetWing(bool targetIsToken0_) internal pure returns (Types.Slot) {
        return targetIsToken0_ ? Types.Slot.Upper : Types.Slot.Lower;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultGeometry[]
