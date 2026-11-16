// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/// @notice Integer contracts defined by the pinned PairToken PRD, PT-MATH-01 through PT-MATH-05.
library PairTokenMath {
    error InvalidPrice();
    error SafeCastOverflow();
    error InvalidTick(int24 tick);

    uint256 internal constant Q96 = 1 << 96;

    /// @dev Divide the full 512-bit product. All domain/result failures have empty revert data.
    function MD(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        unchecked {
            uint256 lo;
            uint256 hi;
            assembly ("memory-safe") {
                lo := mul(a, b)
                let residue := mulmod(a, b, not(0))
                hi := sub(sub(residue, lo), lt(residue, lo))
                if iszero(gt(c, hi)) { revert(0, 0) }
            }
            if (hi == 0) return lo / c;

            // Subtract the remainder so that the two-word numerator is exactly divisible.
            uint256 remainder = mulmod(a, b, c);
            hi -= remainder > lo ? 1 : 0;
            lo -= remainder;

            // Remove powers of two and fold the high word into the low word.
            uint256 twos = c & (0 - c);
            c /= twos;
            lo /= twos;
            assembly ("memory-safe") {
                twos := add(div(sub(0, twos), twos), 1)
            }
            lo |= hi * twos;

            // c is odd. Newton iteration doubles the inverse's correct bits each step.
            uint256 inverse = (3 * c) ^ 2;
            inverse *= 2 - c * inverse;
            inverse *= 2 - c * inverse;
            inverse *= 2 - c * inverse;
            inverse *= 2 - c * inverse;
            inverse *= 2 - c * inverse;
            inverse *= 2 - c * inverse;
            result = lo * inverse;
        }
    }

    function MU(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        result = MD(a, b, c);
        if (mulmod(a, b, c) != 0) {
            if (result == type(uint256).max) {
                assembly ("memory-safe") { revert(0, 0) }
            }
            ++result;
        }
    }

    function A0down(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        if (a > b) (a, b) = (b, a);
        if (a == 0) revert InvalidPrice();
        return MD(uint256(liquidity) * Q96, b - a, b) / a;
    }

    function A0up(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        if (a > b) (a, b) = (b, a);
        if (a == 0) revert InvalidPrice();
        uint256 numerator = MU(uint256(liquidity) * Q96, b - a, b);
        return numerator / a + (numerator % a == 0 ? 0 : 1);
    }

    function A1down(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        uint256 difference = a > b ? a - b : b - a;
        return MD(liquidity, difference, Q96);
    }

    function A1up(uint160 a, uint160 b, uint128 liquidity) internal pure returns (uint256) {
        uint256 difference = a > b ? a - b : b - a;
        uint256 down = MD(liquidity, difference, Q96);
        return down + (mulmod(liquidity, difference, Q96) == 0 ? 0 : 1);
    }

    function L0(uint160 a, uint160 b, uint256 amount) internal pure returns (uint128) {
        if (a > b) (a, b) = (b, a);
        uint256 value = MD(amount, MD(a, b, Q96), b - a);
        if (value > type(uint128).max) revert SafeCastOverflow();
        return uint128(value);
    }

    function L1(uint160 a, uint160 b, uint256 amount) internal pure returns (uint128) {
        if (a > b) (a, b) = (b, a);
        uint256 value = MD(amount, Q96, b - a);
        if (value > type(uint128).max) revert SafeCastOverflow();
        return uint128(value);
    }

    function Fit(uint160 p, uint160 a, uint160 b, uint256 x, uint256 y)
        internal
        pure
        returns (uint128)
    {
        if (a > b) (a, b) = (b, a);
        if (p <= a) return L0(a, b, x);
        if (p >= b) return L1(a, b, y);
        uint128 from0 = L0(p, b, x);
        uint128 from1 = L1(a, p, y);
        return from0 < from1 ? from0 : from1;
    }

    function T(int24 tick) internal pure returns (uint160) {
        if (tick < -887272 || tick > 887272) revert InvalidTick(tick);
        uint256 magnitude = uint256(tick < 0 ? -int256(tick) : int256(tick));
        // Numerical coefficients from PT-MATH-04; no dependency library is an authority.
        uint256[20] memory coefficients = [
            uint256(0xfffcb933bd6fad37aa2d162d1a594001),
            0xfff97272373d413259a46990580e213a,
            0xfff2e50f5f656932ef12357cf3c7fdcc,
            0xffe5caca7e10e4e61c3624eaa0941cd0,
            0xffcb9843d60f6159c9db58835c926644,
            0xff973b41fa98c081472e6896dfb254c0,
            0xff2ea16466c96a3843ec78b326b52861,
            0xfe5dee046a99a2a811c461f1969c3053,
            0xfcbe86c7900a88aedcffc83b479aa3a4,
            0xf987a7253ac413176f2b074cf7815e54,
            0xf3392b0822b70005940c7a398e4b70f3,
            0xe7159475a2c29b7443b29c7fa6e889d9,
            0xd097f3bdfd2022b8845ad8f792aa5825,
            0xa9f746462d870fdf8a65dc1f90e061e5,
            0x70d869a156d2a1b890bb3df62baf32f7,
            0x31be135f97d08fd981231505542fcfa6,
            0x9aa508b5b7a84e1c677de54f3e99bc9,
            0x5d6af8dedb81196699c329225ee604,
            0x2216e584f5fa1ea926041bedfe98,
            0x48a170391f7dc42444e8fa2
        ];
        uint256 ratio = 1 << 128;
        for (uint256 bit; bit < 20; ++bit) {
            if ((magnitude & (uint256(1) << bit)) != 0) {
                ratio = (ratio * coefficients[bit]) >> 128;
            }
        }
        if (tick > 0) ratio = type(uint256).max / ratio;
        return uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    /// @dev The caller must perform any genesis product with checked multiplication before this call.
    function sqrt(uint256 value) internal pure returns (uint256 result) {
        if (value < 2) return value;
        result = value;
        uint256 next = value / 2 + value % 2;
        while (next < result) {
            result = next;
            next = (value / next + next) / 2;
        }
    }

    function U128(int128 delta) internal pure returns (uint256) {
        return uint256(uint128(delta));
    }
}
