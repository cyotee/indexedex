// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types
} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultInventory[]
/// @notice Principal and uncollected fee arithmetic; this library never treats fees as converted principal.
library UniswapV4UpperLowerWingsStandardExchangeVaultInventory {
    error InvalidPositionRange(int24 lower, int24 upper);

    /// @notice Native-unit principal available on removal (floor) or required on addition (ceil).
    /// @dev Slot alignment and pool liquidity capacity are enforced by the later placement/execution layer.
    function principal(uint160 sqrtPriceX96_, int24 lower_, int24 upper_, uint128 liquidity_, bool roundUp_)
        internal
        pure
        returns (Types.Principal memory result_)
    {
        if (lower_ < TickMath.MIN_TICK || upper_ > TickMath.MAX_TICK || lower_ >= upper_) {
            revert InvalidPositionRange(lower_, upper_);
        }
        if (sqrtPriceX96_ < TickMath.MIN_SQRT_PRICE || sqrtPriceX96_ >= TickMath.MAX_SQRT_PRICE) {
            revert TickMath.InvalidSqrtPrice(sqrtPriceX96_);
        }
        if (liquidity_ == 0) return result_;
        uint160 lowerPrice = TickMath.getSqrtPriceAtTick(lower_);
        uint160 upperPrice = TickMath.getSqrtPriceAtTick(upper_);
        uint160 price =
            sqrtPriceX96_ < lowerPrice ? lowerPrice : sqrtPriceX96_ > upperPrice ? upperPrice : sqrtPriceX96_;
        result_.amount0 = SqrtPriceMath.getAmount0Delta(price, upperPrice, liquidity_, roundUp_);
        result_.amount1 = SqrtPriceMath.getAmount1Delta(lowerPrice, price, liquidity_, roundUp_);
    }

    /// @notice Fees earned since the position's last checkpoint, with protocol modular growth subtraction.
    function earnedFee(uint128 liquidity_, uint256 growthInsideX128_, uint256 growthLastX128_)
        internal
        pure
        returns (uint256 fee_)
    {
        uint256 growth;
        unchecked {
            growth = growthInsideX128_ - growthLastX128_;
        }
        return FullMath.mulDiv(growth, liquidity_, uint256(1) << 128);
    }

    /// @notice Actual integer composition; a funded dust position may have no currently removable principal.
    function composition(Types.Principal memory principal_) internal pure returns (Types.Composition) {
        if (principal_.amount0 == 0) {
            return principal_.amount1 == 0 ? Types.Composition.NoPrincipal : Types.Composition.Token1Only;
        }
        return principal_.amount1 == 0 ? Types.Composition.Token0Only : Types.Composition.Mixed;
    }

    /// @notice Conversion is relative to the wing's creation currency, independent of the vault's target choice.
    /// @dev Core never qualifies; callers must use principal excluding fees and current operation credit.
    function harvestEligible(Types.Slot slot_, Types.Principal memory principal_) internal pure returns (bool) {
        if (slot_ == Types.Slot.Upper) return principal_.amount1 != 0;
        if (slot_ == Types.Slot.Lower) return principal_.amount0 != 0;
        return false;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultInventory[]
