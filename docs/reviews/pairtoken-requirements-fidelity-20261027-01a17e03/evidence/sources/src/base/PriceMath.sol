// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {TickMath} from "v4-core/libraries/TickMath.sol";

/// @title PriceMath
/// @notice Opening price helpers shared by the StonkBrokers launch controllers.
library PriceMath {
    error PriceOverflow();

    /// @notice sqrtPriceX96 that prices `tokenAmount` of `token` against `quoteAmount` of `quote`.
    function sqrtPriceFor(address token, address quote, uint256 tokenAmount, uint256 quoteAmount)
        internal
        pure
        returns (uint160)
    {
        // price = amount1 / amount0; sqrtPriceX96 = sqrt(price) * 2^96 = sqrt(price * 2^96) * 2^48.
        bool tokenIs0 = token < quote;
        uint256 num = tokenIs0 ? quoteAmount : tokenAmount;
        uint256 den = tokenIs0 ? tokenAmount : quoteAmount;
        if (den == 0 || num >= (1 << 160)) revert PriceOverflow();
        uint256 ratioX96 = (num << 96) / den;
        uint256 sqrtP = sqrt(ratioX96) << 48;
        if (sqrtP < TickMath.MIN_SQRT_PRICE) sqrtP = TickMath.MIN_SQRT_PRICE;
        if (sqrtP > TickMath.MAX_SQRT_PRICE - 1) sqrtP = TickMath.MAX_SQRT_PRICE - 1;
        return uint160(sqrtP);
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        uint256 y = x;
        z = 1;
        if (y >= 1 << 128) {
            y >>= 128;
            z <<= 64;
        }
        if (y >= 1 << 64) {
            y >>= 64;
            z <<= 32;
        }
        if (y >= 1 << 32) {
            y >>= 32;
            z <<= 16;
        }
        if (y >= 1 << 16) {
            y >>= 16;
            z <<= 8;
        }
        if (y >= 1 << 8) {
            y >>= 8;
            z <<= 4;
        }
        if (y >= 1 << 4) {
            y >>= 4;
            z <<= 2;
        }
        if (y >= 1 << 2) z <<= 1;
        for (uint256 i = 0; i < 8; i++) {
            z = (z + x / z) >> 1;
        }
        uint256 z2 = x / z;
        if (z2 < z) z = z2;
    }
}

