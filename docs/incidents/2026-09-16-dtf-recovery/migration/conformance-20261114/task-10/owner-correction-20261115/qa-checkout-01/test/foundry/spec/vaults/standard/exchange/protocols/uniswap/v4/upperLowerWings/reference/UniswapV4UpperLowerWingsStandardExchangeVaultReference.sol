// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultReference[]
/// @notice Test-only independent search and bounded rational arithmetic. Never used by production.
library UniswapV4UpperLowerWingsStandardExchangeVaultReference {
    /// @notice Binary-search the ordered usable boundary list, without inverse TickMath or signed floor division.
    function boundaries(uint160 price_, int24 spacing_) internal pure returns (int24 lower_, int24 upper_) {
        int256 count = int256(887272) / spacing_;
        int256 lo = -count;
        int256 hi = count + 1;
        while (lo < hi) {
            int256 mid = lo + (hi - lo) / 2;
            if (TickMath.getSqrtPriceAtTick(int24(mid * spacing_)) < price_) lo = mid + 1;
            else hi = mid;
        }
        lower_ = int24((lo - 1) * spacing_);
        lo = -count;
        hi = count + 1;
        while (lo < hi) {
            int256 mid = lo + (hi - lo) / 2;
            if (TickMath.getSqrtPriceAtTick(int24(mid * spacing_)) <= price_) lo = mid + 1;
            else hi = mid;
        }
        upper_ = int24(lo * spacing_);
    }

    /// @notice Direct rational formulas, independent of SqrtPriceMath and FullMath.
    /// @dev Test domain: all sqrt prices in [sqrt(-20000),sqrt(20000)] and liquidity <= uint32.max.
    function principal(uint160 price_, uint160 lower_, uint160 upper_, uint32 liquidity_, bool ceil_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        uint256 p = price_ < lower_ ? lower_ : price_ > upper_ ? upper_ : price_;
        uint256 n0 = uint256(liquidity_) * (upper_ - p) * (uint256(1) << 96);
        uint256 d0 = p * upper_;
        uint256 n1 = uint256(liquidity_) * (p - lower_);
        uint256 d1 = uint256(1) << 96;
        amount0_ = n0 / d0 + (ceil_ && n0 % d0 != 0 ? 1 : 0);
        amount1_ = n1 / d1 + (ceil_ && n1 % d1 != 0 ? 1 : 0);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultReference[]
