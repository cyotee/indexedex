// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/// @notice Fee-free settlement against the complete two-asset share book.
/// @dev A locked protocol pool cannot perform the exit swap. Instead the remaining
/// holders buy the withdrawing holder's other-token entitlement at x*y=k. Assets
/// stay in the book, output must be locally funded, and no pool interaction occurs.
library StandardExchangeConstantProduct {
    error InsufficientBacking();

    function _sharesForDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 totalSharesBefore,
        uint256 reserve0Before,
        uint256 reserve1Before
    ) internal pure returns (uint256 sharesOut) {
        if (amount0Added == 0 && amount1Added == 0) return 0;
        if (totalSharesBefore == 0) {
            if (amount0Added == 0 || amount1Added == 0) return 0;
            return FixedPointMathLib.mulSqrt(amount0Added, amount1Added);
        }
        if (reserve0Before == 0 && reserve1Before == 0) return 0;
        if (reserve0Before == 0) return Math.mulDiv(amount1Added, totalSharesBefore, reserve1Before);
        if (reserve1Before == 0) return Math.mulDiv(amount0Added, totalSharesBefore, reserve0Before);
        if (amount0Added != 0 && amount1Added != 0) {
            return Math.min(
                Math.mulDiv(amount0Added, totalSharesBefore, reserve0Before),
                Math.mulDiv(amount1Added, totalSharesBefore, reserve1Before)
            );
        }
        uint256 beforeInvariant = FixedPointMathLib.mulSqrt(reserve0Before, reserve1Before);
        // Round the denominator up, including when the product needs 512 bits.
        if (Math.mulDiv(reserve0Before, reserve1Before, beforeInvariant) != beforeInvariant
            || mulmod(reserve0Before, reserve1Before, beforeInvariant) != 0) ++beforeInvariant;
        uint256 afterInvariant = FixedPointMathLib.mulSqrt(reserve0Before + amount0Added, reserve1Before + amount1Added);
        if (afterInvariant <= beforeInvariant) return 0;
        return Math.mulDiv(totalSharesBefore, afterInvariant - beforeInvariant, beforeInvariant);
    }

    function _singleExit(uint256 reserveOut, uint256 reserveOther, uint256 shares, uint256 supply)
        internal pure returns (uint256 output)
    {
        if (shares == 0 || supply == 0) return 0;
        if (shares > supply || (shares == supply && reserveOther != 0)) revert InsufficientBacking();
        uint256 entitlementOut = Math.mulDiv(reserveOut, shares, supply);
        uint256 entitlementOther = Math.mulDiv(reserveOther, shares, supply);
        // Burn proportionally, then swap the other entitlement into the remaining
        // book. The swap denominator is remainingOther + entitlementOther.
        output = entitlementOut;
        if (entitlementOther != 0) {
            output += Math.mulDiv(reserveOut - entitlementOut, entitlementOther, reserveOther);
        }
    }

    function _sharesForSingleExit(uint256 reserveOut, uint256 reserveOther, uint256 output, uint256 supply)
        internal pure returns (uint256 shares)
    {
        if (output == 0) return 0;
        if (output > reserveOut || supply == 0) revert InsufficientBacking();
        // Invert the exact integer forward quote, rounding shares up. Bisection
        // avoids a lossy fixed-point square root and works with mixed decimals.
        uint256 low = 1;
        uint256 high = reserveOther == 0 ? supply : supply - 1;
        if (_singleExit(reserveOut, reserveOther, high, supply) < output) revert InsufficientBacking();
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (_singleExit(reserveOut, reserveOther, mid, supply) >= output) high = mid;
            else low = mid + 1;
        }
        return low;
    }
}
